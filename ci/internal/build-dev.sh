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

# Build hipDF C++ library, and optionally Python bindings and docs.
#
# Required environment variables:
#   PROJECT_ID, SRC_DIR, BUILD_DIR, INSTALL_DIR, BUILD_ARTIFACTS_DIR
#   HIPDF_BUILD_TYPE -- controls what gets built
#
# Optional environment variables:
#   CI_INTERNAL_CREATE_TESTS_TARBALL -- '1' packs the tester tarball (default: 0)

set -euxo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
: "${AMDGPU_TARGETS:?AMDGPU_TARGETS must be set}"
: "${ROCM_PATH:?ROCM_PATH must be set}"

[[ "${HIPDF_BUILD_TYPE:-}" != "install"* ]] && no_install=1
[[ "${HIPDF_BUILD_TYPE:-}" == *"java"* ]] && build_cudfjar=1
[[ "${HIPDF_BUILD_TYPE:-}" == *"all"* ]] && build_python=1
[[ "${HIPDF_BUILD_TYPE:-}" == *"py"* ]] && build_python=1
[[ "${HIPDF_BUILD_DASK_CUDF:-false}" == "true" ]] && build_python=1
[[ "${HIPDF_BUILD_KAFKA:-false}" == "true" ]] && build_python=1
[[ -d ${SRC_DIR}/${PROJECT_ID}/python/pylibcudf ]] && have_pylibcudf=1
[[ "${HIPDF_BUILD_DASK_CUDF:-false}" == "true" ]] && build_dask_cudf=1
[[ "${HIPDF_BUILD_KAFKA:-false}" == "true" ]] && build_kafka=1
[[ "${HIPDF_DEBUG_BUILD:-false}" == "true" ]] && debug_build=1

build_sh_args=(
  libcudf
  tests
  benchmarks
  ${build_python:+${have_pylibcudf:+"pylibcudf"}}
  ${build_python:+"cudf"}
  ${build_dask_cudf:+"dask_cudf"}
  ${build_kafka:+"libcudf_kafka cudf_kafka custreamz"}
  ${build_cudfjar:+"cudfjar"}
  ${debug_build:+"-g"}
  ${no_install:+"-n"}
)

src_dir=${SRC_DIR}/${PROJECT_ID}
build_dir=${BUILD_DIR}/${PROJECT_ID}
build_build_dir=${BUILD_DIR}/${PROJECT_ID}/cpp/build
tests_tarball_name="${PROJECT_ID}-tests.tar.gz"

case "${CI_INTERNAL_CREATE_TESTS_TARBALL:-0}" in
  1 | true | yes | on) create_tests_tarball="1" ;;
  *) create_tests_tarball="" ;;
esac

if [ "${HIPDF_INCREMENTAL_BUILD:-false}" == "true" ]; then
    echo "HIPDF_INCREMENTAL_BUILD=true: skipping clean, reusing ${build_dir}"
else
    rm -rf ${build_dir}
    cp -a ${src_dir} ${build_dir}
    rm -rf ${build_dir}/cpp/build ${build_dir}/java/target
    find ${build_dir}/python -type d -name build -o -name .pytest_cache -o -name __pycache__ 2>/dev/null | xargs rm -rf 2>/dev/null || true
fi

cd ${build_dir}
    . "${SCRIPT_DIR}/_build-preamble.sh"
    . "${SCRIPT_DIR}/_install-build-deps.sh"

    export SHELLOPTS

    _ldflags=(
      -Wl,-O2
      -Wl,--sort-common
      -Wl,--as-needed
      -Wl,-z,relro
      -Wl,-z,now
      -Wl,--disable-new-dtags
      -Wl,--gc-sections
      -Wl,--allow-shlib-undefined
      -Wl,-rpath,/lib/x86_64-linux-gnu
      ${CONDA_PREFIX:+"-Wl,-rpath,${CONDA_PREFIX}/lib"}
      ${CONDA_PREFIX:+"-Wl,-rpath-link,${CONDA_PREFIX}/lib"}
      ${CONDA_PREFIX:+"-L${CONDA_PREFIX}/lib"}
    )
    export LDFLAGS="${_ldflags[*]}"

    export CUDF_CMAKE_HIP_ARCHITECTURES=${AMDGPU_TARGETS}
    export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}:${ROCM_PATH}

    if [[ -n "${no_install:-}" ]]; then
      export INSTALL_PREFIX=${build_build_dir}
    fi

    set +u
    bash build.sh ${build_sh_args[@]} \
     ${cmake_args:+"--cmake-args=\"${cmake_args[@]}\""}
    set -u

    if [ "${HIPDF_BUILD_JAVA:-false}" == "true" ]; then
      cd ${BUILD_DIR}/${PROJECT_ID}/java
      LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-"${ROCM_PATH}/lib:${BUILD_DIR}/${PROJECT_ID}/cpp/build/:${BUILD_DIR}/${PROJECT_ID}/java/target/cmake-build:${BUILD_DIR}/${PROJECT_ID}/java/target/libcudf-install/lib:${BUILD_DIR}/${PROJECT_ID}/java/target/libcudf-cmake-build/lib"}
      set +e
      mvn -B clean package -Dmaven.repo.local="$HOME/.m2/repository" \
          -DLD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
          -DskipTests=true \
          -Dcmake.ccache.opts='-DCMAKE_C_COMPILER_LAUNCHER=ccache \
                              -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
                              -DCMAKE_CUDA_COMPILER_LAUNCHER=ccache \
                              -DCMAKE_CXX_LINKER_LAUNCHER=ccache \
                              -DCMAKE_C_COMPILER=hipcc \
                              -DCMAKE_CXX_COMPILER=hipcc \
                              -DCMAKE_PREFIX_PATH="${ROCM_PATH}/"' \
          -DCUDF_JNI_ENABLE_PROFILING=NO \
          -Dio.netty.tryReflectionSetAccessible=true \
          -DCUDA_STATIC_RUNTIME=ON \
          -DCUDF_USE_PER_THREAD_DEFAULT_STREAM=ON \
          -DUSE_GDS=OFF \
          -DGPU_ARCHS=${AMDGPU_TARGETS} \
          -Dparallel.level=${PARALLEL_LEVEL} \
          -DCUDF_USE_WARPSIZE_32=${HIPDF_USE_WARPSIZE_32} \
          -DCUDF_JNI_LIBCUDF_STATIC=OFF \
          -Dtest=*,!CuFileTest,!CudaFatalTest,!ColumnViewNonEmptyNullsTest
      set -e
    fi

    cd ${BUILD_DIR}/${PROJECT_ID}/cpp/examples
    bash build.sh

    if [ "${HIPDF_BUILD_DOCS:-false}" == "true" ]; then
      cd ${BUILD_DIR}/${PROJECT_ID}/docs
        [ ! -d _venv ] && python3 -m venv _venv --system-site-packages
        . _venv/bin/activate
        python3 -m pip install -r sphinx/requirements.in
        python3 -m sphinx -T -E -b html -d _build/doctrees -D language=en . _build/html
        deactivate
    fi

if [ -n "${create_tests_tarball:-}" ]; then
  dev_venv="${INSTALL_DIR:-}/venv/hipdf_dev"
  [ -d "${dev_venv}" ] || dev_venv=""

  tar --exclude=.git -czf ${BUILD_ARTIFACTS_DIR}/${tests_tarball_name} \
    ${build_dir} ${dev_venv}
  du -sh ${BUILD_ARTIFACTS_DIR}/${tests_tarball_name}
fi
