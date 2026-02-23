/*
 * Copyright (c) 2019-2025, NVIDIA CORPORATION.
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

#include <rolling/jit/operation-udf.hpp>

struct rolling_udf_ptx {
  template <typename OutType, typename InType>
  __device__ static OutType operate(InType const* in_col, cudf::size_type start, cudf::size_type count)
  {
    OutType ret;
    rolling_udf(&ret, nullptr, nullptr, 0, 0, &in_col[start], count, sizeof(InType)); // NOTE(HIP/AMD): Changed from 0 to nullptr for second & third arguments.
                                                                                      // In fact, this is what both CUDA's Numba as well as HIP's NUMBA expect.
    return ret;
  }
};

struct rolling_udf_cuda {
  template <typename OutType, typename InType>
  __device__ static OutType operate(InType const* in_col, cudf::size_type start, cudf::size_type count)
  {
    OutType ret;
    rolling_udf(&ret, in_col, start, count);
    return ret;
  }
};
