/*
 * Copyright (c) 2023-2025, NVIDIA CORPORATION.
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
// Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

/**
 * @brief A casting functor wrapping another functor.
 * @file
 */

#include <cudf/types.hpp>

#include <cuda/functional>

#include <type_traits>
#include <utility>

namespace cudf {
namespace detail {

/**
 * @brief Functor that casts a primitive input value to a specified type
 */
template <typename T>
struct cast_fn {
  template <typename U>
  CUDF_HOST_DEVICE constexpr T operator()(U&& val) const
  {
    return static_cast<T>(cuda::std::forward<U>(val));
  }

  CUDF_HOST_DEVICE constexpr T&& operator()(T&& val) const noexcept
  {
    return cuda::std::forward<T>(val);
  }
};

/**
 * @brief Functor that casts another functor's result to a specified type.
 *
 * CUB 2.0.0 reductions require that the binary operator returns the same type
 * as the initial value type, so we wrap binary operators with this when used
 * by CUB.
 */
template <typename ResultType, typename F>
struct cast_functor_fn {
  F f;

  template <typename... Ts>
  CUDF_HOST_DEVICE inline ResultType operator()(Ts&&... args) const
  {
    return static_cast<ResultType>(f(std::forward<Ts>(args)...));
  }
};

/**
 * @brief Function creating a casting functor.
 */
template <typename ResultType, typename F>
inline cast_functor_fn<ResultType, std::decay_t<F>> cast_functor(F&& f)
{
  return cast_functor_fn<ResultType, std::decay_t<F>>{std::forward<F>(f)};
}

}  // namespace detail

}  // namespace cudf
