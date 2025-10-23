/*
 * SPDX-FileCopyrightText: Copyright (c) 2020-2023, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */
// MIT License
//
// Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

#include <cudf/types.hpp>

namespace cudf {

namespace detail {

template <class T>
__device__ T minimum(T a, T b)
{
  return b < a ? b : a;
}

struct preceding_window_wrapper {
  cudf::size_type const* d_group_offsets;
  cudf::size_type const* d_group_labels;
  cudf::size_type preceding_window;

  __device__ cudf::size_type operator[](cudf::size_type idx)
  {
    auto group_label = d_group_labels[idx];
    auto group_start = d_group_offsets[group_label];
    return minimum(preceding_window, idx - group_start + 1);  // Preceding includes current row.
  }
};

struct following_window_wrapper {
  cudf::size_type const* d_group_offsets;
  cudf::size_type const* d_group_labels;
  cudf::size_type following_window;

  __device__ cudf::size_type operator[](cudf::size_type idx)
  {
    auto group_label = d_group_labels[idx];
    auto group_end =
      d_group_offsets[group_label +
                      1];  // Cannot fall off the end, since offsets is capped with `input.size()`.
    return minimum(following_window, (group_end - 1) - idx);
  }
};

}  // namespace detail

}  // namespace cudf
