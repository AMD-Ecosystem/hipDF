/*
 * SPDX-FileCopyrightText: Copyright (c) 2020-2024, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */
// MIT License
//
// Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#pragma once

#ifndef NVTX_DISABLE
#include <nvtx3/nvtx3.hpp>

namespace cudf {
/**
 * @brief Tag type for libcudf's NVTX domain.
 */
struct libcudf_domain {
  static constexpr char const* name{"libcudf"};  ///< Name of the libcudf domain
};

/**
 * @brief Alias for an NVTX range in the libcudf domain.
 *
 * Customizes an NVTX range with the given input.
 *
 * Example:
 * ```
 * void some_function(){
 *    cudf::scoped_range rng{"custom_name"}; // Customizes range name
 *    ...
 * }
 * ```
 */
using scoped_range = ::nvtx3::scoped_range_in<libcudf_domain>;

}  // namespace cudf

/**
 * @brief Convenience macro for generating an NVTX range in the `libcudf` domain
 * from the lifetime of a function.
 *
 * Uses the name of the immediately enclosing function returned by `__func__` to
 * name the range.
 *
 * Example:
 * ```
 * void some_function(){
 *    CUDF_FUNC_RANGE();
 *    ...
 * }
 * ```
 */
#define CUDF_FUNC_RANGE() NVTX3_FUNC_RANGE_IN(cudf::libcudf_domain)
#else
// TODO(HIP/AMD, <ROCTX>): NVTX is unavailable on HIP (NVTX_DISABLE), so profiling ranges are
// currently a no-op on AMD - libcudf emits none. Provide a no-op scoped_range stub so source
// that constructs `cudf::scoped_range range{"name"}` still compiles, and make
// CUDF_FUNC_RANGE() a no-op.
//
// rocTX is the intended replacement (available in ROCm 7.14 as
// <rocprofiler-sdk-roctx/roctx.h>, providing roctxRangePushA / roctxRangeStartA / roctxMarkA,
// which cover what scoped_range and CUDF_FUNC_RANGE need). Deferred until rocTX reaches
// capability parity with NVTX - notably domains, registered string handles and payloads, which
// upstream relies on via NVTX3_FUNC_RANGE_IN(cudf::libcudf_domain). Revisit then; see the
// matching TODO on the get_nvtx.cmake include in cpp/CMakeLists.txt.
namespace cudf {
struct scoped_range {
  scoped_range() = default;
  template <typename... Args>
  explicit scoped_range(Args&&...)
  {
  }
};
}  // namespace cudf

#define CUDF_FUNC_RANGE()
#endif
