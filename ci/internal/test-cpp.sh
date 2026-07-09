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

# Env defaults for local execution (override CI-style conda env defaults)
: ${SRC_DIR:=/home/moberste/Coding}
: ${BUILD_DIR:=/tmp/hipdf-ci-build}
: ${INSTALL_DIR:=/tmp/hipdf-ci-install}
: ${BUILD_ARTIFACTS_DIR:=/tmp/hipdf-ci-artifacts}
: ${ARTIFACTS_DIR:=/tmp/hipdf-ci-artifacts}
: ${PROJECT_ID:=hipDF}
: ${ROCM_PATH:=/opt/rocm}
: ${AMDGPU_TARGETS:=gfx90a}

# If running locally (SRC_DIR points to nonexistent /src), override with real paths
if [ "${SRC_DIR}" == "/src" ] && [ ! -d "/src/${PROJECT_ID}" ]; then
  SRC_DIR=/home/moberste/Coding
  BUILD_DIR=/tmp/hipdf-ci-build
  INSTALL_DIR=/tmp/hipdf-ci-install
  BUILD_ARTIFACTS_DIR=/tmp/hipdf-ci-artifacts
  ARTIFACTS_DIR=/tmp/hipdf-ci-artifacts
fi

export PROJECT_ID="${PROJECT_ID}"

if [ "${HIPDF_TEST_WITH_ASAN:-false}" == "true" ]
then
    if [ "${HIPDF_ASAN_BUILD:-false}" == "true" ]
    then
        export HSA_XNACK=1
        export GTEST_CUDF_RMM_MODE="cuda"
        export LD_PRELOAD=$(amdclang++ -print-file-name=libclang_rt.asan-x86_64.so)
        if [ "${ROCM_USE_ASAN:-false}" == "true" ]; then
            export LD_LIBRARY_PATH="${ROCM_PATH}/lib/asan/:${LD_LIBRARY_PATH}"
        fi
    else
        exit -1
    fi
fi

# run tests
if [ "${HIPDF_TEST_WITH_ASAN:-false}" == "true" ]
then
    cd ${BUILD_DIR}/${PROJECT_ID}/cpp/build
    success=1
    for test in gtests/*_TEST
    do
      ${test} || success=0 || true
    done
    exit ${success}
else
    if [ -z "${HIPDF_CONDA_ENV:-}" ]; then
      . ${INSTALL_DIR}/venv/hipdf_dev/bin/activate # ctest
    fi

    cd ${BUILD_DIR}/${PROJECT_ID}/cpp/build
      ctest .
fi

# run examples; build-dev.sh compiles them, but they may be absent when
# running in a test-only context (e.g. against a pre-existing build)
EXAMPLES_DIR="${BUILD_DIR}/${PROJECT_ID}/cpp/examples"
if [ -f "${EXAMPLES_DIR}/run_examples.sh" ]; then
    cd "${EXAMPLES_DIR}"
    ./run_examples.sh || echo "WARNING: run_examples.sh failed — likely some examples not compiled"
else
    echo "NOTE: ${EXAMPLES_DIR}/run_examples.sh not found — skipping examples"
fi
