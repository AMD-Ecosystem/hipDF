/*
 * SPDX-FileCopyrightText: Copyright (c) 2025-2026, NVIDIA CORPORATION.
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
#include <cudf/wrappers/durations.hpp>
#include <cudf/wrappers/timestamps.hpp>

#include <cuda/std/cstddef>

#include <cudf/detail/jit/accessors.cuh>
#include <cudf/detail/jit/span.cuh>

#pragma nv_hdrstop  // The above headers are used by the kernel below and need to be included before
                    // it. Each UDF will have a different operation-udf.hpp generated for it, so we
                    // need to put this pragma before including it to avoid PCH mismatch.

// clang-format off
// This header is an inlined header that defines the GENERIC_FILTER_OP function. It is placed here
// so the symbols in the headers above can be used by it.
#include <cudf/detail/operation-udf.hpp>
// clang-format on

namespace cudf {
namespace filtering {
namespace jit {

template <null_aware is_null_aware, bool has_user_data, typename Out, typename... In>
CUDF_KERNEL void kernel(cudf::jit::device_optional_span<typename Out::type> const* outputs,
                        cudf::column_device_view_core const* inputs,
                        void* user_data)
{
  auto const start  = cudf::detail::grid_1d::global_thread_id();
  auto const stride = cudf::detail::grid_1d::grid_stride();
  auto const output = outputs[0].to_span();
  auto const size   = output.size();

  for (auto i = start; i < size; i += stride) {
    bool applies = false;

    if constexpr (is_null_aware == null_aware::NO) {
      auto const any_null = (false || ... || In::is_null(inputs, i));

      if (!any_null) {
        if constexpr (has_user_data) {
          GENERIC_FILTER_OP(user_data, i, &applies, In::element(inputs, i)...);
        } else {
          GENERIC_FILTER_OP(&applies, In::element(inputs, i)...);
        }
      }
    } else {  // is_null_aware == null_aware::YES
      cuda::std::optional<bool> nullable_applies;

      if constexpr (has_user_data) {
        GENERIC_FILTER_OP(user_data, i, &nullable_applies, In::nullable_element(inputs, i)...);
      } else {
        GENERIC_FILTER_OP(&nullable_applies, In::nullable_element(inputs, i)...);
      }

      applies = nullable_applies.value_or(false);
    }

    output[i] = applies;
  }
}

}  // namespace jit
}  // namespace filtering
}  // namespace cudf
