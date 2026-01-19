# Copyright (c) 2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

# initialize hip architecture
rapids_hip_init_architectures(string_transforms_examples)

project(
  string_transforms_examples
  VERSION 0.0.1
  LANGUAGES CXX HIP
)

include(../fetch_dependencies.cmake)

include(rapids-cmake)
rapids_cmake_build_type("Release")

# For now, disable CMake's automatic module scanning for C++ files. There is an sccache bug in the
# version RAPIDS uses in CI that causes it to handle the resulting -M* flags incorrectly with
# gcc>=14. We can remove this once we upgrade to a newer sccache version.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

list(APPEND CUDF_CUDA_FLAGS --expt-extended-lambda --expt-relaxed-constexpr)

add_executable(compute_checksum_jit compute_checksum_jit.cpp)
target_compile_features(compute_checksum_jit PRIVATE cxx_std_20)
target_compile_options(
  compute_checksum_jit PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>"
)
target_link_libraries(
  compute_checksum_jit PRIVATE cudf::cudf # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD): Reenable once nvtx equivalent is available
)
install(TARGETS compute_checksum_jit DESTINATION bin/examples/libcudf/string_transformers)

add_executable(extract_email_jit extract_email_jit.cpp)
target_compile_features(extract_email_jit PRIVATE cxx_std_20)
target_compile_options(extract_email_jit PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>")
target_link_libraries(
  extract_email_jit PRIVATE cudf::cudf # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD): Reenable once nvtx equivalent is available
)
install(TARGETS extract_email_jit DESTINATION bin/examples/libcudf/string_transformers)

add_executable(extract_email_precompiled extract_email_precompiled.cpp)
target_compile_features(extract_email_precompiled PRIVATE cxx_std_20)
target_compile_options(
  extract_email_precompiled PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>"
)
target_link_libraries(
  extract_email_precompiled PRIVATE cudf::cudf # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD): Reenable once nvtx equivalent is available
)
install(TARGETS extract_email_precompiled DESTINATION bin/examples/libcudf/string_transformers)

add_executable(format_phone_jit format_phone_jit.cpp)
target_compile_features(format_phone_jit PRIVATE cxx_std_20)
target_compile_options(format_phone_jit PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>")
target_link_libraries(format_phone_jit PRIVATE cudf::cudf) # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp>) # TODO(HIP/AMD): Reenable once nvtx equivalent is available
install(TARGETS format_phone_jit DESTINATION bin/examples/libcudf/string_transformers)

add_executable(format_phone_precompiled format_phone_precompiled.cpp)
target_compile_features(format_phone_precompiled PRIVATE cxx_std_20)
target_compile_options(
  format_phone_precompiled PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>"
)
target_link_libraries(
  format_phone_precompiled PRIVATE cudf::cudf # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD): Reenable once nvtx equivalent is available
)
install(TARGETS format_phone_precompiled DESTINATION bin/examples/libcudf/string_transformers)

add_executable(localize_phone_jit localize_phone_jit.cpp)
target_compile_features(localize_phone_jit PRIVATE cxx_std_20)
target_compile_options(localize_phone_jit PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>")
target_link_libraries(
  localize_phone_jit PRIVATE cudf::cudf # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD): Reenable once nvtx equivalent is available
)
install(TARGETS localize_phone_jit DESTINATION bin/examples/libcudf/string_transformers)

add_executable(localize_phone_precompiled localize_phone_precompiled.cpp)
target_compile_features(localize_phone_precompiled PRIVATE cxx_std_20)
target_compile_options(
  localize_phone_precompiled PRIVATE "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_CUDA_FLAGS}>"
)
target_link_libraries(
  localize_phone_precompiled PRIVATE cudf::cudf # $<BUILD_LOCAL_INTERFACE:nvtx3::nvtx3-cpp> # TODO(HIP/AMD): Reenable once nvtx equivalent is available
)
install(TARGETS localize_phone_precompiled DESTINATION bin/examples/libcudf/string_transformers)

install(FILES ${CMAKE_CURRENT_LIST_DIR}/info.csv
        DESTINATION bin/examples/libcudf/string_transformers
)
