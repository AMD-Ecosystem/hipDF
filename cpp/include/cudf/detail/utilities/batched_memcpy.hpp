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

#include <cudf/detail/iterator.cuh>
#include <cudf/utilities/memory_resource.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_buffer.hpp>

#include <hipcub/hipcub.hpp>
#include <cuda/functional>
#include <thrust/iterator/constant_iterator.h>

namespace CUDF_EXPORT cudf {
namespace detail {

/**
 * @brief Helper to batched memcpy specified numbers of bytes from source device iterators to
 * destination device iterators
 *
 * @tparam SrcIterator **[inferred]** The type of device-accessible source addresses iterator
 * @tparam DstIterator **[inferred]** The type of device-accessible destination address iterator
 * @tparam SizeIterator **[inferred]** The type of device-accessible buffer size iterator
 *
 * @param src_iter Device-accessible iterator to source addresses
 * @param dst_iter Device-accessible iterator to destination addresses
 * @param size_iter Device-accessible iterator to the buffer sizes (in bytes)
 * @param num_buffs Number of buffers to be copied
 * @param stream CUDA stream to use
 */
template <typename SrcIterator, typename DstIterator, typename SizeIterator>
void batched_memcpy_async(SrcIterator src_iter,
                          DstIterator dst_iter,
                          SizeIterator size_iter,
                          size_t num_buffs,
                          rmm::cuda_stream_view stream)
{
  // FIXME(HIP/AMD): Early exit if num_buffs is zero.
  // FIXME(HIP/AMD): hipcub batched_memcpy does not like offsets.size()==0
  if(num_buffs==0) return;

  size_t temp_storage_bytes = 0;
  CUDF_CUDA_TRY(hipcub::DeviceMemcpy::Batched(
    nullptr, temp_storage_bytes, src_iter, dst_iter, size_iter, num_buffs, stream.value()));

  rmm::device_buffer d_temp_storage{temp_storage_bytes, stream.value()};

  CUDF_CUDA_TRY(hipcub::DeviceMemcpy::Batched(d_temp_storage.data(),
                             temp_storage_bytes,
                             src_iter,
                             dst_iter,
                             size_iter,
                             num_buffs,
                             stream.value()));
}

}  // namespace detail
}  // namespace CUDF_EXPORT cudf
