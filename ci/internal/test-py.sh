#!/usr/bin/env bash

# MIT License
#
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -xeu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Runs all tests individually given the input folder (1st arg),
# the output folder (2nd arg), and a timeout value (3rd arg)
# that should chosen so that long running tests
# complete but hanging tests are aborted.
# The 4th argument can be used to append additional
# pytest arguments. Do not forgot to use quotes if there are
# more than one arguments.
# The 5th argument can be used to append a suffix to the test ID output in the CSV files.
# Map a test directory to the pytest config file that declares the intended
# options for that package (filterwarnings=error, --strict-markers, xfail_strict,
# registered markers, ...).
#
# Why this is needed: pytest is invoked from the repo top-level
# (${BUILD_DIR}/${PROJECT_ID}) with a single test-file path. Its rootdir/config
# auto-discovery can select the top-level pyproject.toml, which has NO
# [tool.pytest.ini_options] table, instead of the per-package config. When that
# happens the package options are silently dropped: warnings are no longer turned
# into errors and custom marks are unregistered, which makes "error case" tests
# (that expect a warning-turned-exception) fail and emits PytestUnknownMarkWarning.
# Passing an explicit `-c` makes the active config deterministic regardless of the
# cwd/rootdir that pytest would otherwise infer.
function config_for_tests() {
    case "$1" in
        python/pylibcudf/*)          echo "python/pylibcudf/pyproject.toml" ;;
        python/cudf/cudf_pandas_tests*) echo "python/cudf/cudf_pandas_tests/pytest.ini" ;;
        python/cudf/*)               echo "python/cudf/pyproject.toml" ;;
        *)                           echo "" ;;
    esac
}

function run_tests() {
    set +e # continue on error
    local pytest_args=${4:-""}
    local suffix=${5:-""}
    local id_suffix=${6:-""}
    # Resolve the per-package pytest config and pass it explicitly (see
    # config_for_tests above). Empty => fall back to pytest auto-discovery.
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
# NOTE: We currently group the tests such that all files with zero failures
#       come first. To have a more deterministic order, we might consider to
#       change that behavior.
function merge_test_results() {
    # note: status emitted by pytest-csv: passed, failed, error, skipped,
    #       xpassed, xfailed
    # note: status is second last CSV column, so is embedded within ","
    FAILURE_EXPR=",\(error\|failed\),"

    result=""
    test_failures=0
    # first add results with no 'failed' or 'error' status (xfailed are included)
    i=0
    for f in $(grep -rL "${FAILURE_EXPR}" --include="*.csv" $1); do
        # echo $f
        if (( i == 0 )); then
            result+=$(cat $f)
        else
            result+=$(tail -n +2 $f)
        fi
        i=1
    done
    # second include results with failed
    for f in $(grep -rl "${FAILURE_EXPR}" --include="*.csv" $1); do
        # Filter out cases where "error" is part of the test name.
        has_errors=$(cat $f | grep -n "error" | grep -v "passed"  | grep -v "xfailed" || true)
        if [ -n "$has_errors" ]; then
            test_failures=1
        fi
        # echo $f
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

# activate conda env if specified
# note: test phase might be used without the rest of the phases
# Skip conda activation for test-wheels stage (uses isolated venv instead)
if [ -n "${HIPDF_CONDA_ENV:-}" ] && [ "${STAGE_NAME:-}" != "test-wheels" ]; then
    set +u # note: conda script may have unbound variables
    source ${CONDA_DIR}/etc/profile.d/conda.sh
    conda activate ${HIPDF_CONDA_ENV}
    set -u
elif [ -z "${HIPDF_CONDA_ENV:-}" ] && [ "${STAGE_NAME:-}" != "test-wheels" ]; then
    # No conda env: activate the pipeline-managed venv created by _build-preamble.sh
    # (mirrors test-cpp.sh). Required so pip/pytest run inside the venv instead of the
    # externally-managed system Python, which rejects `pip install` under PEP 668.
    . ${INSTALL_DIR}/venv/hipdf_dev/bin/activate
fi

test_failures=0
cd ${BUILD_DIR}/${PROJECT_ID}
    . "${SCRIPT_DIR}/_install-test-requirements.sh"

    CSV_OUTPUT_DIR=${PROJECT_ID}_pytest_output

#==========================
# BEGIN of project-specific
#==========================
    # Disable dask.distributed's NVML GPU diagnostics. On this ROCm stack the
    # `pynvml` shim that distributed probes at cluster startup falls back to
    # `rocm.bindings.amdsmi`, whose `amdsmi_get_processor_type()` signature is
    # incompatible (expects 2 positional args, pynvml passes 1). That mismatch
    # raises `TypeError` and aborts LocalCluster startup, erroring out
    # test_stumpy_distributed.py. GPU diagnostics are not needed for these
    # CPU-distributed tests, so switch them off. (case-sensitive value)
    export DASK_DISTRIBUTED__DIAGNOSTICS__NVML=False

    # Allow partial failures here — some packages (e.g. tensorflow-rocm) may not
    # be available for every ROCm/Python version combination.
    python3 -m pip install -r python/cudf/cudf_pandas_tests/third_party_integration_tests/requirements.txt || \
        echo "WARNING: some third-party integration test deps failed to install (e.g. tensorflow-rocm); continuing"

    TIMEOUT_PER_TEST_SEC=240

    run_tests python/cudf/hipdf/tests ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC}
    run_tests python/cudf/cudf/tests ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC}
    if [ "${HIPDF_PYTHON_CUDF_PANDAS_TESTS_XNACK_0}" = "true" ] ; then
        export HSA_XNACK=0
        export CUDF_PANDAS_BYPASS_XNACK_CHECK=1
        run_tests python/cudf/cudf_pandas_tests \
            ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC} "-p cudf.pandas" "_xnack0" "[xnack=0]"
    fi
    export HSA_XNACK=1
    run_tests python/cudf/cudf_pandas_tests \
        ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC} "-p cudf.pandas" "_xnack1" "[xnack=1]"
    run_tests python/pylibcudf/pylibcudf/tests \
        ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC}

#========================
# END of project-specific
#========================

    result=$(merge_test_results ${CSV_OUTPUT_DIR}) || test_failures=1
    echo $result > ${ARTIFACTS_DIR}/${PROJECT_ID}-test-results-py.csv

exit $test_failures
