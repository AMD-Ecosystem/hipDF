/*
 * SPDX-FileCopyrightText: Copyright (c) 2021-2025, NVIDIA CORPORATION.
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

#include <cudf/types.hpp>

#include <cuda/std/tuple>

namespace cudf {
namespace detail {

using idx_valid_pair_t = cuda::std::tuple<cudf::size_type, bool>;

/**
 * @brief Functor used by `replace_nulls(replace_policy)` to determine the index to gather from in
 * the result column.
 *
 * Binary functor passed to `inclusive_scan` or `inclusive_scan_by_key`. Arguments are a tuple of
 * index and validity of a row. Returns a tuple of current index and a discarded boolean if current
 * row is valid, otherwise a tuple of the nearest non-null row index and a discarded boolean.
 */
struct replace_policy_functor {
  // FIXME(HIP/AMD, <ROCPRIM-CONSTOP>): `operator()` must be const-qualified - rocThrust's scan
  // invokes the binary op through a const object, unlike CCCL Thrust. (`__host__` is a pre-existing
  // hipDF delta; upstream declares this `__device__`-only.) The extra line wrap is clang-format's
  // consequence of the longer signature, not a gratuitous reformat.
  __host__ __device__ idx_valid_pair_t operator()(idx_valid_pair_t const& lhs,
                                                  idx_valid_pair_t const& rhs) const
  {
    return cuda::std::get<1>(rhs) ? rhs : lhs;
  }
};

}  // namespace detail
}  // namespace cudf
