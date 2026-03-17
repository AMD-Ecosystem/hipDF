# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2024-2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on

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

include(../set_cuda_architecture.cmake)

# initialize cuda architecture
rapids_hip_init_architectures(parquet_io)

project(
  parquet_io
  VERSION 0.0.1
  LANGUAGES CXX HIP
)

include(../fetch_dependencies.cmake)

include(rapids-cmake)
rapids_cmake_build_type("Release")

find_package(Threads REQUIRED) # note: pthread required for parquet_io_multithreaded

# For now, disable CMake's automatic module scanning for C++ files. There is an sccache bug in the
# version RAPIDS uses in CI that causes it to handle the resulting -M* flags incorrectly with
# gcc>=14. We can remove this once we upgrade to a newer sccache version.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

add_library(parquet_io_utils OBJECT common_utils.cpp io_source.cpp)
target_compile_features(parquet_io_utils PRIVATE cxx_std_20)
target_link_libraries(parquet_io_utils PRIVATE cudf::cudf)

# <<<<<<< OLD CODE from 830085513b (43aecf4696) - COMMENTED OUT
# # Build and install parquet_io
# add_executable(parquet_io parquet_io.cpp)
# # TODO(HIP/AMD): Re-enable once nvtx equivalent is available
# target_link_libraries(parquet_io PRIVATE cudf::cudf $<TARGET_OBJECTS:parquet_io_utils>)
# # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp>)
# target_compile_features(parquet_io PRIVATE cxx_std_20)
# install(TARGETS parquet_io DESTINATION bin/examples/libcudf/parquet_io)
#
# # Build and install parquet_io_multithreaded
# add_executable(parquet_io_multithreaded parquet_io_multithreaded.cpp)
# target_link_libraries(
#   parquet_io_multithreaded
#   PRIVATE
#     cudf::cudf
#     Threads::Threads
#     $<TARGET_OBJECTS:parquet_io_utils> # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD):
#                                        # Re-enable once nvtx equivalent is available
# )
# target_compile_features(parquet_io_multithreaded PRIVATE cxx_std_20)
# install(TARGETS parquet_io_multithreaded DESTINATION bin/examples/libcudf/parquet_io)
# =======
# Creates a parquet I/O example executable and installs it.
#
# Arguments: target_name  - Name of the CMake target and resulting executable source_file  - Source
# file to compile for the example
function(add_parquet_io_example target_name source_file)
  add_executable(${target_name} ${source_file})
  target_link_libraries(
    ${target_name} PRIVATE cudf::cudf $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp>
                           $<TARGET_OBJECTS:parquet_io_utils>
  )
  target_compile_features(${target_name} PRIVATE cxx_std_20)
  install(TARGETS ${target_name} DESTINATION bin/examples/libcudf/parquet_io)
endfunction()

add_parquet_io_example(parquet_io parquet_io.cpp)
add_parquet_io_example(parquet_io_multithreaded parquet_io_multithreaded.cpp)
# >>>>>>> END NEW CODE (43aecf4696)

# Install the example.parquet file
install(FILES ${CMAKE_CURRENT_LIST_DIR}/example.parquet DESTINATION bin/examples/libcudf/parquet_io)
