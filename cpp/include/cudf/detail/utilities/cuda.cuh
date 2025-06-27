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
// Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

#include "cudf/cuda_runtime.h"
#include <cudf/types.hpp>
#include <cudf/utilities/default_stream.hpp>

#include <rmm/cuda_stream_view.hpp>

#include <hipcub/hipcub.hpp>
#include <cuda/std/type_traits>

namespace cudf {
namespace detail {

/**
 * @brief Size of a warp in a CUDA kernel.
 */
#if defined(__HIP_PLATFORM_AMD__)
#ifndef CUDF_USE_WARPSIZE_32
static constexpr size_type warp_size{64};
#else
// for RDNA3/gfx1100
static constexpr size_type warp_size{32};
#endif
#else
static constexpr size_type warp_size{32};
#endif

/**
 * @brief Performs a sum reduction of values from the same lane across all
 * warps in a thread block and returns the result on thread 0 of the block.
 *
 * All threads in a block must call this function, but only values from the
 * threads indicated by `leader_lane` will contribute to the result. Similarly,
 * the returned result is only defined on `threadIdx.x==0`.
 *
 * @tparam block_size The number of threads in the thread block (must be less
 * than or equal to 1024)
 * @tparam leader_lane The id of the lane in the warp whose value contributes to
 * the reduction
 * @tparam T Arithmetic type
 * @param lane_value The value from the lane that contributes to the reduction
 * @return The sum reduction of the values from each lane. Only valid on
 * `threadIdx.x == 0`. The returned value on all other threads is undefined.
 */
template <int32_t block_size, int32_t leader_lane = 0, typename T>
__device__ T single_lane_block_sum_reduce(T lane_value)
{
  static_assert(block_size <= 1024, "Invalid block size.");
  static_assert(cuda::std::is_arithmetic_v<T>, "Invalid non-arithmetic type.");
  constexpr auto warps_per_block{block_size / warp_size};
  auto const lane_id{threadIdx.x % warp_size};
  auto const warp_id{threadIdx.x / warp_size};
  __shared__ T lane_values[warp_size];

  // Load each lane's value into a shared memory array
  if (lane_id == leader_lane) { lane_values[warp_id] = lane_value; }
  __syncthreads();

  // Use a single warp to do the reduction, result is only defined on
  // threadId.x == 0
  T result{0};
  if (warp_id == 0) {
    __shared__ typename hipcub::WarpReduce<T>::TempStorage temp;
    lane_value = (lane_id < warps_per_block) ? lane_values[lane_id] : T{0};
    result     = hipcub::WarpReduce<T>(temp).Sum(lane_value);
  }
  // Shared memory has block scope, so sync here to ensure no data
  // races between successive calls to this function in the same
  // kernel.
  __syncthreads();
  return result;
}

template <class F>
CUDF_KERNEL void single_thread_kernel(F f)
{
  f();
}

/**
 * @brief single thread cuda kernel
 *
 * @tparam Functor Device functor type
 * @param functor device functor object or device lambda function
 * @param stream CUDA stream used for the kernel launch
 */
template <class Functor>
void device_single_thread(Functor functor, rmm::cuda_stream_view stream)
{
  single_thread_kernel<<<1, 1, 0, stream.value()>>>(functor);
}

}  // namespace detail
}  // namespace cudf
