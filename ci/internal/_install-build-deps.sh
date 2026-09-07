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

# Install build dependencies for hipDF.
# Meant to be sourced, not executed directly.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- directory containing pre-built dependency wheels
#   HIPDF_BUILD_TYPE    -- controls which dependencies to install
#   CMAKE_VERSION       -- the version of the cmake package to install

set -euo pipefail

pip install --upgrade pip

case "${HIPDF_BUILD_TYPE:-}" in
  all|cpp_py|cpp_wheels|wheels|install_all|install_cpp_py|install_cpp_wheels)
    if [ -z "${HIPDF_CONDA_ENV:-}" ]; then
      specs=(
        amd-rocmds-logger
        amd-libhipmm
      )

      need_hip_python_deps=0
      [[ "${HIPDF_BUILD_TYPE:-}" == *py* ]] && need_hip_python_deps=1
      hipdf_build_libhipdf=${HIPDF_BUILD_LIBHIPDF-1}
      hipdf_build_pylibcudf=${HIPDF_BUILD_PYLIBCUDF-1}
      hipdf_build_hipdf=${HIPDF_BUILD_HIPDF-1}
      [[ -n "${hipdf_build_pylibcudf}" || -n "${hipdf_build_hipdf}" ]] && need_hip_python_deps=1

      if [ "${need_hip_python_deps}" -eq 1 ]; then
        specs+=(
          rocm-bindings-core
          rocm-bindings-hip
          hip-python-interop
        )
      fi

      pip install --no-deps \
          --find-links "${BUILD_ARTIFACTS_DIR}" \
          "${specs[@]}"
    fi
    ;;
esac

pip install wheel auditwheel Cython scikit-build-core \
            patchelf
pip install --force-reinstall "cmake==${CMAKE_VERSION}"
pip install ninja

pip install rapids-build-backend
