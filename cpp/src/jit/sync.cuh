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

// NOTE(HIP/AMD): the lane mask must be 64-bit on AMD for *both* wave64 and wave32 targets:
// HIP's `__ballot_sync`/`__activemask` return `unsigned long long` regardless of the wavefront
// size, so that masks are portable across wave32 and wave64 (see SWDEV-490930). `countr_zero`
// on a 64-bit mask yields the correct leader lane in either case.
// This is deliberately NOT `bitmask_type`: that is the null-mask *storage* word type and is only
// coincidentally the same width on wave64. Conflating the two is a correctness hazard - see the
// note in `warp_compact_validity` below.
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
  // TODO(HIP/AMD, <LIBHIPCXX>): replace this hand-rolled leader election with a wavefront-size
  // agnostic `elect` intrinsic once libhipcxx provides one (must work for wave32 and wave64).
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
    // NOTE(HIP/AMD): in hipDF the null-mask word width always tracks the wavefront width
    // (`bitmask_type` is uint64_t at warp_size 64, uint32_t under CUDF_USE_WARPSIZE_32), so one
    // wavefront-wide ballot maps to exactly one null-mask word on every supported configuration,
    // just as on NVIDIA. Do NOT split a 64-bit ballot into two 32-bit halves: `set_null_mask_word`
    // takes a `bitmask_type` and `word_index()` divides by `size_in_bits<bitmask_type>()`, so a
    // split both zero-fills the upper half of word N and clobbers word N+1, which belongs to the
    // next wavefront.
    static_assert(static_cast<cudf::size_type>(cudf::detail::size_in_bits<bitmask_type>()) ==
                    cudf::detail::warp_size,
                  "warp_compact_validity assumes one wavefront ballot fills exactly one "
                  "null-mask word");
    Out::set_null_mask_word(
      outcols, cudf::word_index(row_base), static_cast<bitmask_type>(null_word));
  }
}

}  // namespace jit
}  // namespace cudf
