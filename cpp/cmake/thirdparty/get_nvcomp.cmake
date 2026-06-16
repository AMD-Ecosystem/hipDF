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

# This function finds hipcomp and sets any additional necessary environment variables.
function(find_and_configure_hipcomp)

  include(${rapids-cmake-dir}/cpm/hipcomp.cmake)
  set(export_args)
  if(CUDF_EXPORT_NVCOMP)
    set(export_args BUILD_EXPORT_SET cudf-exports INSTALL_EXPORT_SET cudf-exports)
  endif()
  # FIXME(HIP/AMD): Ensure CUDF_USE_PROPRIETARY_NVCOMP has a value to prevent argument shift
  if(NOT DEFINED CUDF_USE_PROPRIETARY_NVCOMP)
    set(CUDF_USE_PROPRIETARY_NVCOMP OFF)
  endif()
  rapids_cpm_hipcomp(${export_args} USE_PROPRIETARY_BINARY ${CUDF_USE_PROPRIETARY_NVCOMP} BUILD_STATIC OFF)

  # Per-thread default stream
  if(TARGET hipcomp AND CUDF_USE_PER_THREAD_DEFAULT_STREAM)
    target_compile_definitions(
      hipcomp PRIVATE CUDA_API_PER_THREAD_DEFAULT_STREAM HIP_API_PER_THREAD_DEFAULT_STREAM
                      __HIP_API_PER_THREAD_DEFAULT_STREAM__
    )
  endif()

  # NOTE(HIP/AMD): upstream cuDF links the nvcomp library into libcudf via
  # ${CUDF_nvcomp_TARGET}, but that variable is never set anywhere in the tree (upstream
  # relies on the NVIDIA nvcomp rapids module to export it). With the HIP port the rapids
  # hipcomp module only guarantees the `hipcomp::hipcomp` target (the nvcomp::nvcomp alias
  # is gated on HIP_AS_CUDA). Without this, libcudf.so is left with undefined hipcomp*
  # symbols which only surface when the gtest executables link with
  # --no-allow-shlib-undefined. Set CUDF_nvcomp_TARGET to the available hipcomp target so
  # the (static) hipcomp library is actually linked into libcudf.
  if(TARGET nvcomp::nvcomp)
    set(CUDF_nvcomp_TARGET nvcomp::nvcomp PARENT_SCOPE)
  elseif(TARGET hipcomp::hipcomp)
    set(CUDF_nvcomp_TARGET hipcomp::hipcomp PARENT_SCOPE)
  elseif(TARGET hipcomp)
    set(CUDF_nvcomp_TARGET hipcomp PARENT_SCOPE)
  endif()

endfunction()

find_and_configure_hipcomp()
