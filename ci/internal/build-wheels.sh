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

# Build hipDF Python wheels with the interpreter on PATH.
#
# Required environment variables:
#   PROJECT_ID, SRC_DIR, BUILD_DIR, INSTALL_DIR, BUILD_ARTIFACTS_DIR
#   AMDGPU_TARGETS, ROCM_PATH
#
# Optional environment variables:
#   HIPDF_BUILD_TYPE, CMAKE_VERSION
#   USE_SABI -- "no", or the stable-ABI floor for pylibhipdf and hipdf, e.g. "3.12"
#   HIPDF_BUILD_{LIBHIPDF,PYLIBCUDF,HIPDF,DASK_HIPDF} -- set empty to skip a wheel

set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_wheel-helpers.sh"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${AMDGPU_TARGETS:?AMDGPU_TARGETS must be set}"
: "${ROCM_PATH:?ROCM_PATH must be set}"

build_libhipdf=${HIPDF_BUILD_LIBHIPDF-1}
build_pylibcudf=${HIPDF_BUILD_PYLIBCUDF-1}
build_hipdf=${HIPDF_BUILD_HIPDF-1}
build_dask_hipdf=${HIPDF_BUILD_DASK_HIPDF-1}

if [ "${USE_SABI:-no}" = "no" ]; then
  hipdf_wheel_config=(--config-settings=skbuild.wheel.py-api=)
else
  hipdf_wheel_config=(--config-settings=skbuild.wheel.py-api=cp${USE_SABI//./})
fi

src_dir=${SRC_DIR}/${PROJECT_ID}
wheels_build_dir=${BUILD_DIR}/_WHEELS_/
build_dir="${wheels_build_dir}/${PROJECT_ID}"

mkdir -p ${wheels_build_dir}
cp -va ${src_dir}/. ${build_dir}/

cd ${build_dir}
    . "${SCRIPT_DIR}/_build-preamble.sh"

    export CC=hipcc
    export CXX=hipcc
    cmake_args+=(
        "-DAMDGPU_TARGETS=${AMDGPU_TARGETS}"
        "-DCMAKE_HIP_ARCHITECTURES=${AMDGPU_TARGETS}"
        "-DGPU_TARGETS=${AMDGPU_TARGETS}"
    )
    export SKBUILD_CMAKE_ARGS="$(IFS=';'; echo "${cmake_args[*]}")"
    export RAPIDS_DISABLE_CUDA=true
    export CUDF_CMAKE_HIP_ARCHITECTURES=${AMDGPU_TARGETS}
    export WHEEL_BUILD_ROOT="${build_dir}"

    wheels_build_env=$(mktemp -d)
    python3 -m venv ${wheels_build_env}
    . ${wheels_build_env}/bin/activate

        . "${SCRIPT_DIR}/_install-build-deps.sh"

        if [ -n "${build_libhipdf}" ]; then
          # note: only cudf is disabled, so that the C++ library is built here instead of being
          # taken from ${INSTALL_DIR}. rmm has to stay findable in the amd-libhipmm wheel installed
          # above -- a CPM source build installs the rmm headers into this wheel.
          build_rapids_wheel "python/libcudf" "-DCMAKE_DISABLE_FIND_PACKAGE_cudf=ON"
          verify_wheel_absent 'amd_libhipdf*.whl' 'rmm/|librmm|libhipmm'
        fi

        if [ -n "${build_pylibcudf}" ]; then
          # note: load-bearing -- find_package(cudf) resolves here, and --no-build-isolation
          # means pip installs nothing from [tool.rapids-build-backend] requires itself.
          pip install ${BUILD_ARTIFACTS_DIR}/amd_libhipdf*.whl
          build_rapids_wheel "python/pylibcudf" "" "${hipdf_wheel_config[@]}"
        fi

        if [ -n "${build_hipdf}" ]; then
          # note: both load-bearing -- find_package(cudf) resolves in the first, the pylibhipdf
          # cimports in the second.
          pip install ${BUILD_ARTIFACTS_DIR}/amd_libhipdf*.whl
          pip install ${BUILD_ARTIFACTS_DIR}/amd_pylibhipdf*.whl
          build_rapids_wheel "python/cudf" "" "${hipdf_wheel_config[@]}"
        fi

        if [ -n "${build_dask_hipdf}" ]; then
          # note: pure Python on setuptools, so nothing here is built against the other wheels
          # and the resulting py3-none-any wheel is the same for every interpreter.
          build_setuptools_wheel "python/dask_cudf"
        fi

    deactivate
    rm -rf ${wheels_build_env}

rm -rf ${build_dir}
