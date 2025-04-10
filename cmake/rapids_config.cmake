# =============================================================================
# Copyright (c) 2018-2025, NVIDIA CORPORATION.
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

file(READ "${CMAKE_CURRENT_LIST_DIR}/../VERSION" _rapids_version)
if(_rapids_version MATCHES [[^([0-9][0-9]?)\.([0-9][0-9]?)\.([0-9][0-9])(a[0-9])?]])
  set(RAPIDS_VERSION_MAJOR "${CMAKE_MATCH_1}")
  set(RAPIDS_VERSION_MINOR "${CMAKE_MATCH_2}")
  set(RAPIDS_VERSION_PATCH "${CMAKE_MATCH_3}")
  set(RAPIDS_VERSION_MAJOR_MINOR "${RAPIDS_VERSION_MAJOR}.${RAPIDS_VERSION_MINOR}")
  set(RAPIDS_VERSION "${RAPIDS_VERSION_MAJOR}.${RAPIDS_VERSION_MINOR}.${RAPIDS_VERSION_PATCH}")
else()
  string(REPLACE "\n" "\n  " _rapids_version_formatted "  ${_rapids_version}")
  message(
    FATAL_ERROR
      "Could not determine RAPIDS version. Contents of VERSION file:\n${_rapids_version_formatted}"
  )
endif()

set(
  RAPIDS_CMAKE_MODULE_PATH
  $ENV{RAPIDS_CMAKE_MODULE_PATH}
  CACHE FILEPATH
  "Announce that ROCmDS-CMake is available via the provided module path."  
)
if (NOT "${RAPIDS_CMAKE_MODULE_PATH}" STREQUAL "")
  list(APPEND CMAKE_MODULE_PATH "${RAPIDS_CMAKE_MODULE_PATH}")
  # NOTE(HIP/AMD): needed to set rapids-cmake-dir variable
  include(rapids-cmake)
  return()
endif()

if(NOT EXISTS "${CMAKE_CURRENT_BINARY_DIR}/CUDF_RAPIDS-${RAPIDS_VERSION_MAJOR_MINOR}.cmake")
  if(DEFINED ENV{RAPIDS_CMAKE_SCRIPT_REPO})
    set(RAPIDS_CMAKE_SCRIPT_REPO "$ENV{RAPIDS_CMAKE_SCRIPT_REPO}")
  else()
    set(RAPIDS_CMAKE_SCRIPT_REPO ROCm-DS/ROCmDS-CMake)
  endif()
  if(DEFINED ENV{RAPIDS_CMAKE_SCRIPT_BRANCH})
    set(RAPIDS_CMAKE_SCRIPT_BRANCH "$ENV{RAPIDS_CMAKE_SCRIPT_BRANCH}")
  else()
    set(RAPIDS_CMAKE_SCRIPT_BRANCH release/rocmds-25.10)
  endif()

  set(URL "https://raw.githubusercontent.com/${RAPIDS_CMAKE_SCRIPT_REPO}/${RAPIDS_CMAKE_SCRIPT_BRANCH}/RAPIDS.cmake")
   
  file(
      DOWNLOAD ${URL}
      "${CMAKE_CURRENT_BINARY_DIR}/CUDF_RAPIDS-${RAPIDS_VERSION_MAJOR_MINOR}.cmake"
      STATUS DOWNLOAD_STATUS
  )

  list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
  list(GET DOWNLOAD_STATUS 1 ERROR_MESSAGE)

  if(${STATUS_CODE} EQUAL 0)
    message(STATUS "Downloaded CUDF_RAPIDS-${RAPIDS_VERSION_MAJOR_MINOR}.cmake' successfully!")
  else()
    message(FATAL_ERROR "Failed to download 'CUDF_RAPIDS-${RAPIDS_VERSION_MAJOR_MINOR}.cmake'. Reason: ${ERROR_MESSAGE}")
  endif()
endif()

if(DEFINED ENV{RAPIDS_CMAKE_BRANCH})
  set(rapids-cmake-branch $ENV{RAPIDS_CMAKE_BRANCH})
endif()

# TODO(HIP/AMD): Ship RAPIDS.cmake with hipDF?
set(rapids-cmake-version "${RAPIDS_VERSION_MAJOR_MINOR}")
include("${CMAKE_CURRENT_BINARY_DIR}/CUDF_RAPIDS-${RAPIDS_VERSION_MAJOR_MINOR}.cmake")
