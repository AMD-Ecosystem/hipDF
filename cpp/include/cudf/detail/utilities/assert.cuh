/*
 * Copyright (c) 2019-2023, NVIDIA CORPORATION.
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

/**
 * @brief `assert`-like macro for device code
 *
 * This is effectively the same as the standard `assert` macro, except it
 * relies on the `__PRETTY_FUNCTION__` macro which is specific to GCC and Clang
 * to produce better assert messages.
 */
// NOTE(HIP/AMD): Also check for __HIP_DEVICE_COMPILE__ for HIP device code
#if !defined(NDEBUG) && (defined(__CUDA_ARCH__) || defined(__HIP_DEVICE_COMPILE__)) && (defined(__clang__) || defined(__GNUC__))
#define __ASSERT_STR_HELPER(x) #x
#define cudf_assert(e)        \
  ((e) ? static_cast<void>(0) \
       : __assert_fail(__ASSERT_STR_HELPER(e), __FILE__, __LINE__, __PRETTY_FUNCTION__))
#else
#define cudf_assert(e) (static_cast<void>(0))
#endif

/**
 * @brief Macro indicating that a location in the code is unreachable.
 *
 * The CUDF_UNREACHABLE macro should only be used where CUDF_FAIL cannot be used
 * due to performance or due to being used in device code. In the majority of
 * host code situations, an exception should be thrown in "unreachable" code
 * paths as those usually aren't tight inner loops like they are in device code.
 *
 * One example where this macro may be used is in conjunction with dispatchers
 * to indicate that a function does not need to return a default value because
 * it has already exhausted all possible cases in a `switch` statement.
 *
 * The assert in this macro can be used when compiling in debug mode to help
 * debug functions that may reach the supposedly unreachable code.
 *
 * Example usage:
 * ```
 * CUDF_UNREACHABLE("Invalid type_id.");
 * ```
 */
#define CUDF_UNREACHABLE(msg)             \
  do {                                    \
    assert(false && "Unreachable: " msg); \
    __builtin_unreachable();              \
  } while (0)
