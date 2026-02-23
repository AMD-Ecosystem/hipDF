# =============================================================================
# Copyright (c) 2021-2023, NVIDIA CORPORATION.
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
# Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
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
# =============================================================================

# This function finds cudf and sets any additional necessary environment variables.
function(find_and_configure_cudf VERSION)
  rapids_cmake_parse_version(MAJOR_MINOR ${VERSION} major_minor)
  rapids_cpm_find(
    cudf ${VERSION}
    BUILD_EXPORT_SET cudf_kafka-exports
    INSTALL_EXPORT_SET cudf_kafka-exports
    CPM_ARGS # : GIT_REPOSITORY https://github.com/rapidsai/cudf.git : GIT_TAG branch-${major_minor}
    GIT_REPOSITORY https://github.com/ROCm/hipdf.git
    GIT_TAG dev
    GIT_SHALLOW TRUE SOURCE_SUBDIR cpp
    OPTIONS "BUILD_TESTS OFF" "BUILD_BENCHMARKS OFF"
  )
  # If after loading cudf we now have the CMAKE_CUDA_COMPILER variable we know that we need to
  # re-enable the cuda language
  if(CMAKE_HIP_COMPILER)
    # : if(CMAKE_CUDA_COMPILER)
    set(cudf_REQUIRES_CUDA
        TRUE
        PARENT_SCOPE
    )
  endif()
endfunction()

set(CUDF_KAFKA_MIN_VERSION
    "${CUDF_KAFKA_VERSION_MAJOR}.${CUDF_KAFKA_VERSION_MINOR}.${CUDF_KAFKA_VERSION_PATCH}"
)
find_and_configure_cudf(${CUDF_KAFKA_MIN_VERSION})

if(cudf_REQUIRES_CUDA)
  rapids_cuda_init_architectures(CUDF_KAFKA)

  # Since we are building cudf as part of ourselves we need to enable the CUDA language in the
  # top-most scope : enable_language(CUDA)
  enable_language(HIP)

  # Since CUDF_KAFKA only enables CUDA optionally we need to manually include the file that
  # rapids_cuda_init_architectures relies on `project` calling
  if(DEFINED CMAKE_PROJECT_CUDF_KAFKA_INCLUDE)
    include("${CMAKE_PROJECT_CUDF_KAFKA_INCLUDE}")
  endif()
endif()
