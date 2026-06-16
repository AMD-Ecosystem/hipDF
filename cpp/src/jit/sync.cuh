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

#pragma once
#include <cudf/column/column_device_view_base.cuh>
#include <cudf/detail/utilities/cuda.cuh>
#include <cudf/types.hpp>
#include <cudf/utilities/bit.hpp>

// NOTE(HIP/AMD): cuda::ptx (and elect.sync) are NVIDIA PTX-only and libhipcxx
// hard-errors on including <cuda/ptx> for AMD targets. elect.sync is a Hopper+
// (sm_90) optimization; AMD always uses the generic leader-election fallback
// below, so only pull in <cuda/ptx> on the NVIDIA path.
#if !defined(__HIP_PLATFORM_AMD__)
#include <cuda/ptx>
#endif
#include <cuda/std/bit>

namespace cudf {

// NOTE(HIP/AMD): the lane mask is wavefront-wide; on AMD that is 64 lanes, so it must
// be a 64-bit type. countr_zero on a 64-bit mask yields the correct leader lane.
#if defined(__HIP_PLATFORM_AMD__)
using lane_mask_type = uint64_t;
#else
using lane_mask_type = unsigned int;
#endif

__device__ inline bool warp_elect(lane_mask_type mask)
{
#if !defined(__HIP_PLATFORM_AMD__) && __CUDA_ARCH__ >= 900
  // use elect.sync
  return cuda::ptx::elect_sync(mask);
#else
  // fallback: manually elect a leader (e.g., the first active thread)
  int leader = mask == 0 ? 0 : cuda::std::countr_zero(mask);
  int lane   = (threadIdx.x & (cudf::detail::warp_size - 1));
  return (lane == leader);
#endif
}

namespace jit {

template <typename Out>
__device__ void warp_compact_validity(lane_mask_type active_mask,
                                      mutable_column_device_view_core const* outcols,
                                      size_type row,
                                      bool is_valid)
{
  auto null_word = __ballot_sync(active_mask, is_valid);
  // use warp-elect to make sure we only issue one memory transaction per warp
  if (warp_elect(active_mask)) {
    auto const lane_id  = static_cast<size_type>(threadIdx.x & (cudf::detail::warp_size - 1));
    auto const row_base = row - lane_id;
#if defined(__HIP_PLATFORM_AMD__)
    // NOTE(HIP/AMD): the wavefront is 64 lanes wide but cudf null masks are 32-bit words, so a
    // single 64-lane ballot spans two consecutive null-mask words. Split it and write both.
    static_assert(cudf::detail::warp_size == 64,
                  "warp_compact_validity assumes a 64-lane wavefront on AMD");
    auto const word_base = cudf::word_index(row_base);
    Out::set_null_mask_word(
      outcols, word_base, static_cast<bitmask_type>(null_word & 0xFFFF'FFFFULL));
    Out::set_null_mask_word(
      outcols, word_base + 1, static_cast<bitmask_type>((null_word >> 32) & 0xFFFF'FFFFULL));
#else
    Out::set_null_mask_word(outcols, cudf::word_index(row_base), null_word);
#endif
  }
}

}  // namespace jit
}  // namespace cudf
