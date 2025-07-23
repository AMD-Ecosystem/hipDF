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
# Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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
# =============================================================================

cmake_minimum_required(VERSION 3.30.4 FATAL_ERROR)

include(rapids-cmake)
include(rapids-cpm)
include(rapids-find)

rapids_cpm_init()

# FIXME(HIP/AMD): During the wheel
# build process, the hip target and other targets
# set by find_package(HIP ...) are added multiple
# times, causing the CMake build to fail.
if(NOT TARGET hip)
rapids_find_package(
  HIP REQUIRED
  BUILD_EXPORT_SET udf-exports
  INSTALL_EXPORT_SET udf-exports
)
endif()

# The below is inspired by legate dataframe
execute_process(
  COMMAND "python" -c
          "from numba.cuda.memory_management.nrt import get_include; print(get_include())"
  OUTPUT_VARIABLE NRT_INCLUDE_DIR
  ERROR_VARIABLE NRT_ERROR
  RESULT_VARIABLE NRT_RESULT
  OUTPUT_STRIP_TRAILING_WHITESPACE
)
if(${NRT_RESULT})
  message(
    FATAL_ERROR "Error while trying to obtain numba cuda runtime include directory:\n${NRT_ERROR}"
  )
endif()

include(${rapids-cmake-dir}/cpm/cccl.cmake)
rapids_cpm_cccl(BUILD_EXPORT_SET udf-exports INSTALL_EXPORT_SET udf-exports)

add_library(cudf_strings_udf SHARED strings/src/strings/udf/udf_apis.cu)

target_include_directories(
  cudf_strings_udf PUBLIC "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/strings/include>"
                          "${NRT_INCLUDE_DIR}"
)

set_target_properties(
  cudf_strings_udf
  PROPERTIES BUILD_RPATH "\$ORIGIN/../"
             INSTALL_RPATH "\$ORIGIN/../"
             CXX_STANDARD 20
             CXX_STANDARD_REQUIRED ON
             CUDA_STANDARD 20
             CUDA_STANDARD_REQUIRED ON
             POSITION_INDEPENDENT_CODE ON
             INTERFACE_POSITION_INDEPENDENT_CODE ON
)

set(UDF_CXX_FLAGS)
set(UDF_CUDA_FLAGS)
target_compile_options(
  cudf_strings_udf PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${UDF_CXX_FLAGS}>"
                            "$<$<COMPILE_LANGUAGE:HIP>:${UDF_CUDA_FLAGS}>"
)
target_link_libraries(cudf_strings_udf PUBLIC cudf::cudf)
install(TARGETS cudf_strings_udf DESTINATION ./cudf/_lib/)

# This function will copy the generated PTX file from its generator-specific location in the build
# tree into a specified location in the build tree from which we can install it.
function(copy_ptx_to_location target destination new_name)
  set(cmake_generated_file
      "${CMAKE_CURRENT_BINARY_DIR}/cmake/cp_${target}_$<LOWER_CASE:$<CONFIG>>_ptx.cmake"
  )
  file(
    GENERATE
    OUTPUT "${cmake_generated_file}"
    CONTENT
      "
set(ptx_path \"$<TARGET_OBJECTS:${target}>\")
file(MAKE_DIRECTORY \"${destination}\")
file(COPY_FILE \${ptx_path} \"${destination}/${new_name}\")"
  )

  add_custom_target(
    ${target}_cp_ptx ALL
    COMMAND ${CMAKE_COMMAND} -P "${cmake_generated_file}"
    DEPENDS $<TARGET_OBJECTS:${target}>
    COMMENT "Copying PTX files to '${destination}'"
  )
endfunction()

# Create the shim library for each architecture.
set(SHIM_HIP_FLAGS -fgpu-rdc -S -emit-llvm)

# always build a default PTX file in case RAPIDS_NO_INITIALIZE is set and the device cc can't be
# safely queried through a context
# TODO(HIP/AMD): Using RAPIDS_NO_INITIALIZE is currently not supported/used in hipDF

list(SORT CMAKE_HIP_ARCHITECTURES)
list(REMOVE_DUPLICATES CMAKE_HIP_ARCHITECTURES) 

set(tgt "shim_") # NOTE: we keep the suffix "_" because of code in python/cudf/cudf/core/udf/utils.py
add_library(${tgt} OBJECT shim.cu)
target_include_directories(
  shim PUBLIC "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/strings/include>" "${NRT_INCLUDE_DIR}"
)

copy_ptx_to_location(${tgt} "${CMAKE_CURRENT_BINARY_DIR}/../udf" ${tgt}.ll)
install(
  FILES $<TARGET_OBJECTS:${tgt}>
  DESTINATION cudf/core/udf/
  RENAME ${tgt}.ll
)
