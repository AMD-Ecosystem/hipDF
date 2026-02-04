/*
 * Copyright (c) 2021-2025, NVIDIA CORPORATION.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// MIT License
//
// Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
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

#include "sort.hpp"

#include <cudf/column/column_device_view.cuh>
#include <cudf/detail/row_operator/row_operators.cuh>
#include <cudf/utilities/error.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/traits.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/exec_policy.hpp>

#ifdef __HIP_PLATFORM_AMD__
#include <hipcub/device/device_merge_sort.hpp>
#else
#include <cub/device/device_merge_sort.cuh>
#endif

namespace cudf {
namespace detail {

/**
 * @brief Sort indices of a single column.
 *
 * This API offers fast sorting for primitive types. It cannot handle nested types and will not
 * consider `NaN` as equivalent to other `NaN`.
 *
 * @tparam method Whether to use stable sort
 * @param input Column to sort. The column data is not modified.
 * @param column_order Ascending or descending sort order
 * @param null_precedence How null rows are to be ordered
 * @param stream CUDA stream used for device memory operations and kernel launches
 * @param mr Device memory resource used to allocate the returned column's device memory
 * @return Sorted indices for the input column.
 */
template <sort_method method>
std::unique_ptr<column> sorted_order(column_view const& input,
                                     order column_order,
                                     null_order null_precedence,
                                     rmm::cuda_stream_view stream,
                                     rmm::device_async_resource_ref mr);

/**
 * @brief Comparator functor needed for single column sort.
 *
 * @tparam Column element type.
 */
template <typename T>
struct simple_comparator {
  // TODO(HIP/AMD): Potential compiler optimization issue on RDNA architectures (gfx11*/gfx12*) causes
  // incorrect sorting behavior. The noinline attribute works around this
  // This workaround is only applied when CUDF_USE_WARPSIZE_32 is enabled.
#if defined(CUDF_USE_WARPSIZE_32) && defined(CUDF_ENABLE_FAILING_OPTIMIZATION_WORKAROUNDS)
  __attribute__((noinline)) __device__ bool operator()(size_type lhs, size_type rhs)
#else
  __device__ bool operator()(size_type lhs, size_type rhs)
#endif
  {
    if (has_nulls) {
      bool lhs_null{d_column.is_null(lhs)};
      bool rhs_null{d_column.is_null(rhs)};
      if (lhs_null || rhs_null) {
        if (!ascending) { cuda::std::swap(lhs_null, rhs_null); }
        return (null_precedence == cudf::null_order::BEFORE ? !rhs_null : !lhs_null);
      }
    }
    return relational_compare(d_column.element<T>(lhs), d_column.element<T>(rhs)) ==
           (ascending ? weak_ordering::LESS : weak_ordering::GREATER);
  }
  column_device_view const d_column;
  bool has_nulls;
  bool ascending;
  null_order null_precedence{};
};

template <sort_method method>
struct column_sorted_order_fn {
  /**
   * @brief Sorts a single column with a relationally comparable type.
   *
   * This is used when a comparator is required.
   *
   * @param input Column to sort
   * @param indices Output sorted indices
   * @param ascending True if sort order is ascending
   * @param null_precedence How null rows are to be ordered
   * @param stream CUDA stream used for device memory operations and kernel launches
   */
  template <typename T>
  void sorted_order(column_view const& input,
                    mutable_column_view& indices,
                    bool ascending,
                    null_order null_precedence,
                    rmm::cuda_stream_view stream)
  {
    auto keys      = column_device_view::create(input, stream);
    auto comp      = simple_comparator<T>{*keys, input.has_nulls(), ascending, null_precedence};
    auto in_keys   = thrust::make_counting_iterator<cudf::size_type>(0);
    auto out_keys  = indices.begin<size_type>();
    auto tmp_bytes = std::size_t{0};
    if constexpr (method == sort_method::STABLE) {
      CUDF_CUDA_TRY(hipcub::DeviceMergeSort::StableSortKeysCopy(
        nullptr, tmp_bytes, in_keys, out_keys, indices.size(), comp, stream.value()));
      auto tmp_stg = rmm::device_buffer(tmp_bytes, stream);
      CUDF_CUDA_TRY(hipcub::DeviceMergeSort::StableSortKeysCopy(
        tmp_stg.data(), tmp_bytes, in_keys, out_keys, indices.size(), comp, stream.value()));
    } else {
      CUDF_CUDA_TRY(hipcub::DeviceMergeSort::SortKeysCopy(
        nullptr, tmp_bytes, in_keys, out_keys, indices.size(), comp, stream.value()));
      auto tmp_stg = rmm::device_buffer(tmp_bytes, stream);
      CUDF_CUDA_TRY(hipcub::DeviceMergeSort::SortKeysCopy(
        tmp_stg.data(), tmp_bytes, in_keys, out_keys, indices.size(), comp, stream.value()));
    }
  }

  template <typename T, CUDF_ENABLE_IF(cudf::is_relationally_comparable<T, T>())>
  void operator()(column_view const& input,
                  mutable_column_view& indices,
                  bool ascending,
                  null_order null_precedence,
                  rmm::cuda_stream_view stream)
  {
    sorted_order<T>(input, indices, ascending, null_precedence, stream);
  }

  template <typename T, CUDF_ENABLE_IF(not cudf::is_relationally_comparable<T, T>())>
  void operator()(column_view const&, mutable_column_view&, bool, null_order, rmm::cuda_stream_view)
  {
    CUDF_FAIL("Column type must be relationally comparable");
  }
};

}  // namespace detail
}  // namespace cudf
