# =============================================================================
# Copyright (c) 2022-2025, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.
# =============================================================================

# MIT License
#
# Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
# NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
# OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

cmake_minimum_required(VERSION 3.30.4 FATAL_ERROR)

include(../../cmake/rapids_config.cmake)
include(rapids-cuda)
rapids_cuda_init_architectures(pylibcudf)

# For now, disable CMake's automatic module scanning for C++ files. There is an sccache bug in the
# version RAPIDS uses in CI that causes it to handle the resulting -M* flags incorrectly with
# gcc>=14. We can remove this once we upgrade to a newer sccache version.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

project(
  pylibcudf
  VERSION "${RAPIDS_VERSION}"
  LANGUAGES CXX HIP
)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(IS_DIRECTORY "/opt/rocm")
  list(APPEND CMAKE_PREFIX_PATH "/opt/rocm")
else()
  message(WARNING "/opt/rocm not found. ROCm transitive dependencies (libhipcxx, rocthrust, etc.) "
                  "may not be discoverable, which will likely cause build failures.")
endif()

find_package(cudf "${RAPIDS_VERSION}" REQUIRED)

# an installed version of libcudf doesn't provide the dlpack headers so we need to download dlpack
# for the interop.pyx
include(rapids-cpm)
rapids_cpm_init()
include(../../cpp/cmake/thirdparty/get_dlpack.cmake)

include(rapids-cython-core)

rapids_cython_init()

add_subdirectory(pylibcudf)
