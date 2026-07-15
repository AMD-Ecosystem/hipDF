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

src_dir=${SRC_DIR}/${PROJECT_ID}
wheels_build_dir=${BUILD_DIR}/_WHEELS_/
build_dir="${wheels_build_dir}/${PROJECT_ID}"
tests_tarball_name="${PROJECT_ID}-tests.tar.gz"

WHEEL_ARGS=(
    -v
    --no-deps
    --no-build-isolation
    --disable-pip-version-check
    --config-settings=rapidsai.disable-cuda=true
    --config-settings=build.verbose=true
    --config-settings=logging.level=INFO
)

mkdir -p ${wheels_build_dir}
cp -va ${src_dir}/. ${build_dir}/

function build_libhipdf_wheel() {
    # Build libhipdf C++ wheel
    # Args: $1 - optional extra CMAKE args
    if [ -d ${build_dir}/python/libcudf ]; then
        cd ${build_dir}/python/libcudf
        local dist_dir="$(mktemp -d)"

        # Apply extra CMAKE args if provided
        if [ -n "${1:-}" ]; then
            local saved_cmake_args="${SKBUILD_CMAKE_ARGS}"
            export SKBUILD_CMAKE_ARGS="${SKBUILD_CMAKE_ARGS};${1}"
        fi

        python3 -m pip wheel . "${WHEEL_ARGS[@]}" -w "${dist_dir}"

        # Restore CMAKE args if we modified them
        if [ -n "${1:-}" ]; then
            export SKBUILD_CMAKE_ARGS="${saved_cmake_args}"
        fi

        python3 -m auditwheel repair \
            --exclude "*" \
            -w "${BUILD_ARTIFACTS_DIR}" \
            "${dist_dir}"/*

        rm -rf "${dist_dir}"
    fi
}

function build_pylibhipdf_wheel() {
    # Build pylibhipdf C++ bindings wheel
    # Args: $1 - optional extra CMAKE args
    if [ -d ${build_dir}/python/pylibcudf ]; then
        cd ${build_dir}/python/pylibcudf
        local dist_dir="$(mktemp -d)"

        python3 -m pip wheel . "${WHEEL_ARGS[@]}" -w "${dist_dir}"

        # Exclude HIP runtime and system libraries from wheel
        python3 -m auditwheel repair \
            --exclude "*" \
            -w "${BUILD_ARTIFACTS_DIR}" \
            "${dist_dir}"/*

        rm -rf "${dist_dir}"
    fi
}

function build_hipdf_wheel() {
    # Build main hipdf Python wheel
    # Args: $1 - optional extra CMAKE args
    cd ${build_dir}/python/cudf
        local dist_dir="$(mktemp -d)"

        python3 -m pip wheel . "${WHEEL_ARGS[@]}" -w "${dist_dir}"

        python3 -m auditwheel repair \
            --exclude "*" \
            -w "${BUILD_ARTIFACTS_DIR}" \
            "${dist_dir}"/*

        rm -rf "${dist_dir}"
}

function build_dask_cudf_wheel() {
    # Build dask_cudf wheel (if enabled)
    if [[ "${HIPDF_BUILD_DASK_CUDF}" == "true" ]]; then
        cd ${build_dir}/python/dask_cudf
        local dist_dir="$(mktemp -d)"

        python3 -m pip wheel . "${WHEEL_ARGS[@]}" -w "${dist_dir}"

        python3 -m auditwheel repair \
            --exclude "*" \
            -w "${BUILD_ARTIFACTS_DIR}" \
            "${dist_dir}"/*

        rm -rf "${dist_dir}"
    fi
}

function build_kafka_wheels() {
    # Build Kafka-related wheels (if enabled)
    if [[ "${HIPDF_BUILD_KAFKA}" == "true" ]]; then
        # Build cudf_kafka wheel
        if [ -d ${build_dir}/python/cudf_kafka ]; then
            cd ${build_dir}/python/cudf_kafka
            local dist_dir="$(mktemp -d)"

            python3 -m pip wheel . "${WHEEL_ARGS[@]}" -w "${dist_dir}"

            python3 -m auditwheel repair \
                --exclude "*" \
                -w "${BUILD_ARTIFACTS_DIR}" \
                "${dist_dir}"/*

            rm -rf "${dist_dir}"
        fi

        # Build custreamz wheel
        if [ -d ${build_dir}/python/custreamz ]; then
            cd ${build_dir}/python/custreamz
            local dist_dir="$(mktemp -d)"

            python3 -m pip wheel . "${WHEEL_ARGS[@]}" -w "${dist_dir}"

            python3 -m auditwheel repair \
                --exclude "*" \
                -w "${BUILD_ARTIFACTS_DIR}" \
                "${dist_dir}"/*

            rm -rf "${dist_dir}"
        fi
    fi
}

cd ${build_dir}
    . "${SCRIPT_DIR}/_build-preamble.sh"

    # Setup wheel build environment
    # NOTE(HIP/AMD): Export CC/CXX as environment variables instead of passing
    # CMAKE_C_COMPILER/CMAKE_CXX_COMPILER in cmake_args. This prevents CMake
    # from detecting "compiler changed" during re-configuration, which would
    # wipe the cache and drop all CPM_*_SOURCE overrides from _build-preamble.sh.
    export CC=hipcc
    export CXX=hipcc
    cmake_args+=( # from preamble
        "-DAMDGPU_TARGETS=${AMDGPU_TARGETS}"
        "-DCMAKE_HIP_ARCHITECTURES=${AMDGPU_TARGETS}"
        "-DGPU_TARGETS=${AMDGPU_TARGETS}"
    )
    # shellcheck disable=SC2155
    export SKBUILD_CMAKE_ARGS=$(echo "${cmake_args[@]}" | tr ' ' ';')
    export RAPIDS_DISABLE_CUDA=true
    export CUDF_CMAKE_HIP_ARCHITECTURES=${AMDGPU_TARGETS}

    [ ! -d _venv ] && python3 -m venv _venv
    source _venv/bin/activate

    . "${SCRIPT_DIR}/_install-build-requirements.sh"
    pip install wheel auditwheel Cython scikit-build-core \
                patchelf
    pip install rapids-build-backend
    pip install --upgrade cmake${CMAKE_VERSION:+==${CMAKE_VERSION}}
    pip install ninja

    printenv

    # Build wheels in dependency order (disable finding pre-installed packages)
    build_libhipdf_wheel "-DCMAKE_DISABLE_FIND_PACKAGE_rmm=ON;-DCMAKE_DISABLE_FIND_PACKAGE_cudf=ON"

    # Install libhipdf wheel if it was built (will be used by subsequent builds)
    if ls ${BUILD_ARTIFACTS_DIR}/amd_libhipdf*.whl 1> /dev/null 2>&1; then
        pip install ${BUILD_ARTIFACTS_DIR}/amd_libhipdf*.whl
    fi

    build_pylibhipdf_wheel

    # Install pylibhipdf wheel if it was built (will be used by subsequent builds)
    if ls ${BUILD_ARTIFACTS_DIR}/amd_pylibhipdf*.whl 1> /dev/null 2>&1; then
        pip install ${BUILD_ARTIFACTS_DIR}/amd_pylibhipdf*.whl
    fi

    build_hipdf_wheel

    # note: hipdf wheel is not a build dependency as
    #       C++ and Cython files are shipped by
    #       pylibhipdf and libhipdf wheels.
    # note: If installing hipDF becomes necessary top build one of the wheels #       below, we will need to install its runtime dependencies as well.

    #build_dask_cudf_wheel
    #build_kafka_wheels

    # cleanup
    deactivate # deactivate venv
    rm -rf _venv

rm -rf ${build_dir}
