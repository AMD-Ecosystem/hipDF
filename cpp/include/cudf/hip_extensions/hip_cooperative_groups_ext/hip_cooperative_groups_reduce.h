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
#include <hip/amd_detail/amd_warp_sync_functions.h>

namespace cudf {
namespace hip_extensions {
namespace hip_cooperative_groups_ext {
namespace internal {

template <unsigned TILE_SIZE, typename ParentCGTy>
__device__ __attribute__((always_inline)) unsigned long long get_mask(
  const ::cooperative_groups::thread_block_tile<TILE_SIZE, ParentCGTy>& tile) {
  unsigned long long mask = ~0ull >> (64 - TILE_SIZE);
  return mask << (((threadIdx.x % warpSize) / TILE_SIZE) * TILE_SIZE);
}

} // namespace internal

// NOTE(HIP/AMD): This is a temporary workaround for the missing cg::reduce APIs
// in HIP's cooperative groups.

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

// NOTE(HIP/AMD): invoke_one / invoke_one_broadcast are missing from HIP's
// cooperative groups. Provide portable replacements:
//  - invoke_one(group, fn): the lowest-ranked member of the group calls fn once.
//  - invoke_one_broadcast(group, fn): the lowest-ranked member calls fn and the
//    returned value is broadcast to all members of the (tiled) group via shfl.
// TODO(SWDEV-ticket): file a HIP cooperative-groups feature request to add native
// invoke_one / invoke_one_broadcast (and the reduce overloads above); once available
// upstream, drop these portable replacements. The implementations below can serve as the
// reference for the feature request.

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
