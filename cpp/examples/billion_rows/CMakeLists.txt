# Copyright (c) 2024-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

include(../set_cuda_architecture.cmake)

# initialize cuda architecture
rapids_hip_init_architectures(billion_rows)

project(
  billion_rows
  VERSION 0.0.1
  LANGUAGES CXX HIP
)

include(../fetch_dependencies.cmake)

include(rapids-cmake)
rapids_cmake_build_type("Release")

list(APPEND CUDF_CUDA_FLAGS --expt-extended-lambda --expt-relaxed-constexpr)

add_library(groupby_results OBJECT groupby_results.cpp)
target_link_libraries(groupby_results PRIVATE cudf::cudf)

add_executable(brc brc.cpp)
target_link_libraries(brc PRIVATE cudf::cudf $<TARGET_OBJECTS:groupby_results>) # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp>) # TODO(HIP/AMD): Reenable once nvtx equivalent is available
install(TARGETS brc DESTINATION bin/examples/libcudf)

add_executable(brc_chunks brc_chunks.cpp)
target_link_libraries(brc_chunks PRIVATE cudf::cudf $<TARGET_OBJECTS:groupby_results>) # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp>) # TODO(HIP/AMD): Reenable once nvtx equivalent is available
install(TARGETS brc_chunks DESTINATION bin/examples/libcudf)

add_executable(brc_pipeline brc_pipeline.cpp)
target_link_libraries(brc_pipeline PRIVATE cudf::cudf $<TARGET_OBJECTS:groupby_results>) # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp>) # TODO(HIP/AMD): Reenable once nvtx equivalent is available
install(TARGETS brc_pipeline DESTINATION bin/examples/libcudf)
