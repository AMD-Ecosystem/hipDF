/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
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

#include <cudf/ast/detail/operator_functor.cuh>
#include <cudf/column/column_device_view_base.cuh>
#include <cudf/detail/utilities/grid_1d.cuh>
#include <cudf/types.hpp>

#include <cuda/std/cstddef>
#include <cuda/std/limits>

#include <jit/join_column_accessor.cuh>
#include <cudf/detail/jit/span.cuh>
#include <jit/type_list.cuh>

#pragma nv_hdrstop  // The above headers are used by the kernel below and need to be included before
                    // it. Each UDF will have a different operation-udf.hpp generated for it, so we
                    // need to put this pragma before including it to avoid PCH mismatch.

// clang-format off
// This header is an inlined header that defines the GENERIC_JOIN_FILTER_OP function. It is placed here
// so the symbols in the headers above can be used by it.
#include <cudf/detail/operation-udf.hpp>
// clang-format on

namespace cudf::join::jit {

// TODO: Create a JIT-compatible header for JoinNoMatch to avoid this duplication.
// This must match the definition in cudf/join/join.hpp
constexpr cudf::size_type JoinNoMatch = cuda::std::numeric_limits<cudf::size_type>::min();

template <bool has_user_data, null_aware is_null_aware, typename... InputAccessors>
CUDF_KERNEL void filter_join_kernel(cudf::jit::device_span<cudf::size_type const> left_indices,
                                    cudf::jit::device_span<cudf::size_type const> right_indices,
                                    cudf::column_device_view_core const* left_tables,
                                    cudf::column_device_view_core const* right_tables,
                                    bool* predicate_results,
                                    void* user_data)
{
  auto const start  = cudf::detail::grid_1d::global_thread_id();
  auto const stride = cudf::detail::grid_1d::grid_stride();
  auto const size   = left_indices.size();

  for (auto i = start; i < size; i += stride) {
    auto const left_idx  = left_indices[i];
    auto const right_idx = right_indices[i];

    // Skip if either index is JoinNoMatch
    if (left_idx == JoinNoMatch || right_idx == JoinNoMatch) {
      predicate_results[i] = false;
      continue;
    }

    // Each accessor receives both tables and both indices, and internally selects
    // the appropriate table based on whether it's a left or right accessor.
    if constexpr (is_null_aware == null_aware::YES) {
      // Null-aware path: pass optional<T> inputs, get optional<bool> result
      cuda::std::optional<bool> result{false};
      if constexpr (has_user_data) {
        GENERIC_JOIN_FILTER_OP(
          user_data,
          i,
          &result,
          InputAccessors::nullable_element(left_tables, right_tables, left_idx, right_idx, i)...);
      } else {
        GENERIC_JOIN_FILTER_OP(
          &result,
          InputAccessors::nullable_element(left_tables, right_tables, left_idx, right_idx, i)...);
      }
      predicate_results[i] = result.has_value() && result.value();
    } else {
      // Non-null-aware path: if any input is null, predicate is false
      if ((InputAccessors::is_null(left_tables, right_tables, left_idx, right_idx, i) || ...)) {
        predicate_results[i] = false;
        continue;
      }
      bool result = false;
      if constexpr (has_user_data) {
        GENERIC_JOIN_FILTER_OP(
          user_data,
          i,
          &result,
          InputAccessors::element(left_tables, right_tables, left_idx, right_idx, i)...);
      } else {
        GENERIC_JOIN_FILTER_OP(
          &result, InputAccessors::element(left_tables, right_tables, left_idx, right_idx, i)...);
      }
      predicate_results[i] = result;
    }
  }
}

}  // namespace cudf::join::jit
