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

#include "sort.hpp"

#include <cudf/column/column.hpp>
#include <cudf/column/column_factories.hpp>
#include <cudf/detail/copy.hpp>
#include <cudf/detail/gather.hpp>
#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/sequence.hpp>
#include <cudf/detail/sorting.hpp>
#include <cudf/scalar/scalar.hpp>
#include <cudf/sorting.hpp>
#include <cudf/table/table_view.hpp>
#include <cudf/utilities/default_stream.hpp>
#include <cudf/utilities/memory_resource.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>

#ifndef __HIP_PLATFORM_AMD__
#include <cub/device/device_topk.cuh>
#endif
#include <cuda/iterator>
#include <cuda/std/execution>
#include <cuda/stream>

namespace cudf {
namespace detail {
namespace {
bool is_fast_path(column_view const& column)
{
#ifdef __HIP_PLATFORM_AMD__
  // TODO(HIP/AMD, <ROCPRIM-API>): hipcub does not expose a DeviceTopK API, so the CUB
  // partial-selection fast path is unavailable. Always take the sorted_order slow path on AMD;
  // it produces identical top-k indices but is O(n log n) rather than a partial selection.
  //
  // STATUS: rocPRIM *does* provide the underlying primitive as of 4.5.0 (ROCm 7.14) -
  // rocprim::topk / rocprim::topk_pairs in <rocprim/device/device_topk.hpp>. Only the hipcub
  // wrapper is missing, so the request is "expose rocprim::topk as hipcub::DeviceTopK", not
  // "implement top-k".
  (void)column;
  return false;
#else
  return !column.has_nulls() && cudf::is_fixed_width(column.type()) &&
         !cudf::is_floating_point(column.type());  // needs special NaN handling
#endif
}

template <bool fast_path>
struct dispatch_topk_fn {
  column_view input;
  size_type k;
  order topk_order;
  rmm::cuda_stream_view stream;
  rmm::device_async_resource_ref mr;

  template <typename T>
  std::unique_ptr<column> top_k()
  {
#ifdef __HIP_PLATFORM_AMD__
    // TODO(HIP/AMD, <ROCPRIM-API>): DeviceTopK is unavailable in hipcub/rocPRIM. This fast-path
    // body is never reached at runtime on AMD (is_fast_path() returns false), but
    // it is still instantiated by the type_dispatcher, so it must compile. Provide
    // an unreachable stub instead of the CUB DeviceTopK implementation.
    CUDF_UNREACHABLE("top_k fast path (DeviceTopK) is not supported on AMD/HIP");
#else
    auto requirements = cuda::execution::require(cuda::execution::determinism::not_guaranteed,
                                                 cuda::execution::output_ordering::unsorted);
    auto env          = cuda::std::execution::env{cuda::stream_ref{stream.value()}, requirements};
    auto tmp_size     = std::size_t{0};
    auto const size   = input.size();

    auto keys_in  = input.begin<T>();
    auto keys_out = cuda::make_discard_iterator();
    auto indices  = rmm::device_uvector<size_type>(k, stream);
    auto vals_in  = cuda::counting_iterator<size_type>();
    auto vals_out = indices.begin();

    if (topk_order == order::ASCENDING) {
      CUDF_CUDA_TRY(cub::DeviceTopK::MinPairs(
        nullptr, tmp_size, keys_in, keys_out, vals_in, vals_out, size, k, env));
      auto tmp = rmm::device_buffer(tmp_size, stream);
      CUDF_CUDA_TRY(cub::DeviceTopK::MinPairs(
        tmp.data(), tmp_size, keys_in, keys_out, vals_in, vals_out, size, k, env));
    } else {
      CUDF_CUDA_TRY(cub::DeviceTopK::MaxPairs(
        nullptr, tmp_size, keys_in, keys_out, vals_in, vals_out, size, k, env));
      auto tmp = rmm::device_buffer(tmp_size, stream);
      CUDF_CUDA_TRY(cub::DeviceTopK::MaxPairs(
        tmp.data(), tmp_size, keys_in, keys_out, vals_in, vals_out, size, k, env));
    }

    return std::make_unique<column>(std::move(indices), rmm::device_buffer{}, 0);
#endif
  }

