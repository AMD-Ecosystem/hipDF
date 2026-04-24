# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2024-2026, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
# cmake-format: on
# =============================================================================

# MIT License
#
# Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

# Use CPM to find or clone flatbuffers
function(find_and_configure_flatbuffers VERSION)
  set(_exclude_from_all EXCLUDE_FROM_ALL ${BUILD_SHARED_LIBS})

  rapids_cpm_find(
    flatbuffers ${VERSION}
    GLOBAL_TARGETS flatbuffers
    CPM_ARGS
    GIT_REPOSITORY https://github.com/google/flatbuffers.git
    GIT_TAG v${VERSION}
    GIT_SHALLOW TRUE ${_exclude_from_all}
# <<<<<<< OLD CODE from 54c26f49ee (6b9741aaf8) - COMMENTED OUT
#     OPTIONS
#       "FLATBUFFERS_BUILD_TESTS OFF" # NOTE(HIP/AMD): This ensures that ctest will not try to run the
#                                     # flatbuffer tests which are not built per default.
# =======
    OPTIONS "FLATBUFFERS_BUILD_TESTS OFF"
# >>>>>>> END NEW CODE (6b9741aaf8)
  )

  rapids_export_find_package_root(
    BUILD flatbuffers "${flatbuffers_BINARY_DIR}" EXPORT_SET cudf-exports
  )

endfunction()

find_and_configure_flatbuffers(24.3.25)
