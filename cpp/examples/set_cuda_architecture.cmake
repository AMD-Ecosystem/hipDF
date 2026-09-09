# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2024-2025, NVIDIA CORPORATION.
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

if(DEFINED ENV{RAPIDS_CMAKE_SCRIPT_REPO})
  set(RAPIDS_CMAKE_SCRIPT_REPO "$ENV{RAPIDS_CMAKE_SCRIPT_REPO}")
else()
  set(RAPIDS_CMAKE_SCRIPT_REPO AMD-Ecosystem/ROCmDS-cmake)
endif()

if(DEFINED ENV{RAPIDS_CMAKE_SCRIPT_BRANCH})
  set(RAPIDS_CMAKE_SCRIPT_BRANCH "$ENV{RAPIDS_CMAKE_SCRIPT_BRANCH}")
else()
  set(RAPIDS_CMAKE_SCRIPT_BRANCH release/rocmds-26.03)
endif()

if(NOT EXISTS ${CMAKE_CURRENT_BINARY_DIR}/libcudf_cpp_examples_RAPIDS.cmake)
  file(
    DOWNLOAD
    "https://raw.githubusercontent.com/${RAPIDS_CMAKE_SCRIPT_REPO}/${RAPIDS_CMAKE_SCRIPT_BRANCH}/RAPIDS.cmake"
    ${CMAKE_CURRENT_BINARY_DIR}/libcudf_cpp_examples_RAPIDS.cmake
  )
endif()
set(rapids-cmake-fetch-via-git ON)
# Fetch the modules from the same place RAPIDS.cmake itself came from, so the two cannot drift
# apart. RAPIDS.cmake requires one of these to be set by the caller.
if(NOT rapids-cmake-repo)
  set(rapids-cmake-repo "${RAPIDS_CMAKE_SCRIPT_REPO}")
endif()
if(NOT rapids-cmake-branch)
  set(rapids-cmake-branch "${RAPIDS_CMAKE_SCRIPT_BRANCH}")
endif()
# TODO(HIP/AMD): include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/rapids_config.cmake)?
include(${CMAKE_CURRENT_BINARY_DIR}/libcudf_cpp_examples_RAPIDS.cmake)

include(rapids-cmake)
include(rapids-cpm)
include(rapids-cuda)
include(rapids-export)
include(rapids-find)

# prescribe versions of internal dependencies
include(cpm/package_override)
# message(STATUS ${CMAKE_CURRENT_LIST_DIR})
rapids_cpm_package_override(${CMAKE_CURRENT_LIST_DIR}/../../versions.json)
