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

#include <cudf_test/column_utilities.hpp>
#include <cudf_test/column_wrapper.hpp>
#include <cudf_test/cudf_gtest.hpp>

#include <cuda/std/tuple>
#include <thrust/iterator/zip_iterator.h>

#include <algorithm>

// NOTE(HIP/AMD): cuda::std::tuple is not compatible with rocthrust from ROCm 7.2.x and lower
// as it doesn't provide iterator traits
// required by thrust::zip_iterator, causing compilation errors. Use thrust::make_tuple for compatibility.
#if defined(__HIP_PLATFORM_AMD__) && defined(HIP_VERSION_MAJOR) && \
    ((HIP_VERSION_MAJOR < 7) || (HIP_VERSION_MAJOR == 7 && HIP_VERSION_MINOR <= 12))
#define MAKE_TUPLE thrust::make_tuple
#else
#define MAKE_TUPLE cuda::std::make_tuple
#endif

namespace transformation {
template <typename TypeOut, typename TypeIn, typename TypeOpe>
void ASSERT_UNARY(cudf::column_view const& out, cudf::column_view const& in, TypeOpe&& ope)
{
  auto in_h     = cudf::test::to_host<TypeIn>(in);
  auto in_data  = in_h.first;
  auto out_h    = cudf::test::to_host<TypeOut>(out);
  auto out_data = out_h.first;

  ASSERT_TRUE(out_data.size() == in_data.size());

  auto begin = thrust::make_zip_iterator(MAKE_TUPLE(in_data.begin(), out_data.begin()));
  auto end   = thrust::make_zip_iterator(MAKE_TUPLE(in_data.end(), out_data.end()));

  std::for_each(begin, end, [ope](auto const& zipped) {
    auto [in_val, out_val] = zipped;
    EXPECT_EQ(out_val, static_cast<TypeOut>(ope(in_val)));
  });

  auto in_valid  = in_h.second;
  auto out_valid = out_h.second;

  ASSERT_TRUE(out_valid.size() == in_valid.size());

  auto valid_begin =
    thrust::make_zip_iterator(MAKE_TUPLE(in_valid.begin(), out_valid.begin()));
  auto valid_end =
    thrust::make_zip_iterator(MAKE_TUPLE(in_valid.end(), out_valid.end()));

  std::for_each(valid_begin, valid_end, [](auto const& zipped) {
    auto [in_flag, out_flag] = zipped;
    EXPECT_EQ(out_flag, in_flag);
  });
}

}  // namespace transformation
