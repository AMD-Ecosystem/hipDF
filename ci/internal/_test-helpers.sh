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
    find $1 -name "test_*.py" \
      -printf "run_tests: found test file: %p\n" \
      -exec bash -c '
        csv_file="$2/{}${5}.csv"
        pytest $7 $4 -v --timeout $3 {} \
        --continue-on-collection-errors \
        --csv "$csv_file" --csv-columns file,id,status,message
        if [[ -n "$5" && -f "$csv_file" ]]; then
          temp_file=$(mktemp)
          head -n 1 "$csv_file" > "$temp_file"
          tail -n +2 "$csv_file" | awk -F"," -v suffix="$6" "BEGIN{OFS=\",\"} {\$2=\$2 suffix; print}" >> "$temp_file"
          mv "$temp_file" "$csv_file"
        fi
        ' _ "$1" "$2" "$3" "$pytest_args" "$suffix" "$id_suffix" "$config_arg" \;
    set -e
}

# Merges all per-file results in a folder (1st arg) into a single CSV.
function merge_test_results() {
    FAILURE_EXPR=",\(error\|failed\),"

    result=""
    test_failures=0
    i=0
    for f in $(grep -rL "${FAILURE_EXPR}" --include="*.csv" $1); do
        if (( i == 0 )); then
            result+=$(cat $f)
        else
            result+=$(tail -n +2 $f)
        fi
        i=1
    done
    for f in $(grep -rl "${FAILURE_EXPR}" --include="*.csv" $1); do
        has_errors=$(cat $f | grep -n "error" | grep -v "passed"  | grep -v "xfailed" || true)
        if [ -n "$has_errors" ]; then
            test_failures=1
        fi
        if (( i == 0 )); then
            result+=$(cat $f)
        else
            result+=$(tail -n +2 $f)
        fi
        i=1
    done
    echo $result
    return $test_failures
}

# run_hipdf_test_suites <csv_output_dir> <timeout_per_test_sec>
function run_hipdf_test_suites() {
    local csv_output_dir=$1
    local timeout_per_test_sec=$2

    export DASK_DISTRIBUTED__DIAGNOSTICS__NVML=False

    python3 -m pip install -r python/cudf/cudf_pandas_tests/third_party_integration_tests/requirements.txt || \
        echo "WARNING: some third-party integration test deps failed to install (e.g. tensorflow-rocm); continuing"

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
    run_tests python/pylibcudf/pylibcudf/tests \
        ${csv_output_dir} ${timeout_per_test_sec}

    if [ "${HIPDF_TEST_DASK:-0}" = "1" ] && [ -d python/dask_cudf/dask_cudf/tests ]; then
        export UCX_TLS=sm,rocm_copy,rocm_ipc,self,tcp
        export UCX_WARN_UNUSED_ENV_VARS=n
        export UCX_MEMTYPE_CACHE=n
        export UCX_TCP_CM_REUSEADDR=y

        DASK_CUDA_WAIT_WORKERS_MIN_TIMEOUT=60 \
            run_tests python/dask_cudf/dask_cudf/tests \
                ${csv_output_dir} ${timeout_per_test_sec} "-rfs"
    fi
}
