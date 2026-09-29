#!/usr/bin/env bash
# MIT License
#
# Copyright (C) 2026 Advanced Micro Devices, Inc.
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

set -xeu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_test-helpers.sh"
source "${SCRIPT_DIR}/_activate-env.sh"

if ! activate_hipdf_conda_env; then
    . ${INSTALL_DIR}/venv/hipdf_dev/bin/activate
fi

test_failures=0
cd ${BUILD_DIR}/${PROJECT_ID}
    export LD_LIBRARY_PATH="${BUILD_DIR}/${PROJECT_ID}/cpp/build${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

    . "${SCRIPT_DIR}/_install-test-deps.sh"

    CSV_OUTPUT_DIR=${PROJECT_ID}_pytest_output
    TIMEOUT_PER_TEST_SEC=240

    run_hipdf_test_suites ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC}

    merge_test_results ${CSV_OUTPUT_DIR} \
        > ${ARTIFACTS_DIR}/${PROJECT_ID}-test-results-py.csv || test_failures=1

exit $test_failures
