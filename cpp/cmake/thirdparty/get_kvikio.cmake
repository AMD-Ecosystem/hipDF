# =============================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2022-2026, NVIDIA CORPORATION.
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

# This function finds KvikIO
function(find_and_configure_kvikio VERSION)

  rapids_cpm_find(
    kvikio ${VERSION}
    GLOBAL_TARGETS kvikio::kvikio
    CPM_ARGS
    GIT_REPOSITORY https://github.com/rapidsai/kvikio.git
    GIT_TAG "${RAPIDS_BRANCH}"
    GIT_SHALLOW TRUE SOURCE_SUBDIR cpp
    OPTIONS "KvikIO_BUILD_EXAMPLES OFF" "KvikIO_REMOTE_SUPPORT ${CUDF_KVIKIO_REMOTE_IO}"
  )

# <<<<<<< OLD CODE from ead9ec6eb8 (745233f175) - COMMENTED OUT
#   if(KvikIO_BINARY_DIR)
#     include("${rapids-cmake-dir}/export/find_package_root.cmake")
#     rapids_export_find_package_root(
#       BUILD KvikIO "${KvikIO_BINARY_DIR}"
#       EXPORT_SET cudf-exports
#       CONDITION KvikIO_BINARY_DIR
#     )
#   endif()
#
# =======
# >>>>>>> END NEW CODE (745233f175)
endfunction()

set(KVIKIO_MIN_VERSION_cudf "${CUDF_VERSION_MAJOR}.${CUDF_VERSION_MINOR}")
find_and_configure_kvikio(${KVIKIO_MIN_VERSION_cudf})
