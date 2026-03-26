/*
 * SPDX-FileCopyrightText: Copyright (c) 2025-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

// MIT License
//
// Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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
#endif

namespace cudf::benchmark {
/**
 * @brief Tag type for the libcudf benchmark NVTX domain
 */
struct benchmark_domain {
  static constexpr char const* name{"benchmarks"};  ///< Name of the domain
};

/**
 * @brief Alias for an NVTX range in the libcudf benchmark domain.
 *
 * Customizes an NVTX range with the given input.
 *
 * Example:
 * ```
 * void some_function(){
 *    cudf::benchmark::scoped_range rng{"custom_name"}; // Customizes range name
 *    ...
 * }
 * ```
 */
using scoped_range = ::nvtx3::scoped_range_in<benchmark_domain>;

}  // namespace cudf::benchmark

/**
 * @brief Convenience macro for generating an NVTX range in the `benchmarks` domain
 * from the lifetime of a function.
 *
 * Uses the name of the immediately enclosing function returned by `__func__` to
 * name the range.
 *
 * Example:
 * ```
 * void some_function(){
 *    CUDF_BENCHMARK_RANGE();
 *    ...
 * }
 * ```
 */
#ifndef NVTX_DISABLE
#define CUDF_BENCHMARK_RANGE() NVTX3_FUNC_RANGE_IN(cudf::benchmark::benchmark_domain)
#else
#define CUDF_BENCHMARK_RANGE() (void)0
#endif
