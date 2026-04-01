/*
 * SPDX-FileCopyrightText: Copyright (c) 2021-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
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
#include "sort_radix.hpp"

#include <cudf/column/column_device_view.cuh>
#include <cudf/detail/indexalator.cuh>
#include <cudf/detail/row_operator/common_utils.cuh>
#include <cudf/dictionary/dictionary_column_view.hpp>
#include <cudf/utilities/error.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/traits.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>

#ifdef __HIP_PLATFORM_AMD__
#include <hipcub/device/device_merge_sort.hpp>
#else
#include <cub/device/device_merge_sort.cuh>
// <<<<<<< OLD CODE from 8414047bb1 (4b19041ca0) - COMMENTED OUT
// // <<<<<<< OLD CODE from 420b69cec5 (7a145e245c) - COMMENTED OUT
// // #endif
// // =======
// =======
#include <cuda/iterator>
// >>>>>>> END NEW CODE (4b19041ca0)
#include <thrust/gather.h>
// >>>>>>> END NEW CODE (7a145e245c)

namespace cudf {
namespace detail {

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

    auto const left_element  = d_column.element<T>(lhs);
    auto const right_element = d_column.element<T>(rhs);
    return relational_compare(left_element, right_element) ==
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
    auto in_keys   = cuda::counting_iterator<cudf::size_type>{0};
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

  template <typename T>
    requires(cudf::is_relationally_comparable<T, T>() and not cudf::is_dictionary<T>())
  void operator()(column_view const& input,
                  mutable_column_view& indices,
                  bool ascending,
                  null_order null_precedence,
                  rmm::cuda_stream_view stream)
  {
    sorted_order<T>(input, indices, ascending, null_precedence, stream);
  }

  template <typename T>
    requires(not cudf::is_relationally_comparable<T, T>())
  void operator()(column_view const&, mutable_column_view&, bool, null_order, rmm::cuda_stream_view)
  {
    CUDF_FAIL("Column type must be relationally comparable");
  }

  template <typename T>
    requires(is_dictionary<T>())
  void operator()(column_view const& input,
                  mutable_column_view& indices,
                  bool ascending,
                  null_order null_precedence,
                  rmm::cuda_stream_view stream)
  {
    auto const keys = dictionary_column_view(input).keys();
    // For the keys we do an arg-sort of arg-sort to get the rank and use that as a map
    // to sort the indices in rank order.
    // First, get sorted-order of just the keys (slow but expect keys.size <<< indices.size)
    auto temp_mr = cudf::get_current_device_resource_ref();
    auto ordered_indices =
      cudf::detail::sorted_order<method>(keys, order::ASCENDING, null_precedence, stream, temp_mr);
    // Now, sort the ordered indices to get their ordered positions (very fast integer sort)
    ordered_indices = cudf::detail::sorted_order<method>(
      ordered_indices->view(), order::ASCENDING, null_precedence, stream, temp_mr);
    // And use the result as a map over the dictionary indices
    auto map = ordered_indices->view().template data<size_type>();
    auto itr = cudf::detail::indexalator_factory::make_input_iterator(
      dictionary_column_view(input).indices());
    auto mapped_indices = rmm::device_uvector<size_type>(input.size(), stream);
    thrust::gather(
      rmm::exec_policy_nosync(stream), itr, itr + input.size(), map, mapped_indices.begin());

    // Finally, sort-order the dictionary indices using mapped values
    auto mapped_view = column_view(data_type{type_to_id<size_type>()},
                                   input.size(),
                                   mapped_indices.data(),
                                   input.null_mask(),
                                   input.null_count());
    // these should be very fast since they are sorting integers
    if (input.has_nulls()) {
      sorted_order<size_type>(mapped_view, indices, ascending, null_precedence, stream);
    } else {
      sorted_order_radix(mapped_view, indices, ascending, stream);
    }
  }
};

}  // namespace detail
}  // namespace cudf
