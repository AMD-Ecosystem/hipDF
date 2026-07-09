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

export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}:${ROCM_PATH}/lib/cmake

export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${BUILD_DIR}/${PROJECT_ID}/cpp/build/:${BUILD_DIR}/${PROJECT_ID}/java/target/cmake-build:${BUILD_DIR}/${PROJECT_ID}/java/target/cmake-build/lib:${BUILD_DIR}/${PROJECT_ID}/java/target/libcudf-install/lib:${BUILD_DIR}/${PROJECT_ID}/java/target/libcudf-cmake-build/lib"

export PARALLEL_LEVEL=${MAX_JOBS:-1}

cd ${BUILD_DIR}/${PROJECT_ID}/java
  mvn test \
  -DLD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
  -Dmaven.repo.local="${HOME}/.m2/repository" \
  -DskipTests=false \
  -Dcmake.ccache.opts="-DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CUDA_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_LINKER_LAUNCHER=ccache \
  -DCMAKE_C_COMPILER=hipcc \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_PREFIX_PATH=\"${ROCM_PATH}/\"" \
  -DCUDF_JNI_ENABLE_PROFILING=NO \
  -Dio.netty.tryReflectionSetAccessible=true \
  -DCUDA_STATIC_RUNTIME=ON \
  -DCUDF_USE_PER_THREAD_DEFAULT_STREAM=ON \
  -DUSE_GDS=OFF \
  -DGPU_ARCHS=${AMDGPU_TARGETS} \
  -Dparallel.level=${PARALLEL_LEVEL} \
  -DCUDF_JNI_LIBCUDF_STATIC=OFF \
  -DfailIfNoTests=false \
  -DCUDF_CPP_BUILD_DIR="${BUILD_DIR}/${PROJECT_ID}/java/target/libcudf-cmake-build" \
      -Dtest=*,!CuFileTest,!ColumnViewNonEmptyNullsTest
