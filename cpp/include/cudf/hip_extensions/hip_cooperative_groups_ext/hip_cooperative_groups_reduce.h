// MIT License
//
// Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
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

#include <hip/hip_cooperative_groups.h>
#include <hip/hip_version.h>

// NOTE(HIP/AMD): `cg::reduce` (with the `plus`/`less`/`greater`/`bit_and`/`bit_or` function
// objects) landed in HIP cooperative groups in ROCm 7.14, in <hip/cooperative_groups/hip_reduce.h>
// - which is deliberately NOT pulled in by <hip/hip_cooperative_groups.h>, so it has to be
// included explicitly. Below 7.14 we fall back to the local implementation further down.
// The official implementation is a strict superset of ours: same tile member-mask computation,
// plus an `__activemask()` intersection and a generic `__reduce_op_sync` fallback for arbitrary
// operators. <hip/hip_version.h> is included above so HIP_VERSION_MAJOR/MINOR are always defined
// here and this guard never silently falls through to the wrong branch.
#if (HIP_VERSION_MAJOR < 7) || (HIP_VERSION_MAJOR == 7 && HIP_VERSION_MINOR < 14)
#define CUDF_HIP_CG_REDUCE_WAR 1
#include <hip/amd_detail/amd_warp_sync_functions.h>
#else
#define CUDF_HIP_CG_REDUCE_WAR 0
#include <hip/cooperative_groups/hip_reduce.h>
#endif

namespace cudf {
namespace hip_extensions {
namespace hip_cooperative_groups_ext {
namespace internal {

#if CUDF_HIP_CG_REDUCE_WAR
template <unsigned TILE_SIZE, typename ParentCGTy>
__device__ __attribute__((always_inline)) unsigned long long get_mask(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile) {
  unsigned long long mask = ~0ull >> (64 - TILE_SIZE);
  return mask << (((threadIdx.x % warpSize) / TILE_SIZE) * TILE_SIZE);
}
#endif

} // namespace internal

#if CUDF_HIP_CG_REDUCE_WAR
// FIXME(HIP/AMD, <HIP-CG-REDUCE>): workaround for cg::reduce being absent from HIP's cooperative
// groups before ROCm 7.14. Delete this whole block (and the CUDF_HIP_CG_REDUCE_WAR guard) once the
// minimum supported ROCm is >= 7.14; the official <hip/cooperative_groups/hip_reduce.h> used on
// newer toolchains provides the same API with a superset of the functionality.

template <typename TArg>
struct plus {
  __device__ __attribute__((always_inline)) TArg operator()(const TArg& lhs, const TArg& rhs) const
  {
    return lhs + rhs;
  }
};

template <typename TArg>
struct less {
  __device__ __attribute__((always_inline)) TArg operator()(const TArg& lhs, const TArg& rhs) const
  {
    return lhs < rhs ? lhs : rhs;
  }
};

template <typename TArg>
struct greater {
  __device__ __attribute__((always_inline)) TArg operator()(const TArg& lhs, const TArg& rhs) const
  {
    return lhs > rhs ? lhs : rhs;
  }
};

template <unsigned TILE_SIZE, typename ParentCGTy, typename TArg>
__device__ __attribute__((always_inline)) TArg reduce(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile,
  TArg count,
  plus<TArg>& op) {
  auto member_mask = internal::get_mask(tile);
  return __reduce_add_sync(member_mask, count);
}

template <unsigned TILE_SIZE, typename ParentCGTy, typename TArg>
__device__ __attribute__((always_inline)) TArg reduce(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile,
  TArg count,
  plus<TArg>&& op) {
  auto member_mask = internal::get_mask(tile);
  return __reduce_add_sync(member_mask, count);
}

template <unsigned TILE_SIZE, typename ParentCGTy, typename TArg>
__device__ __attribute__((always_inline)) TArg reduce(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile,
  TArg value,
  less<TArg>& op) {
  auto member_mask = internal::get_mask(tile);
  return __reduce_min_sync(member_mask, value);
}

template <unsigned TILE_SIZE, typename ParentCGTy, typename TArg>
__device__ __attribute__((always_inline)) TArg reduce(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile,
  TArg value,
  less<TArg>&& op) {
  auto member_mask = internal::get_mask(tile);
  return __reduce_min_sync(member_mask, value);
}

template <unsigned TILE_SIZE, typename ParentCGTy, typename TArg>
__device__ __attribute__((always_inline)) TArg reduce(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile,
  TArg value,
  greater<TArg>& op) {
  auto member_mask = internal::get_mask(tile);
  return __reduce_max_sync(member_mask, value);
}

template <unsigned TILE_SIZE, typename ParentCGTy, typename TArg>
__device__ __attribute__((always_inline)) TArg reduce(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile,
  TArg value,
  greater<TArg>&& op) {
  auto member_mask = internal::get_mask(tile);
  return __reduce_max_sync(member_mask, value);
}

#else  // CUDF_HIP_CG_REDUCE_WAR

// ROCm >= 7.14: forward to the official implementations so callers that alias this namespace as
// `cg` keep working unchanged. (The trailing `using namespace ::cooperative_groups;` below would
// make these visible anyway; naming them explicitly documents the intent and keeps the two
// branches of the guard symmetric.)
using ::cooperative_groups::bit_and;
using ::cooperative_groups::bit_or;
using ::cooperative_groups::greater;
using ::cooperative_groups::less;
using ::cooperative_groups::plus;
using ::cooperative_groups::reduce;

#endif  // CUDF_HIP_CG_REDUCE_WAR

// TODO(HIP/AMD, AIRUNTIME-2740): invoke_one / invoke_one_broadcast are still missing
// from HIP's cooperative groups as of ROCm 7.14 (unlike cg::reduce). Portable
// replacements below; drop them once the native APIs are available.

template <typename Group, typename F>
__device__ __attribute__((always_inline)) void invoke_one(const Group& group, F&& fn) {
  if (group.thread_rank() == 0) { fn(); }
}

// Group must support thread_rank() and shfl() (thread_block_tile or coalesced_group).
template <typename Group, typename F>
__device__ __attribute__((always_inline)) auto invoke_one_broadcast(const Group& group, F&& fn)
  -> decltype(fn()) {
  using result_t = decltype(fn());
  result_t result{};
  if (group.thread_rank() == 0) { result = fn(); }
  return group.shfl(result, 0);
}

// Passthroughs for commonly used cooperative_groups types/functions so callers
// can alias this namespace as `cg` and continue to access tiled_partition and
// this_thread_block alongside the reduce helpers.
using ::cooperative_groups::thread_block;
using ::cooperative_groups::thread_block_tile;
using ::cooperative_groups::tiled_partition;
using ::cooperative_groups::this_thread_block;
using ::cooperative_groups::this_grid;
using ::cooperative_groups::coalesced_group;
using namespace ::cooperative_groups;

} // namespace hip_cooperative_groups_ext
} // namespace hip_extensions
} // namespace cudf
