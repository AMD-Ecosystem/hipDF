/*
 * Copyright (c) 2024-2025, NVIDIA CORPORATION.
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

#include <cudf/detail/iterator.cuh>
#include <cudf/detail/utilities/vector_factories.hpp>
#include <cudf/utilities/memory_resource.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_buffer.hpp>

#include <hipcub/hipcub.hpp>
#include <cuda/functional>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/iterator/transform_iterator.h>
#include <thrust/transform.h>

namespace CUDF_EXPORT cudf {
namespace detail {

/**
 * @brief Helper to batched memset a host span of device spans to the provided value
 *
 * @param host_buffers Host span of device spans of data
 * @param value Value to memset all device spans to
 * @param stream Stream used for device memory operations and kernel launches
 *
 * @return The data in device spans all set to value
 */
template <typename T>
void batched_memset(cudf::host_span<cudf::device_span<T> const> host_buffers,
                    T const value,
                    rmm::cuda_stream_view stream)
{
  // Copy buffer spans into device memory and then get sizes
  auto buffers = cudf::detail::make_device_uvector_async(
    host_buffers, stream, cudf::get_current_device_resource_ref());

  // Vector of sizes of all buffer spans
  auto sizes = thrust::make_transform_iterator(
    thrust::counting_iterator<size_t>(0),
    cuda::proclaim_return_type<size_t>(
      [buffers = buffers.data()] __device__(size_t i) { return buffers[i].size(); }));

  // Constant iterator to the value to memset
  auto iter_in = thrust::make_constant_iterator(thrust::make_constant_iterator(value));

  // Iterator to each device span pointer
  auto iter_out = thrust::make_transform_iterator(
    thrust::counting_iterator<size_t>(0),
    cuda::proclaim_return_type<T*>(
      [buffers = buffers.data()] __device__(size_t i) { return buffers[i].data(); }));

  size_t temp_storage_bytes = 0;
  auto const num_buffers    = host_buffers.size();

  CUDF_CUDA_TRY(hipcub::DeviceCopy::Batched(
    nullptr, temp_storage_bytes, iter_in, iter_out, sizes, num_buffers, stream));

  // Allocate temporary storage
  rmm::device_buffer d_temp_storage(
    temp_storage_bytes, stream, cudf::get_current_device_resource_ref());

  CUDF_CUDA_TRY(hipcub::DeviceCopy::Batched(
    d_temp_storage.data(), temp_storage_bytes, iter_in, iter_out, sizes, num_buffers, stream));
}

}  // namespace detail
}  // namespace CUDF_EXPORT cudf
