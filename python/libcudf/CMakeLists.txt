# =============================================================================
# Copyright (c) 2024-2025, NVIDIA CORPORATION.
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

cmake_minimum_required(VERSION 3.30.4 FATAL_ERROR)

include(../../cmake/rapids_config.cmake)
include(rapids-cpm)
include(rapids-hip)
rapids_hip_init_architectures(libcudf-python)
rapids_cpm_init()

project(
  libcudf-python
  VERSION "${RAPIDS_VERSION}"
  LANGUAGES CXX HIP
)

option(USE_NVCOMP_RUNTIME_WHEEL "Use the nvcomp wheel at runtime instead of vendoring nvcomp" OFF)

# Check if cudf is already available. If so, it is the user's responsibility to ensure that the
# CMake package is also available at build time of the Python cudf package.
find_package(cudf "${RAPIDS_VERSION}")

if(cudf_FOUND)
  return()
endif()

unset(cudf_FOUND)

set(BUILD_TESTS OFF)
set(BUILD_BENCHMARKS OFF)
set(CUDF_BUILD_TESTUTIL OFF)
set(CUDF_BUILD_STREAMS_TEST_UTIL OFF)
set(CUDF_EXPORT_NVCOMP OFF)

include(../../cpp/cmake/thirdparty/get_nvcomp.cmake)

# Install only the specific libnvcomp.so.* library instead of all nvcomp targets
if(TARGET nvcomp::nvcomp)
  get_target_property(is_imported nvcomp::nvcomp IMPORTED)
  if(is_imported)
    get_target_property(nvcomp_lib_path nvcomp::nvcomp IMPORTED_LOCATION_RELEASE)
    # Compute the SOVERSION from the library path
    get_filename_component(nvcomp_lib_dir ${nvcomp_lib_path} DIRECTORY)
    get_filename_component(nvcomp_lib_name ${nvcomp_lib_path} NAME)
    string(REGEX REPLACE "^libnvcomp\\.so\\.([0-9]+).*$" "\\1" nvcomp_soversion_major
                         ${nvcomp_lib_name}
    )
    install(
      FILES ${nvcomp_lib_path}
      DESTINATION ${SKBUILD_PLATLIB_DIR}/libcudf/lib64/
      RENAME libnvcomp.so.${nvcomp_soversion_major}
    )
  else()
    message(FATAL_ERROR "nvcomp target must be imported")
  endif()
else()
  message(FATAL_ERROR "nvcomp target not found")
endif()
set(CUDA_STATIC_RUNTIME OFF) # NOTE(HIP/AMD): Unsupported.

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)

add_subdirectory(../../cpp cudf-cpp)

if(USE_NVCOMP_RUNTIME_WHEEL)
  set(rpaths "$ORIGIN/../../nvidia/nvcomp")
  set_property(
    TARGET cudf
    PROPERTY INSTALL_RPATH ${rpaths}
    APPEND
  )
endif()
