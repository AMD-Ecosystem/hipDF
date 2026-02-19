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
namespace transformation {
namespace jit {

template <null_aware is_null_aware,
          bool may_evaluate_null,
          bool has_user_data,
          typename Out,
          typename... In>
CUDF_KERNEL void kernel(cudf::mutable_column_device_view_core const* outputs,
                        cudf::column_device_view_core const* inputs,
                        bool* intermediate_null_mask,
                        void* user_data)
{
  // inputs to JITIFY kernels have to be either sized-integral types or pointers. Structs or
  // references can't be passed directly/correctly as they will be crossing an ABI boundary

  auto const start  = cudf::detail::grid_1d::global_thread_id();
  auto const stride = cudf::detail::grid_1d::grid_stride();
  auto const size   = outputs[0].size();

  for (auto i = start; i < size; i += stride) {
    if constexpr (is_null_aware == null_aware::NO) {
      if constexpr (may_evaluate_null) {
        if (Out::is_null(outputs, i)) { continue; }
      }

      if constexpr (has_user_data) {
        GENERIC_TRANSFORM_OP(user_data, i, &Out::element(outputs, i), In::element(inputs, i)...);
      } else {
        GENERIC_TRANSFORM_OP(&Out::element(outputs, i), In::element(inputs, i)...);
      }

    } else {  // is_null_aware == null_aware::YES
      cuda::std::optional<typename Out::type> result;

      if constexpr (has_user_data) {
        GENERIC_TRANSFORM_OP(user_data, i, &result, In::nullable_element(inputs, i)...);
      } else {
        GENERIC_TRANSFORM_OP(&result, In::nullable_element(inputs, i)...);
      }

      Out::assign(outputs, i, *result);

      if constexpr (may_evaluate_null) { intermediate_null_mask[i] = result.has_value(); }
    }
  }
}

template <null_aware is_null_aware,
          bool may_evaluate_null,
          bool has_user_data,
          typename Out,
          typename... In>
CUDF_KERNEL void fixed_point_kernel(cudf::mutable_column_device_view_core const* outputs,
                                    cudf::column_device_view_core const* inputs,
                                    bool* intermediate_null_mask,
                                    void* user_data)
{
  auto const start        = cudf::detail::grid_1d::global_thread_id();
  auto const stride       = cudf::detail::grid_1d::grid_stride();
  auto const size         = outputs[0].size();
  auto const output_scale = static_cast<numeric::scale_type>(outputs[0].type().scale());

  for (auto i = start; i < size; i += stride) {
    if constexpr (is_null_aware == null_aware::NO) {
      if constexpr (may_evaluate_null) {
        if (Out::is_null(outputs, i)) { continue; }
      }

      typename Out::type result{numeric::scaled_integer<typename Out::type::rep>{0, output_scale}};

      if constexpr (has_user_data) {
        GENERIC_TRANSFORM_OP(user_data, i, &result, In::element(inputs, i)...);
      } else {
        GENERIC_TRANSFORM_OP(&result, In::element(inputs, i)...);
      }

      Out::assign(outputs, i, result);

    } else {  // is_null_aware == null_aware::YES
      cuda::std::optional<typename Out::type> result{
        typename Out::type{numeric::scaled_integer<typename Out::type::rep>{0, output_scale}}};

      if constexpr (has_user_data) {
        GENERIC_TRANSFORM_OP(user_data, i, &result, In::nullable_element(inputs, i)...);
      } else {
        GENERIC_TRANSFORM_OP(&result, In::nullable_element(inputs, i)...);
      }

      Out::assign(outputs, i, *result);

      if constexpr (may_evaluate_null) { intermediate_null_mask[i] = result.has_value(); }
    }
  }
}

template <null_aware is_null_aware,
          bool may_evaluate_null,
          bool has_user_data,
          typename Out,
          typename... In>
CUDF_KERNEL void span_kernel(cudf::jit::device_optional_span<typename Out::type> const* outputs,
                             cudf::column_device_view_core const* inputs,
                             bool* intermediate_null_mask,
                             void* user_data)
{
  auto const start  = cudf::detail::grid_1d::global_thread_id();
  auto const stride = cudf::detail::grid_1d::grid_stride();
  auto const size   = outputs[0].size();

  for (auto i = start; i < size; i += stride) {
    if constexpr (is_null_aware == null_aware::NO) {
      if constexpr (may_evaluate_null) {
        if (Out::is_null(outputs, i)) { continue; }
      }

      if constexpr (has_user_data) {
        GENERIC_TRANSFORM_OP(user_data, i, &Out::element(outputs, i), In::element(inputs, i)...);
      } else {
        GENERIC_TRANSFORM_OP(&Out::element(outputs, i), In::element(inputs, i)...);
      }
    } else {  // is_null_aware == null_aware::YES
      cuda::std::optional<typename Out::type> result;

      if constexpr (has_user_data) {
        GENERIC_TRANSFORM_OP(user_data, i, &result, In::nullable_element(inputs, i)...);
      } else {
        GENERIC_TRANSFORM_OP(&result, In::nullable_element(inputs, i)...);
      }

      Out::assign(outputs, i, *result);

      if constexpr (may_evaluate_null) { intermediate_null_mask[i] = result.has_value(); }
    }
  }
}

}  // namespace jit
}  // namespace transformation
}  // namespace cudf
