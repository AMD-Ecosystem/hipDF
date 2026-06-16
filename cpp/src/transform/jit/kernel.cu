/*
 * SPDX-FileCopyrightText: Copyright (c) 2019-2026, NVIDIA CORPORATION.
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

#include <cudf/ast/detail/operator_functor.cuh>
#include <cudf/column/column_device_view_base.cuh>
#include <cudf/detail/utilities/grid_1d.cuh>
#include <cudf/strings/string_view.cuh>
#include <cudf/types.hpp>
#include <cudf/utilities/bit.hpp>
#include <cudf/wrappers/durations.hpp>
#include <cudf/wrappers/timestamps.hpp>

#include <cuda/std/cstddef>
#include <cuda/std/tuple>
#include <cuda/std/utility>

#include <jit/column_accessor.cuh>
#include <jit/column_device_view_wrappers.cuh>
#include <jit/sync.cuh>
#include <jit/type_list.cuh>

#pragma nv_hdrstop  // The above headers are used by the kernel below and need to be included before
                    // it. Each UDF will have a different operation-udf.hpp generated for it, so we
                    // need to put this pragma before including it to avoid PCH mismatch.

// clang-format off
// This header is an inlined header that defines the GENERIC_TRANSFORM_OP function. It is placed here
// so the symbols in the headers above can be used by it.
#include <cudf/detail/operation-udf.hpp>
// clang-format on

namespace cudf {
namespace jit {

template <bool has_user_data, typename Args>
__device__ void execute_transform_op(void* user_data, size_type element_idx, Args args)
{
  // TODO: static assert invocable
  if constexpr (has_user_data) {
    cuda::std::apply([&](auto... a) { GENERIC_TRANSFORM_OP(a...); },
                     cuda::std::tuple_cat(cuda::std::tuple{user_data, element_idx}, args));
  } else {
    cuda::std::apply([&](auto... a) { GENERIC_TRANSFORM_OP(a...); }, args);
  }
}

/// @brief The generic transform kernel. Supports all types and nullability combinations.
template <null_aware is_null_aware,
          bool has_user_data,
          typename InputAccessors,
          typename OutputAccessors>
CUDF_KERNEL void transform_kernel(size_type row_size,
                                  bitmask_type const* __restrict__ stencil,
                                  void* __restrict__ user_data,
                                  column_device_view_core const* __restrict__ input_cols,
                                  mutable_column_device_view_core const* __restrict__ output_cols)
{
  // TODO: ensure block size is a multiple of warp size for correct warp-synchronous behavior
  auto start  = detail::grid_1d::global_thread_id();
  auto stride = detail::grid_1d::grid_stride();

  for (auto element_idx = start; element_idx < row_size; element_idx += stride) {
    if constexpr (is_null_aware == null_aware::NO) {
      if (stencil != nullptr && !bit_is_set(stencil, element_idx)) { continue; }

      auto ins = InputAccessors::map(
        [&]<typename... A>() { return cuda::std::tuple{A::element(input_cols, element_idx)...}; });

      auto outs = OutputAccessors::map([&]<typename... A>() {
        return cuda::std::tuple{A::output_arg(output_cols, element_idx)...};
      });

      auto out_ptrs =
        cuda::std::apply([&](auto&... args) { return cuda::std::tuple{&args...}; }, outs);

      execute_transform_op<has_user_data>(
        user_data, element_idx, cuda::std::tuple_cat(out_ptrs, ins));

      OutputAccessors::map([&]<typename... A>() {
        (A::assign(output_cols, element_idx, cuda::std::get<A::index>(outs)), ...);
      });

    } else {
      // NOTE(HIP/AMD): this is reached inside the grid-stride loop, so lanes whose row is out
      // of range have already exited and are not converged. Passing LANE_MASK_ALL as the
      // participating mask to __ballot_sync would reference inactive lanes and faults on AMD
      // (and is UB on NVIDIA). Use __activemask() to ballot over exactly the executing lanes;
      // the resulting mask drives both the null-word compaction and the leader election. On AMD
      // __activemask() returns a 64-bit wavefront mask (HIPRTC static-asserts a 64-bit mask).
      // See SWDEV-490930.
      auto active_mask = __activemask();

      auto ins = InputAccessors::map([&]<typename... A>() {
        return cuda::std::tuple{A::nullable_element(input_cols, element_idx)...};
      });

      auto outs = OutputAccessors::map([&]<typename... A>() {
        return cuda::std::tuple{A::null_output_arg(output_cols, element_idx)...};
      });

      auto out_ptrs =
        cuda::std::apply([&](auto&... args) { return cuda::std::tuple{&args...}; }, outs);

      execute_transform_op<has_user_data>(
        user_data, element_idx, cuda::std::tuple_cat(out_ptrs, ins));

      OutputAccessors::map([&]<typename... A>() {
        (A::assign(output_cols, element_idx, *cuda::std::get<A::index>(outs)), ...);
        (warp_compact_validity<A>(
           active_mask, output_cols, element_idx, cuda::std::get<A::index>(outs).has_value()),
         ...);
      });
    }
  }
}

}  // namespace jit
}  // namespace cudf
