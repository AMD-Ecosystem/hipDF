/*
 * Copyright (c) 2025, NVIDIA CORPORATION.
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

#pragma once
#include <cudf/column/column_device_view_base.cuh>
#include <cudf/types.hpp>

#include <cuda/std/cstddef>
#include <cuda/std/optional>

#include <cudf/detail/jit/span.cuh>

#include <cstddef>

namespace cudf {
namespace jit {

template <typename T, int32_t Index>
struct column_accessor {
  using type                     = T;
  static constexpr int32_t index = Index;

  template <typename ColumnView>
  static __device__ decltype(auto) element(ColumnView const* columns, cudf::size_type row)
  {
    return columns[index].template element<T>(row);
  }

  static __device__ void assign(cudf::mutable_column_device_view_core const* outputs,
                                cudf::size_type row,
                                T value)
  {
    outputs[index].assign<T>(row, value);
  }

  template <typename ColumnView>
  static __device__ bool is_null(ColumnView const* inputs, cudf::size_type row)
  {
    return inputs[index].is_null(row);
  }

  template <typename ColumnView>
  static __device__ cuda::std::optional<T> nullable_element(ColumnView const* columns,
                                                            cudf::size_type row)
  {
    if (is_null(columns, row)) { return cuda::std::nullopt; }
    return columns[index].template element<T>(row);
  }
};

template <typename T, int32_t Index>
struct span_accessor {
  using type                     = T;
  static constexpr int32_t index = Index;

  static __device__ type& element(cudf::jit::device_optional_span<T> const* spans,
                                  cudf::size_type row)
  {
    return spans[index][row];
  }

  static __device__ void assign(cudf::jit::device_optional_span<T> const* outputs,
                                cudf::size_type row,
                                T value)
  {
    outputs[index][row] = value;
  }

  static __device__ bool is_null(cudf::jit::device_optional_span<T> const* inputs,
                                 cudf::size_type row)
  {
    return inputs[index].is_null(row);
  }

  static __device__ cuda::std::optional<T> nullable_element(
    cudf::jit::device_optional_span<T> const* outputs, cudf::size_type row)
  {
    if (is_null(outputs, row)) { return cuda::std::nullopt; }
    return outputs[index].element(row);
  }
};

template <typename Accessor>
struct scalar_accessor {
  using type                     = typename Accessor::type;
  static constexpr int32_t index = Accessor::index;

  template <typename ColumnView>
  static __device__ decltype(auto) element(ColumnView const* columns, cudf::size_type)
  {
    return Accessor::element(columns, 0);
  }

  static __device__ void assign(cudf::mutable_column_device_view_core const* outputs,
                                cudf::size_type,
                                type value)
  {
    return Accessor::assign(outputs, 0, value);
  }

  template <typename ColumnView>
  static __device__ bool is_null(ColumnView const* columns, cudf::size_type)
  {
    return Accessor::is_null(columns, 0);
  }

  template <typename ColumnView>
  static __device__ decltype(auto) nullable_element(ColumnView const* columns, cudf::size_type)
  {
    return Accessor::nullable_element(columns, 0);
  }
};

}  // namespace jit
}  // namespace cudf
