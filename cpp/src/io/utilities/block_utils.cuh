/*
 * SPDX-FileCopyrightText: Copyright (c) 2019-2025, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */
// MIT License
//
// Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
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
#include <cudf/detail/utilities/cuda.cuh>

#ifdef __HIP_PLATFORM_AMD__
#include <hip/hip_cooperative_groups.h>
#include <hipcub/hipcub.hpp>
#else
#include <cooperative_groups.h>
#include <cub/cub.cuh>
#endif
#include <cuda/std/cstdint>
#include <cuda/std/cstring>

namespace cudf {
namespace io {

template <typename T>
inline __device__ T shuffle(T var, int lane = 0)
{
  return __shfl_sync((uint64_t) LANE_MASK_ALL, var, lane); // NOTE(HIP/AMD): See SWDEV-490930
}

template <typename T>
inline __device__ T shuffle_xor(T var, uint32_t delta)
{
  return __shfl_xor_sync((uint64_t) LANE_MASK_ALL, var, delta); // NOTE(HIP/AMD): See SWDEV-490930
}

// NOTE(HIP/AMD): See SWDEV-490930
inline __device__ bitmask_type ballot(int pred)
{
  return __ballot_sync((uint64_t)LANE_MASK_ALL, pred);
}

// Warp reduction helpers
template <cudf::size_type size, typename T>
inline __device__ T warp_reduce_or(T acc)
{
  static_assert(size >= 1 and size <= cudf::detail::warp_size and (size & (size - 1)) == 0,
                "Size must be a power of 2 and less than or equal to the warp size");
  if constexpr (size == 1) {
    return acc;
  } else {
    acc = warp_reduce_or<size / 2>(acc);
    return acc | shuffle_xor(acc, size / 2);
  }
}

template <cudf::size_type size, typename T>
inline __device__ T warp_reduce_pos(T pos, uint32_t t)
{
  static_assert(size >= 2 and size <= cudf::detail::warp_size and (size & (size - 1)) == 0,
                "Size must be a power of 2 between 2 and warp_size");
  if constexpr (size == 2) {
    T const tmp = shuffle(pos, t & 0x1e);
    return pos + ((t & 1) ? tmp : 0);
  } else {
    pos         = warp_reduce_pos<size / 2>(pos, t);
    T const tmp = shuffle(pos, (t & ~(size - 1)) | (size / 2 - 1));
    return pos + ((t & (size / 2)) ? tmp : 0);
  }
}

template <typename T>
  requires(cuda::std::is_integral_v<T>)
inline __device__ T unaligned_load(uint8_t const* p)
{
  T value;
  cuda::std::memcpy(&value, p, sizeof(T));
  return value;
}

template <uint32_t nthreads, bool sync_before_store>
inline __device__ void memcpy_block(void* dstv,
                                    void const* srcv,
                                    uint32_t len,
                                    cooperative_groups::thread_block const& block)
{
  static_assert(
    nthreads >= sizeof(uint32_t),
    "The kernel block size (nthreads) must be greater than or equal to the size of uint32_t");
  auto const t    = block.thread_rank();
  auto* dst       = static_cast<uint8_t*>(dstv);
  auto const* src = static_cast<uint8_t const*>(srcv);
  // Align output to 32-bit
  auto const dst_align_bytes = static_cast<uint32_t>(0x3 & -reinterpret_cast<intptr_t>(dst));
  if (dst_align_bytes != 0) {
    auto const align_len = cuda::std::min<uint32_t>(dst_align_bytes, len);
    uint8_t byte;
    if (t < align_len) { byte = src[t]; }
    if constexpr (sync_before_store) { block.sync(); }
    if (t < align_len) { dst[t] = byte; }
    src += align_len;
    dst += align_len;
    len -= align_len;
  }
  // Copy 32-bit chunks
  while (len >= sizeof(uint32_t)) {
    auto const copy_cnt = cuda::std::min<uint32_t>(len / sizeof(uint32_t), nthreads);
    uint32_t value;
    if (t < copy_cnt) { value = unaligned_load<uint32_t>(src + (t * sizeof(uint32_t))); }
    if constexpr (sync_before_store) { block.sync(); }
    if (t < copy_cnt) { reinterpret_cast<uint32_t*>(dst)[t] = value; }
    src += copy_cnt * sizeof(uint32_t);
    dst += copy_cnt * sizeof(uint32_t);
    len -= copy_cnt * sizeof(uint32_t);
  }
  // Copy the remaining bytes
  if (len != 0) {
    uint8_t byte;
    if (t < len) { byte = src[t]; }
    if constexpr (sync_before_store) { block.sync(); }
    if (t < len) { dst[t] = byte; }
  }
}

}  // namespace io
}  // namespace cudf
