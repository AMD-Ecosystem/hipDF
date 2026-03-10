/*
 * Copyright (c) 2020-2025, NVIDIA CORPORATION.
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

#include <cudf/utilities/error.hpp>
#include <cudf/utilities/prefetch.hpp>

#include <rmm/cuda_device.hpp>

#include <atomic>
#include <iostream>

namespace cudf::prefetch {

namespace detail {

std::atomic_bool& enabled()
{
  static std::atomic_bool value;
  return value;
}

std::atomic_bool& debug()
{
  static std::atomic_bool value;
  return value;
}

cudaError_t prefetch_noexcept(void const* ptr,
                              std::size_t size,
                              rmm::cuda_stream_view stream,
                              rmm::cuda_device_id device_id) noexcept
{
  if (!detail::enabled()) { return cudaSuccess; }

  // Don't try to prefetch nullptrs or empty data. Sometimes libcudf has column
  // views that use nullptrs with a nonzero size as an optimization.
  if (ptr == nullptr) {
    if (detail::debug()) { std::cerr << "Skipping prefetch of nullptr" << std::endl; }
    return cudaSuccess;
  }
  if (size == 0) {
    if (detail::debug()) { std::cerr << "Skipping prefetch of size 0" << std::endl; }
    return cudaSuccess;
  }
  if (detail::debug()) {
    std::cerr << "Prefetching " << size << " bytes at location " << ptr << std::endl;
  }

#if defined(CUDART_VERSION) && CUDART_VERSION >= 13000
  cudaMemLocation location{
    (device_id.value() == cudaCpuDeviceId) ? cudaMemLocationTypeHost : cudaMemLocationTypeDevice,
    device_id.value()};
  constexpr int flags = 0;
  auto result         = cudaMemPrefetchAsync(ptr, size, location, flags, stream.value());
#else
  auto result = cudaMemPrefetchAsync(ptr, size, device_id.value(), stream.value());
#endif
  // Need to flush the CUDA error so that the context is not corrupted.
  if (result == cudaErrorInvalidValue) { HIPDF_ASSERT_CUDA_SUCCESS(cudaGetLastError()); }
  return result;
}

void prefetch(void const* ptr,
              std::size_t size,
              rmm::cuda_stream_view stream,
              rmm::cuda_device_id device_id)
{
  auto result = prefetch_noexcept(ptr, size, stream, device_id);
  // Ignore cudaErrorInvalidValue because that will be raised if prefetching is
  // attempted on unmanaged memory.
  if ((result != cudaErrorInvalidValue) && (result != cudaSuccess)) {
    std::cerr << "Prefetch failed" << std::endl;
    CUDF_CUDA_TRY(result);
  }
}

}  // namespace detail

void enable() noexcept { detail::enabled() = true; }

void disable() noexcept { detail::enabled() = false; }

void enable_debugging() noexcept { detail::debug() = true; }

void disable_debugging() noexcept { detail::debug() = false; }
}  // namespace cudf::prefetch
