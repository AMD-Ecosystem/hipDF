# shellcheck shell=bash
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

# NOTE: meant to be sourced
pip install --upgrade pip
pip install pytest pytest-timeout pytest-csv pytest-benchmark

# When using a conda env, dependency packages (hip_python, cupy, hipmm, etc.)
# and the hipDF packages themselves are already installed there. Only install
# from BUILD_ARTIFACTS_DIR when running outside a conda env (e.g. in a
# pipeline-managed venv).
if [ -z "${HIPDF_CONDA_ENV:-}" ]; then
    pip install ${BUILD_ARTIFACTS_DIR}/hip_python*.whl \
                ${BUILD_ARTIFACTS_DIR}/rocm_bindings*.whl \
                ${BUILD_ARTIFACTS_DIR}/*rocmds_logger*.whl \
                ${BUILD_ARTIFACTS_DIR}/numba_hip*.whl \
                ${BUILD_ARTIFACTS_DIR}/*cupy*.whl \
                ${BUILD_ARTIFACTS_DIR}/*hipmm*.whl

    # Install the hipDF packages under test. In the venv flow these are not
    # otherwise present (build-wheels.sh installs them only into a throwaway
    # venv, and _build-preamble.sh clears ${INSTALL_DIR}/venv/hipdf_dev), so the
    # test modules cannot `import cudf` without this. Installed in dependency
    # order: libhipdf (C++), pylibhipdf (bindings), then hipdf.
    pip install ${BUILD_ARTIFACTS_DIR}/amd_libhipdf*.whl \
                ${BUILD_ARTIFACTS_DIR}/amd_pylibhipdf*.whl \
                ${BUILD_ARTIFACTS_DIR}/amd_hipdf*.whl
fi

# note: for jupyter notebooks
pip install ipykernel==7.0.0a0
