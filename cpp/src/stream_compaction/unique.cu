/*
 * Copyright (c) 2019-2025, NVIDIA CORPORATION.
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

#include "stream_compaction_common.cuh"

#include <cudf/column/column_device_view.cuh>
#include <cudf/column/column_factories.hpp>
#include <cudf/column/column_view.hpp>
#include <cudf/detail/copy.hpp>
#include <cudf/detail/gather.hpp>
#include <cudf/detail/iterator.cuh>
#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/row_operator/row_operators.cuh>
#include <cudf/detail/sorting.hpp>
#include <cudf/detail/stream_compaction.hpp>
#include <cudf/stream_compaction.hpp>
#include <cudf/table/table.hpp>
#include <cudf/table/table_view.hpp>
#include <cudf/types.hpp>
#include <cudf/utilities/default_stream.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/exec_policy.hpp>

#include <cuda/std/functional>
#include <cuda/std/iterator>
#include <thrust/copy.h>
#include <thrust/execution_policy.h>
#include <thrust/iterator/counting_iterator.h>

#include <utility>
#include <vector>

namespace cudf {
namespace detail {
std::unique_ptr<table> unique(table_view const& input,
                              std::vector<size_type> const& keys,
                              duplicate_keep_option keep,
                              null_equality nulls_equal,
                              rmm::cuda_stream_view stream,
                              rmm::device_async_resource_ref mr)
{
  // If keep is KEEP_ANY, just alias it to KEEP_FIRST.
  if (keep == duplicate_keep_option::KEEP_ANY) { keep = duplicate_keep_option::KEEP_FIRST; }

  auto const num_rows = input.num_rows();
  if (num_rows == 0 or input.num_columns() == 0 or keys.empty()) { return empty_like(input); }

  auto unique_indices = make_numeric_column(
    data_type{type_to_id<size_type>()}, num_rows, mask_state::UNALLOCATED, stream, mr);
  auto mutable_view = mutable_column_device_view::create(*unique_indices, stream);
  auto keys_view    = input.select(keys);

  auto comp = cudf::detail::row::equality::self_comparator(keys_view, stream);

  size_type const unique_size = [&] {
    if (cudf::detail::has_nested_columns(keys_view)) {
      // Using a temporary buffer for intermediate transform results from the functor containing
      // the comparator speeds up compile-time significantly without much degradation in
      // runtime performance over using the comparator directly in thrust::unique_copy.
      auto row_equal =
        comp.equal_to<true>(nullate::DYNAMIC{has_nested_nulls(keys_view)}, nulls_equal);
      auto d_results = rmm::device_uvector<bool>(num_rows, stream);
      auto itr       = thrust::make_counting_iterator<size_type>(0);
      thrust::transform(
        rmm::exec_policy(stream),
        itr,
        itr + num_rows,
        d_results.begin(),
        unique_copy_fn<decltype(itr), decltype(row_equal)>{itr, keep, row_equal, num_rows - 1});
      // NOTE(HIP/AMD): libhipcxx 2.7.0 has a const-correctness issue where cuda::std::identity
      // drops const qualifier when used with transform_iterator<bool*> in rocPRIM's select.
      // This causes compilation errors. We conditionally use a workaround for affected versions.
#if defined(CCCL_VERSION) && CCCL_VERSION <= 2007000
      auto result_end = thrust::copy_if(rmm::exec_policy(stream),
                                        itr,
                                        itr + num_rows,
                                        d_results.begin(),
                                        mutable_view->begin<size_type>(),
                                        thrust::identity{});
#else
      auto result_end = thrust::copy_if(rmm::exec_policy(stream),
                                        itr,
                                        itr + num_rows,
                                        d_results.begin(),
                                        mutable_view->begin<size_type>(),
                                        cuda::std::identity{});
#endif
      return static_cast<size_type>(
        cuda::std::distance(mutable_view->begin<size_type>(), result_end));
    } else {
      // Using thrust::unique_copy with the comparator directly will compile more slowly but
      // improves runtime by up to 2x over the transform/copy_if approach above.
      auto row_equal =
        comp.equal_to<false>(nullate::DYNAMIC{has_nested_nulls(keys_view)}, nulls_equal);
      auto result_end = unique_copy(thrust::counting_iterator<size_type>(0),
                                    thrust::counting_iterator<size_type>(num_rows),
                                    mutable_view->begin<size_type>(),
                                    row_equal,
                                    keep,
                                    stream);
      return static_cast<size_type>(
        cuda::std::distance(mutable_view->begin<size_type>(), result_end));
    }
  }();
  auto indices_view = cudf::detail::slice(column_view(*unique_indices), 0, unique_size, stream);

  // gather unique rows and return
  return detail::gather(input,
                        indices_view,
                        out_of_bounds_policy::DONT_CHECK,
                        detail::negative_index_policy::NOT_ALLOWED,
                        stream,
                        mr);
}
}  // namespace detail

std::unique_ptr<table> unique(table_view const& input,
                              std::vector<size_type> const& keys,
                              duplicate_keep_option const keep,
                              null_equality nulls_equal,
                              rmm::cuda_stream_view stream,
                              rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::unique(input, keys, keep, nulls_equal, stream, mr);
}

}  // namespace cudf
