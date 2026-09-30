# MIT License
#
# Copyright (c) 2026 Advanced Micro Devices, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Shared pytest helpers for hipDF CI. Meant to be sourced, not executed.
# Requires pytest, pytest-csv and pytest-timeout.

set -euo pipefail

_TEST_HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Map a test directory to the pytest config file that declares the intended
# options for that package (filterwarnings=error, --strict-markers, xfail_strict,
# registered markers, ...).
function config_for_tests() {
    case "$1" in
        python/pylibcudf/*)              echo "python/pylibcudf/pyproject.toml" ;;
        python/cudf/cudf_pandas_tests*)  echo "python/cudf/cudf_pandas_tests/pytest.ini" ;;
        python/cudf/*)                   echo "python/cudf/pyproject.toml" ;;
        *)                               echo "" ;;
    esac
}

# Runs all tests individually given the input folder (1st arg),
# the output folder (2nd arg), and a timeout value (3rd arg)
# that should be chosen so that long running tests
# complete but hanging tests are aborted.
# The 4th argument can be used to append additional
# pytest arguments. Do not forget to use quotes if there are
# more than one arguments.
# The 5th argument can be used to append a suffix to the CSV filename.
# The 6th argument can be used to append a suffix to the test ID in CSV output.
function run_tests() {
    set +e # continue on error
    local pytest_args=${4:-""}
    local suffix=${5:-""}
    local id_suffix=${6:-""}
    local config_file
    config_file="$(config_for_tests "$1")"
    local config_arg=""
    if [ -n "${config_file}" ]; then
        config_arg="-c ${config_file}"
    fi
    # Whole-file backstop. --timeout is per test and cannot always fire: a test
    # blocked inside a native call never reaches a point where the timeout can
    # act, which used to wedge the job indefinitely. Sized far above any
    # legitimate single file so only genuine hangs reach it.
    local file_timeout=$(( $3 * 15 ))
    find $1 -name "test_*.py" \
      -printf "run_tests: found test file: %p\n" \
      -exec bash -c '
        csv_file="$2/{}${5}.csv"
        timeout -k 30 "$8" pytest $7 $4 --tb=short -ra --timeout $3 {} \
        --continue-on-collection-errors \
        --csv "$csv_file" --csv-columns file,id,status,message
        pytest_rc=$?
        # No CSV with exit 0 or 5 is normal: pytest-csv writes no file when
        # every test in it was skipped at module level, or nothing was
        # collected. Any other exit with no CSV means pytest died without
        # reporting (killed by the backstop above, or crashed), and
        # merge_test_results would otherwise see no CSV and count the file as
        # a pass, so synthesise an error row for it.
        if [[ ! -f "$csv_file" && "$pytest_rc" != 0 && "$pytest_rc" != 5 ]]; then
          mkdir -p "$(dirname "$csv_file")"
          printf "file,id,status,message\n%s,%s,error,pytest exited %s without writing results (hang or crash)\n" \
            "{}" "{}" "$pytest_rc" > "$csv_file"
        fi
        if [[ -n "$5" && -f "$csv_file" ]]; then
          python3 "$9/_test-results.py" suffix-ids "$csv_file" "$6"
        fi
        ' _ "$1" "$2" "$3" "$pytest_args" "$suffix" "$id_suffix" "$config_arg" "$file_timeout" \
          "${_TEST_HELPERS_DIR}" \;
    set -e
}

# Merges all per-file results in a folder (1st arg) into a single CSV on
# stdout. Returns 1 if any test ended in error or failed.
function merge_test_results() {
    python3 "${_TEST_HELPERS_DIR}/_test-results.py" merge "$1"
}

# run_hipdf_test_suites <csv_output_dir> <timeout_per_test_sec>
function run_hipdf_test_suites() {
    local csv_output_dir=$1
    local timeout_per_test_sec=$2

    export DASK_DISTRIBUTED__DIAGNOSTICS__NVML=False

    # The third-party integration test dependencies are installed by
    # _install-test-deps.sh, which both callers of this function source first.

    run_tests python/cudf/hipdf/tests ${csv_output_dir} ${timeout_per_test_sec}
    run_tests python/cudf/cudf/tests ${csv_output_dir} ${timeout_per_test_sec}
    if [ "${HIPDF_PYTHON_CUDF_PANDAS_TESTS_XNACK_0:-false}" = "true" ] ; then
        export HSA_XNACK=0
        export CUDF_PANDAS_BYPASS_XNACK_CHECK=1
        run_tests python/cudf/cudf_pandas_tests \
            ${csv_output_dir} ${timeout_per_test_sec} "-p cudf.pandas" "_xnack0" "[xnack=0]"
    fi
    export HSA_XNACK=1
    run_tests python/cudf/cudf_pandas_tests \
        ${csv_output_dir} ${timeout_per_test_sec} "-p cudf.pandas" "_xnack1" "[xnack=1]"
    # WORKAROUND(two-rocms): pylibcudf only imports once librmm.so is loaded.
    # libcudf.load_library() loads librmm and rapids_logger only if libkvikio
    # and nvidia.libnvcomp import too, and hipDF ships neither. Loading them
    # regardless would make librmm resolve /opt/rocm's HIP before hip-python
    # opens rocm-sdk's, and a plain `import cudf` would then abort wherever both
    # ROCms are installed. Once they no longer clash, load each dependency on
    # its own in python/libcudf/libcudf/load.py and drop -p rmm.
    run_tests python/pylibcudf/tests \
        ${csv_output_dir} ${timeout_per_test_sec} "-p rmm"

    if [ "${HIPDF_TEST_DASK:-0}" = "1" ] && [ -d python/dask_cudf/dask_cudf/tests ]; then
        export UCX_TLS=sm,rocm_copy,rocm_ipc,self,tcp
        export UCX_WARN_UNUSED_ENV_VARS=n
        export UCX_MEMTYPE_CACHE=n
        export UCX_TCP_CM_REUSEADDR=y

        DASK_CUDA_WAIT_WORKERS_MIN_TIMEOUT=60 \
            run_tests python/dask_cudf/dask_cudf/tests \
                ${csv_output_dir} ${timeout_per_test_sec}
    fi
}
