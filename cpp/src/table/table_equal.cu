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

#include <cudf/detail/algorithms/reduce.cuh>
#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/row_operator/common_utils.cuh>
#include <cudf/detail/row_operator/equality.cuh>
#include <cudf/table/equality.hpp>
#include <cudf/table/table_view.hpp>
#include <cudf/utilities/error.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/type_checks.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>

#ifdef __HIP_PLATFORM_AMD__
#include <hipcub/device/device_transform.hpp>
#else
#include <cub/device/device_transform.cuh>
#endif
#include <cuda/iterator>
#include <cuda/std/functional>

namespace cudf {
namespace detail {

#ifdef __HIP_PLATFORM_AMD__
using DeviceTransform = hipcub::DeviceTransform;
#else
using DeviceTransform = cub::DeviceTransform;
#endif

namespace {

template <bool has_nested_columns>
[[nodiscard]] bool tables_equal(table_view const& left,
                                table_view const& right,
                                null_equality nulls_equal,
                                rmm::cuda_stream_view stream)
{
  auto const comparator = detail::row::equality::two_table_comparator{left, right, stream};
  auto const rows_equal = comparator.equal_to<has_nested_columns>(
    nullate::DYNAMIC{has_nested_nulls(left) or has_nested_nulls(right)}, nulls_equal);
  rmm::device_uvector<bool> eq_rows{
    static_cast<std::size_t>(left.num_rows()), stream, cudf::get_current_device_resource_ref()};
  CUDF_CUDA_TRY(DeviceTransform::Transform(
    cuda::counting_iterator<size_type>{0},
    eq_rows.begin(),
    eq_rows.size(),
    [rows_equal] __device__(size_type i) -> bool {
      return rows_equal(detail::row::lhs_index_type{i}, detail::row::rhs_index_type{i});
    },
    stream.value()));
  return cudf::detail::reduce(
    eq_rows.begin(), eq_rows.end(), true, cuda::std::logical_and<bool>{}, stream);
}

}  // namespace

[[nodiscard]] bool tables_equal(table_view const& left,
                                table_view const& right,
                                null_equality nulls_equal,
                                rmm::cuda_stream_view stream)
{
  if (left.num_rows() != right.num_rows() || left.num_columns() != right.num_columns() ||
      !have_same_types(left, right)) {
    return false;
  } else if (left.num_rows() == 0) {
    return true;
  }

  return cudf::has_nested_columns(left) || cudf::has_nested_columns(right)
           ? tables_equal<true>(left, right, nulls_equal, stream)
           : tables_equal<false>(left, right, nulls_equal, stream);
}
}  // namespace detail

bool tables_equal(table_view const& left,
                  table_view const& right,
                  null_equality nulls_equal,
                  rmm::cuda_stream_view stream)
{
  CUDF_FUNC_RANGE();
  return detail::tables_equal(left, right, nulls_equal, stream);
}

}  // namespace cudf
