# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2024-2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on
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

# NOTE(HIP/AMD): make *.cu files HIP lang files - MUST be set before project()
set(CMAKE_USER_MAKE_RULES_OVERRIDE "${CMAKE_CURRENT_LIST_DIR}/../../overrides.cmake")

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

# TODO(HIP/AMD): hipcomp is not shipped as wheel yet option(USE_HIPCOMP_RUNTIME_WHEEL "Use the
# hipcomp wheel at runtime instead of vendoring hipcomp" OFF)
set(USE_HIPCOMP_RUNTIME_WHEEL OFF)

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

include(../../cpp/cmake/thirdparty/get_nvcomp.cmake)

# <<<<<<< OLD CODE from 0214b0a419 (ca93d33343) - COMMENTED OUT
# # NOTE(HIP/AMD): hipcomp is built from source via CPM, not imported as a prebuilt library. The
# # installation of hipcomp is handled by the main cudf build (add_subdirectory below), so we don't
# # need to explicitly install it here like nvcomp does in CUDA builds. Just verify the target exists.
# if(NOT TARGET hipcomp)
#   message(FATAL_ERROR "hipcomp target not found")
# =======
# Install only the specific libnvcomp.so.* library instead of all nvcomp targets
if(NOT USE_NVCOMP_RUNTIME_WHEEL)
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
# >>>>>>> END NEW CODE (ca93d33343)
endif()
# <<<<<<< OLD CODE from f03d37aeb3 (10e5073a31) - COMMENTED OUT
# set(CUDA_STATIC_RUNTIME OFF) # NOTE(HIP/AMD): Unsupported.
# =======
# >>>>>>> END NEW CODE (10e5073a31)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib)

add_subdirectory(../../cpp cudf-cpp)
# <<<<<<< OLD CODE from 0214b0a419 (ca93d33343) - COMMENTED OUT
#
# # TODO(HIP/AMD): Enable when hipcomp wheel becomes available
# if(USE_HIPCOMP_RUNTIME_WHEEL)
#   set(rpaths "$ORIGIN/../../amd/hipcomp")
#   set_property(
#     TARGET cudf
#     PROPERTY INSTALL_RPATH ${rpaths}
#     APPEND
#   )
# endif()
# =======
# >>>>>>> END NEW CODE (ca93d33343)
