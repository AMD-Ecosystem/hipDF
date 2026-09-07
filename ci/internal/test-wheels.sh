#!/usr/bin/env bash
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

# Test hipDF wheels in an isolated venv, using the interpreter on PATH.
#
# Required environment variables:
#   PROJECT_ID, BUILD_DIR, BUILD_ARTIFACTS_DIR, ARTIFACTS_DIR
#
# Optional environment variables:
#   HIPDF_TEST_RESULTS_SUFFIX -- appended to the pytest output dir and CSV name

set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${ARTIFACTS_DIR:?ARTIFACTS_DIR must be set}"

source "${SCRIPT_DIR}/_test-helpers.sh"

wheels_test_env=$(mktemp -d)
python3 -m venv ${wheels_test_env}
. ${wheels_test_env}/bin/activate

  pip install --upgrade pip
  . "${SCRIPT_DIR}/_install-test-deps.sh"

  shopt -s nullglob
  specs=()
  for wheel in "${BUILD_ARTIFACTS_DIR}"/amd_libhipdf*.whl \
               "${BUILD_ARTIFACTS_DIR}"/amd_pylibhipdf*.whl \
               "${BUILD_ARTIFACTS_DIR}"/amd_hipdf*.whl; do
    IFS=- read -r dist version _ <<<"$(basename "${wheel}")"
    specs+=("${dist}==${version}")
  done
  shopt -u nullglob

  if [ ${#specs[@]} -eq 0 ]; then
    echo "ERROR: no hipDF wheels in ${BUILD_ARTIFACTS_DIR}; nothing to test." >&2
    exit 1
  fi

  mapfile -t specs < <(printf '%s\n' "${specs[@]}" | sort -u)

  pip install --find-links "${BUILD_ARTIFACTS_DIR}" "${specs[@]}"

  pip install --find-links "${BUILD_ARTIFACTS_DIR}" \
    "amd-hipdf[test,cudf-pandas-tests]"

  test_failures=0
  cd ${BUILD_DIR}/${PROJECT_ID}

      results_suffix=${HIPDF_TEST_RESULTS_SUFFIX:+-${HIPDF_TEST_RESULTS_SUFFIX}}
      CSV_OUTPUT_DIR=${PROJECT_ID}_pytest_output${results_suffix}
      TIMEOUT_PER_TEST_SEC=240

      run_hipdf_test_suites ${CSV_OUTPUT_DIR} ${TIMEOUT_PER_TEST_SEC}

      result=$(merge_test_results ${CSV_OUTPUT_DIR}) || test_failures=1
      echo $result > ${ARTIFACTS_DIR}/${PROJECT_ID}-test-results-py${results_suffix}.csv

deactivate
rm -rf ${wheels_test_env}

exit $test_failures
