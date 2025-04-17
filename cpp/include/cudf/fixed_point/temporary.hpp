/*
 * Copyright (c) 2021-2025, NVIDIA CORPORATION.
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
#include <cudf/cuda_runtime.h>

#include <cudf/types.hpp>

#include <cuda/std/limits>
#include <cuda/std/type_traits>

// NOTE(AMD/HIP): Redefinition error
#ifndef __HIPCC_RTC__
#include <algorithm>
#include <string>
#endif

namespace CUDF_EXPORT numeric {
namespace detail {
// NOTE(AMD/HIP): Redefinition error (issue 304).
#ifndef __HIPCC_RTC__
template <typename T>
auto to_string(T value) -> std::string
{
  if constexpr (cuda::std::is_same_v<T, __int128_t>) {
    auto s          = std::string{};
    auto const sign = value < 0;
    if (sign) {
      value += 1;  // avoid overflowing if value == _int128_t lowest
      value *= -1;
      if (value == cuda::std::numeric_limits<__int128_t>::max())
        return "-170141183460469231731687303715884105728";
      value += 1;  // can add back the one, no need to avoid overflow anymore
    }
    do {
      s.push_back("0123456789"[value % 10]);
      value /= 10;
    } while (value);
    if (sign) s.push_back('-');
    std::reverse(s.begin(), s.end());
    return s;
  } else {
    return std::to_string(value);
  }
  return std::string{};  // won't ever hit here, need to suppress warning though
}
#endif

template <typename T>
CUDF_HOST_DEVICE constexpr auto abs(T value)
{
  return value >= 0 ? value : -value;
}

template <typename T>
CUDF_HOST_DEVICE inline auto min(T lhs, T rhs)
{
  return lhs < rhs ? lhs : rhs;
}

template <typename T>
CUDF_HOST_DEVICE inline auto max(T lhs, T rhs)
{
  return lhs > rhs ? lhs : rhs;
}

template <typename BaseType>
CUDF_HOST_DEVICE constexpr auto exp10(int32_t exponent)
{
  BaseType value = 1;
  while (exponent > 0)
    value *= 10, --exponent;
  return value;
}

}  // namespace detail
}  // namespace CUDF_EXPORT numeric