  template <typename T>
    requires(cudf::is_fixed_width<T>() and !cudf::is_floating_point<T>() and !cudf::is_chrono<T>())
  std::unique_ptr<column> operator()()
  {
    return top_k<T>();
  }

  template <typename T>
    requires(cudf::is_chrono<T>())
  std::unique_ptr<column> operator()()
  {
    using rep_type = typename T::rep;
    return top_k<rep_type>();
  }

  template <typename T>
    requires(not cudf::is_fixed_width<T>() or cudf::is_floating_point<T>())
  std::unique_ptr<column> operator()()
  {
    CUDF_UNREACHABLE("unexpected type for top_k fast path");
  }
};

}  // namespace

std::unique_ptr<column> top_k(column_view const& col,
                              size_type k,
                              order topk_order,
                              rmm::cuda_stream_view stream,
                              rmm::device_async_resource_ref mr)
{
  CUDF_EXPECTS(k >= 0, "k must be non-negative", std::invalid_argument);
  if (k == 0 || col.is_empty()) { return empty_like(col); }
  if (k >= col.size()) { return std::make_unique<column>(col, stream, mr); }

  auto const indices = [&] {
    auto const temp_mr = cudf::get_current_device_resource_ref();
    if (is_fast_path(col)) {
      return type_dispatcher<dispatch_storage_type>(
        col.type(), dispatch_topk_fn<true>{col, k, topk_order, stream, temp_mr});
    }
    auto const nulls = topk_order == order::ASCENDING ? null_order::AFTER : null_order::BEFORE;
    return sorted_order<sort_method::STABLE>(col, topk_order, nulls, stream, temp_mr);
  }();

  auto const k_indices = cudf::detail::split(indices->view(), {k}, stream).front();

  auto const dont_check  = out_of_bounds_policy::DONT_CHECK;
  auto const not_allowed = negative_index_policy::NOT_ALLOWED;
  auto result =
    cudf::detail::gather(cudf::table_view({col}), k_indices, dont_check, not_allowed, stream, mr);
  return std::move(result->release().front());
}

std::unique_ptr<column> top_k_order(column_view const& col,
                                    size_type k,
                                    order topk_order,
                                    rmm::cuda_stream_view stream,
                                    rmm::device_async_resource_ref mr)
{
  CUDF_EXPECTS(k >= 0, "k must be non-negative", std::invalid_argument);
  if (k == 0 || col.is_empty()) { return make_empty_column(cudf::type_to_id<size_type>()); }
  if (k >= col.size()) {
    return cudf::detail::sequence(
      col.size(),
      numeric_scalar<size_type>(0, true, stream, cudf::get_current_device_resource_ref()),
      stream,
      mr);
  }

  auto const temp_mr = cudf::get_current_device_resource_ref();
  if (is_fast_path(col)) {
    return type_dispatcher<dispatch_storage_type>(
      col.type(), dispatch_topk_fn<true>{col, k, topk_order, stream, temp_mr});
  }
  auto const nulls = topk_order == order::ASCENDING ? null_order::AFTER : null_order::BEFORE;
  auto indices     = sorted_order<sort_method::STABLE>(col, topk_order, nulls, stream, temp_mr);

  return std::make_unique<column>(
    cudf::detail::split(indices->view(), {k}, stream).front(), stream, mr);
}

}  // namespace detail

std::unique_ptr<column> top_k(column_view const& col,
                              size_type k,
                              order topk_order,
                              rmm::cuda_stream_view stream,
                              rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::top_k(col, k, topk_order, stream, mr);
}

std::unique_ptr<column> top_k_order(column_view const& col,
                                    size_type k,
                                    order topk_order,
                                    rmm::cuda_stream_view stream,
                                    rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::top_k_order(col, k, topk_order, stream, mr);
}

}  // namespace cudf
