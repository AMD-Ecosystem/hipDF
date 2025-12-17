/*
 * Copyright (c) 2025, NVIDIA CORPORATION.
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
// Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/reshape.hpp>
#include <cudf/detail/utilities/batched_memcpy.hpp>
#include <cudf/detail/utilities/vector_factories.hpp>
#include <cudf/reshape.hpp>
#include <cudf/types.hpp>
#include <cudf/utilities/default_stream.hpp>
#include <cudf/utilities/error.hpp>
#include <cudf/utilities/span.hpp>
#include <cudf/utilities/type_checks.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>

#ifdef __HIP_PLATFORM_AMD__
#include <hipcub/device/device_memcpy.hpp>
#else
#include <cub/device/device_memcpy.cuh>
#endif
#include <cuda/functional>
#include <cudf/cuda_runtime.h>
#include <thrust/device_vector.h>
#include <thrust/iterator/constant_iterator.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/iterator/transform_iterator.h>

namespace cudf {
namespace detail {
namespace {

template <typename T>
void table_to_array_impl(table_view const& input,
                         device_span<cuda::std::byte> output,
                         rmm::cuda_stream_view stream)
{
  auto const num_columns = input.num_columns();
  auto const num_rows    = input.num_rows();
  auto const item_size   = sizeof(T);
  auto const total_bytes = static_cast<size_t>(num_columns) * num_rows * item_size;

  CUDF_EXPECTS(output.size() >= total_bytes, "Output span is too small", std::invalid_argument);
  CUDF_EXPECTS(cudf::all_have_same_types(input.begin(), input.end()),
               "All columns must have the same data type",
               cudf::data_type_error);
  CUDF_EXPECTS(!cudf::has_nulls(input), "All columns must contain no nulls", std::invalid_argument);

  auto* base_ptr = output.data();

  // NOTE(HIP/AMD): rocPRIM's batch_memcpy has a const-correctness issue where it attempts to
  // reinterpret_cast const T* to unsigned char* (casts away qualifiers), which violates C++
  // const-correctness rules. The issue occurs in rocprim::detail::batch_memcpy::read_item<>()
  // at line 121 of device_batch_memcpy.hpp:
  //   return *(reinterpret_cast<Alias*>(buffer_src) + offset);
  // This fails to compile when buffer_src is const because Alias is unsigned char*.
  // Workaround: Declare source pointers as non-const T* instead of T const*, then apply
  // const_cast in the lambda when extracting column data. Since we only read from the source,
  // this is semantically safe despite rocPRIM's internal reinterpret_cast.
  //   auto h_srcs = make_host_vector<T const*>(num_columns, stream);
  auto h_srcs = make_host_vector<T*>(num_columns, stream);
  auto h_dsts = make_host_vector<T*>(num_columns, stream);

  std::transform(input.begin(), input.end(), h_srcs.begin(), [](auto& col) {
    return const_cast<T*>(col.template data<T>());
  });

  for (int i = 0; i < num_columns; ++i) {
    h_dsts[i] = reinterpret_cast<T*>(base_ptr + i * item_size * num_rows);
  }

  auto const mr = cudf::get_current_device_resource_ref();

  auto d_srcs = cudf::detail::make_device_uvector_async(h_srcs, stream, mr);
  auto d_dsts = cudf::detail::make_device_uvector_async(h_dsts, stream, mr);

  thrust::constant_iterator<size_t> sizes(static_cast<size_t>(item_size * num_rows));

  cudf::detail::batched_memcpy_async(
    d_srcs.begin(), d_dsts.begin(), sizes, num_columns, stream.value());
}

struct table_to_array_dispatcher {
  table_view const& input;
  device_span<cuda::std::byte> output;
  rmm::cuda_stream_view stream;

  template <typename T, CUDF_ENABLE_IF(is_fixed_width<T>())>
  void operator()() const
  {
    table_to_array_impl<T>(input, output, stream);
  }

  template <typename T, CUDF_ENABLE_IF(!is_fixed_width<T>())>
  void operator()() const
  {
    CUDF_FAIL("Unsupported dtype");
  }
};

}  // namespace

void table_to_array(table_view const& input,
                    device_span<cuda::std::byte> output,
                    rmm::cuda_stream_view stream)
{
  if (input.num_columns() == 0) return;

  auto const dtype = input.column(0).type();

  cudf::type_dispatcher<cudf::dispatch_storage_type>(
    dtype, table_to_array_dispatcher{input, output, stream});
}

}  // namespace detail

void table_to_array(table_view const& input,
                    device_span<cuda::std::byte> output,
                    rmm::cuda_stream_view stream)
{
  CUDF_FUNC_RANGE();
  cudf::detail::table_to_array(input, output, stream);
}

}  // namespace cudf
