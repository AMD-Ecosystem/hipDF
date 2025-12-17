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

#include <cudf/column/column.hpp>
#include <cudf/column/column_view.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>

#ifdef __HIP_PLATFORM_AMD__
#include <hipcub/device/device_radix_sort.hpp>
#include <rocprim/types/tuple.hpp>
#else
#include <cub/device/device_radix_sort.cuh>
#endif
#include <thrust/transform.h>

namespace cudf {
namespace detail {
namespace {

template <typename F>
struct float_pair {
  size_type s;  // index bias for sorting nan
  F f;          // actual float value to sort
};

template <typename F>
struct float_decomposer {
  // NOTE(HIP/AMD): rocPRIM/hipCUB requires rocprim::tuple<T&, U&> for radix sort decomposers.
  // Other tuple types cause SFINAE failures in radix_key_codec's is_tuple_of_references check.
#if defined(CCCL_VERSION) && CCCL_VERSION == 2007000
  __device__ rocprim::tuple<size_type&, F&> operator()(float_pair<F>& key) const
  {
    return rocprim::tuple<size_type&, F&>{key.s, key.f};
  }
#else
  __device__ cuda::std::tuple<size_type&, F&> operator()(float_pair<F>& key) const
  {
    return {key.s, key.f};
  }
#endif
};

template <typename F>
struct float_to_pair_fn {
  F const* fs;
  __device__ float_pair<F> operator()(cudf::size_type idx) const
  {
    auto const f = fs[idx];
    auto const s = (isnan(f) * (idx + 1));  // multiplier helps keep the sort stable for NaNs
    return float_pair<F>{s, f};
  }
};

/**
 * @brief Sorts fixed-width columns using cub radix sort
 *
 * Should not be used if `input.has_nulls()==true`
 */
struct sort_radix_fn {
  column_view const input;       // input column to sort
  mutable_column_view output;    // output sorted
  bool ascending;                // true if ascending sort
  rmm::cuda_stream_view stream;  // stream for allocations and kernel launches

  template <typename T>
  void sort_radix()
  {
    auto d_in          = input.data<T>();
    auto d_out         = output.data<T>();
    auto const end_bit = sizeof(T) * 8;
    auto const sv      = stream.value();
    auto const n       = input.size();
    // cub radix sort implementation is always stable
    std::size_t tmp_bytes = 0;
    if (ascending) {
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeys(nullptr, tmp_bytes, d_in, d_out, n, 0, end_bit, sv));
      auto tmp_stg = rmm::device_buffer(tmp_bytes, stream);
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeys(tmp_stg.data(), tmp_bytes, d_in, d_out, n, 0, end_bit, sv));
    } else {
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeysDescending(nullptr, tmp_bytes, d_in, d_out, n, 0, end_bit, sv));
      auto tmp_stg = rmm::device_buffer(tmp_bytes, stream);
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeysDescending(
        tmp_stg.data(), tmp_bytes, d_in, d_out, n, 0, end_bit, sv));
    }
  }

  template <typename T>
  void operator()()
    requires(cudf::is_floating_point<T>())
  {
    auto pair_in  = rmm::device_uvector<float_pair<T>>(input.size(), stream);
    auto d_in     = pair_in.begin();
    auto pair_out = rmm::device_uvector<float_pair<T>>(input.size(), stream);
    auto d_out    = pair_out.begin();

    thrust::transform(rmm::exec_policy_nosync(stream),
                      thrust::counting_iterator<size_type>(0),
                      thrust::counting_iterator<size_type>(input.size()),
                      d_in,
                      float_to_pair_fn<T>{input.begin<T>()});

    auto const decomposer = float_decomposer<T>{};
    auto const end_bit    = sizeof(float_pair<T>) * 8;
    auto const sv         = stream.value();
    auto const n          = input.size();
    // cub radix sort implementation is always stable
    std::size_t tmp_bytes = 0;
    if (ascending) {
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeys(
        nullptr, tmp_bytes, d_in, d_out, n, decomposer, 0, end_bit, sv));
      auto tmp_stg = rmm::device_buffer(tmp_bytes, stream);
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeys(
        tmp_stg.data(), tmp_bytes, d_in, d_out, n, decomposer, 0, end_bit, sv));
    } else {
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeysDescending(
        nullptr, tmp_bytes, d_in, d_out, n, decomposer, 0, end_bit, sv));
      auto tmp_stg = rmm::device_buffer(tmp_bytes, stream);
      CUDF_CUDA_TRY(hipcub::DeviceRadixSort::SortKeysDescending(
        tmp_stg.data(), tmp_bytes, d_in, d_out, n, decomposer, 0, end_bit, sv));
    }
    thrust::transform(rmm::exec_policy_nosync(stream),
                      d_out,
                      d_out + input.size(),
                      output.begin<T>(),
                      [] __device__(float_pair<T> const& p) { return p.f; });
  }

  template <typename T>
  void operator()()
    requires(cudf::is_chrono<T>())
  {
    using rep_type = typename T::rep;
    sort_radix<rep_type>();
  }

  template <typename T>
  void operator()()
    requires(cudf::is_fixed_width<T>() and !cudf::is_chrono<T>() and !cudf::is_floating_point<T>())
  {
    sort_radix<T>();
  }

  template <typename T>
  void operator()()
    requires(not cudf::is_fixed_width<T>())
  {
    CUDF_UNREACHABLE("invalid type for faster sort");
  }
};

}  // namespace

bool is_radix_sortable(column_view const& column)
{
  return !column.has_nulls() && cudf::is_fixed_width(column.type());
}

std::unique_ptr<column> sort_radix(column_view const& input,
                                   bool ascending,
                                   rmm::cuda_stream_view stream,
                                   rmm::device_async_resource_ref mr)
{
  auto result   = std::make_unique<column>(input, stream, mr);
  auto out_view = result->mutable_view();
  cudf::type_dispatcher<dispatch_storage_type>(input.type(),
                                               sort_radix_fn{input, out_view, ascending, stream});
  return result;
}

}  // namespace detail
}  // namespace cudf
