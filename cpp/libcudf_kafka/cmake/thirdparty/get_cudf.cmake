# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2021-2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on
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
# <<<<<<< OLD CODE from d26f0baa9a (7cd540eb83) - COMMENTED OUT
#     CPM_ARGS # : GIT_REPOSITORY https://github.com/rapidsai/cudf.git : GIT_TAG branch-${major_minor}
#     GIT_REPOSITORY https://github.com/ROCm/hipdf.git
#     GIT_TAG dev
# =======
    CPM_ARGS
    GIT_REPOSITORY https://github.com/rapidsai/cudf.git
# <<<<<<< OLD CODE from 27bf05e749 (2903d6b1dd) - COMMENTED OUT
# # <<<<<<< OLD CODE from 8f98ec802e (4694b55cdf) - COMMENTED OUT
# # # <<<<<<< OLD CODE from d605b0d7db (2c127c3e2d) - COMMENTED OUT
# # # # <<<<<<< OLD CODE from 023d224c0e (ae5cd415a4) - COMMENTED OUT
# # # # # <<<<<<< OLD CODE from 58083a4ae1 (24679d11e8) - COMMENTED OUT
# # # # #     GIT_TAG main
# # # # # # >>>>>>> END NEW CODE (7cd540eb83)
# # # # # =======
# # # #     GIT_TAG release/25.12
# # # # # >>>>>>> END NEW CODE (24679d11e8)
# # # # =======
# # #     GIT_TAG main
# # # # >>>>>>> END NEW CODE (ae5cd415a4)
# # # =======
# #     GIT_TAG release/26.02
# # # >>>>>>> END NEW CODE (2c127c3e2d)
# # =======
#     GIT_TAG main
# # >>>>>>> END NEW CODE (4694b55cdf)
# =======
    GIT_TAG "${RAPIDS_BRANCH}"
# >>>>>>> END NEW CODE (2903d6b1dd)
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
