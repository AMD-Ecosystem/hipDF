# shellcheck shell=bash
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

# Install test dependencies for hipDF. Meant to be sourced, not executed.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- directory containing pre-built dependency wheels

set -euo pipefail

pip install --upgrade pip
# pytest 9.1 dropped a positional parameter from _pytest.python.IdMaker, which
# pytest-cases probes at import time. Since it registers as a global pytest11
# plugin, the resulting TypeError aborts collection for every test file.
pip install 'pytest<9.1' pytest-timeout pytest-csv pytest-benchmark

# Runtime deps required by the cudf test/benchmark suite.
pip install pyarrow cachetools "pandas<2.4.0dev0"

pip install "pytest-rerunfailures!=16.0.0" "pytest-cases>=3.8.2" pytest-xdist "scipy==1.15.3"

# When using a conda env, dependency packages and hipDF itself are already
# installed there. Only install from BUILD_ARTIFACTS_DIR when running outside a
# conda env (e.g. in a pipeline-managed venv).
if [ -z "${HIPDF_CONDA_ENV:-}" ]; then
    specs=(
        "amd-rocmds-logger${ROCMDS_LOGGER_VERSION:+==${ROCMDS_LOGGER_VERSION}}"
        "amd-cupy${HIPDF_AMDCUPY_VERSION:+==${HIPDF_AMDCUPY_VERSION}}"
        "amd-libhipmm${HIPMM_VERSION:+==${HIPMM_VERSION}}"
        rocm-bindings-core
        rocm-bindings-hip
        rocm-bindings-compiler
        hip-python-interop
        "numba-hip${NUMBA_HIP_VERSION:+==${NUMBA_HIP_VERSION}}"
    )

    # hipDF wheels are installed separately by test-wheels.sh.
    pip install --no-deps \
        --find-links "${BUILD_ARTIFACTS_DIR}" \
        "${specs[@]}"

    # dask_cudf suites. dask-hip and hipucxx are not in the manifest
    # ci_packages set, so this stack is optional: when it cannot be installed,
    # clear the switch _test-helpers.sh reads rather than fail the whole run.
    # --no-deps throughout: amd-dask-hip pins the legacy hip-python
    # distributions, which would displace the rocm-bindings wheels above.
    if [ "${HIPDF_TEST_DASK:-0}" = "1" ]; then
        if pip install --no-deps \
               --find-links "${BUILD_ARTIFACTS_DIR}" \
               amd-dask_hipdf amd-dask-hip amd-distributed-hipucxx \
           && pip install "rapids-dask-dependency==26.6.*"; then
            :
        else
            echo "WARNING: dask stack unavailable; skipping dask_cudf suites."
            export HIPDF_TEST_DASK=0
        fi
    fi
fi

# For jupyter notebooks. The `cudf-pandas-tests` extra installs a bare
# `ipykernel`; pin it here to the version the notebook-based tests expect.
pip install ipykernel==7.0.0a0
