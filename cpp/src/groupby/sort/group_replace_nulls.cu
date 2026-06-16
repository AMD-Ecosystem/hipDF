/*
 * SPDX-FileCopyrightText: Copyright (c) 2021-2026, NVIDIA CORPORATION.
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

#include <cudf/column/column_device_view.cuh>
#include <cudf/detail/gather.hpp>
#include <cudf/detail/groupby/group_replace_nulls.hpp>
#include <cudf/detail/iterator.cuh>
#include <cudf/detail/replace/nulls.cuh>
#include <cudf/replace.hpp>
#include <cudf/utilities/memory_resource.hpp>

#include <rmm/device_uvector.hpp>

#include <cuda/iterator>
#include <cuda/std/functional>
#include <cuda/std/tuple>
#include <thrust/scan.h>

#include <utility>

namespace cudf {
namespace groupby {
namespace detail {

std::unique_ptr<column> group_replace_nulls(cudf::column_view const& grouped_value,
                                            device_span<size_type const> group_labels,
                                            cudf::replace_policy replace_policy,
                                            rmm::cuda_stream_view stream,
                                            rmm::device_async_resource_ref mr)
{
  cudf::size_type size = grouped_value.size();

  auto device_in = cudf::column_device_view::create(grouped_value, stream);
  auto index     = cuda::counting_iterator<cudf::size_type>{0};
  // NOTE(HIP/AMD): CCCL transform_iterator for validity so the cuda::zip_iterator is advanceable
  // (rocThrust make_validity_iterator does not satisfy cuda::std::random_access). See replace/nulls.cu.
  auto valid_it =
    cuda::make_transform_iterator(index, cudf::detail::validity_accessor<true>{*device_in});
  auto in_begin = cuda::make_zip_iterator(index, valid_it);

  rmm::device_uvector<cudf::size_type> gather_map(size, stream);
  auto gm_begin = cuda::make_zip_iterator(
    cuda::std::make_tuple(gather_map.begin(), cuda::make_discard_iterator()));

  auto func = cudf::detail::replace_policy_functor();
  cuda::std::equal_to<cudf::size_type> eq;
  if (replace_policy == cudf::replace_policy::PRECEDING) {
    thrust::inclusive_scan_by_key(
      rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
      group_labels.begin(),
      group_labels.begin() + size,
      in_begin,
      gm_begin,
      eq,
      func);
  } else {
    auto gl_rbegin = cuda::std::make_reverse_iterator(group_labels.begin() + size);
    auto in_rbegin = cuda::std::make_reverse_iterator(in_begin + size);
    auto gm_rbegin = cuda::std::make_reverse_iterator(gm_begin + size);
    thrust::inclusive_scan_by_key(
      rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
      gl_rbegin,
      gl_rbegin + size,
      in_rbegin,
      gm_rbegin,
      eq,
      func);
  }

  auto output = cudf::detail::gather(cudf::table_view({grouped_value}),
                                     gather_map,
                                     cudf::out_of_bounds_policy::DONT_CHECK,
                                     cudf::negative_index_policy::NOT_ALLOWED,
                                     stream,
                                     mr);

  return std::move(output->release()[0]);
}

}  // namespace detail
}  // namespace groupby
}  // namespace cudf
