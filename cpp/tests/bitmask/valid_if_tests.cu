/*
 * SPDX-FileCopyrightText: Copyright (c) 2019-2026, NVIDIA CORPORATION.
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

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/column_utilities.hpp>
#include <cudf_test/column_wrapper.hpp>
#include <cudf_test/cudf_gtest.hpp>

#include <cudf/detail/iterator.cuh>
#include <cudf/detail/valid_if.cuh>
#include <cudf/types.hpp>
#include <cudf/utilities/memory_resource.hpp>

#include <cuda/iterator>

struct ValidIfTest : public cudf::test::BaseFixture {};

namespace {
struct odds_valid {
  __host__ __device__ bool operator()(cudf::size_type i) { return i % 2; }
};
struct all_valid {
  __host__ __device__ bool operator()(cudf::size_type i) { return true; }
};
struct all_null {
  __host__ __device__ bool operator()(cudf::size_type i) { return false; }
};
}  // namespace

TEST_F(ValidIfTest, EmptyRange)
{
  auto actual        = cudf::detail::valid_if(cuda::counting_iterator<cudf::size_type>{0},
                                       cuda::counting_iterator<cudf::size_type>{0},
                                       odds_valid{},
                                       cudf::get_default_stream(),
                                       cudf::get_current_device_resource_ref());
  auto const& buffer = actual.first;
  EXPECT_EQ(0u, buffer.size());
  EXPECT_EQ(nullptr, buffer.data());
  EXPECT_EQ(0, actual.second);
}

TEST_F(ValidIfTest, InvalidRange)
{
  EXPECT_THROW(cudf::detail::valid_if(cuda::counting_iterator<cudf::size_type>{1},
                                      cuda::counting_iterator<cudf::size_type>{0},
                                      odds_valid{},
                                      cudf::get_default_stream(),
                                      cudf::get_current_device_resource_ref()),
               cudf::logic_error);
}
// NOTE(HIP/AMD): This test has been modified to avoid using memset to zeros
TEST_F(ValidIfTest, OddsValid)
{
  auto iter     = cudf::detail::make_counting_transform_iterator(0, odds_valid{});
// <<<<<<< OLD CODE from 8414047bb1 (4b19041ca0) - COMMENTED OUT
//   auto expected = cudf::test::detail::make_null_mask(iter, iter + 10240);
//   auto actual   = cudf::detail::valid_if(thrust::make_counting_iterator(0),
//                                        thrust::make_counting_iterator(10240),
// =======
  auto expected = cudf::test::detail::make_null_mask(iter, iter + 10000);
  auto actual   = cudf::detail::valid_if(cuda::counting_iterator<cudf::size_type>{0},
                                       cuda::counting_iterator<cudf::size_type>{10000},
// >>>>>>> END NEW CODE (4b19041ca0)
                                       odds_valid{},
                                       cudf::get_default_stream(),
                                       cudf::get_current_device_resource_ref());
  CUDF_TEST_EXPECT_EQUAL_BUFFERS(expected.first.data(), actual.first.data(), expected.first.size());
  EXPECT_EQ(5120, actual.second);
  EXPECT_EQ(expected.second, actual.second);
}
// NOTE(HIP/AMD): This test has been modified to avoid using memset to zeors
TEST_F(ValidIfTest, AllValid)
{
  auto iter     = cudf::detail::make_counting_transform_iterator(0, all_valid{});
// <<<<<<< OLD CODE from 8414047bb1 (4b19041ca0) - COMMENTED OUT
//   auto expected = cudf::test::detail::make_null_mask(iter, iter + 10240);
//   auto actual   = cudf::detail::valid_if(thrust::make_counting_iterator(0),
//                                        thrust::make_counting_iterator(10240),
// =======
  auto expected = cudf::test::detail::make_null_mask(iter, iter + 10000);
  auto actual   = cudf::detail::valid_if(cuda::counting_iterator<cudf::size_type>{0},
                                       cuda::counting_iterator<cudf::size_type>{10000},
// >>>>>>> END NEW CODE (4b19041ca0)
                                       all_valid{},
                                       cudf::get_default_stream(),
                                       cudf::get_current_device_resource_ref());
  CUDF_TEST_EXPECT_EQUAL_BUFFERS(expected.first.data(), actual.first.data(), expected.first.size());
  EXPECT_EQ(0, actual.second);
  EXPECT_EQ(expected.second, actual.second);
}
// NOTE(HIP/AMD): This test has been modified to avoid using memset to zeors
TEST_F(ValidIfTest, AllNull)
{
  auto iter     = cudf::detail::make_counting_transform_iterator(0, all_null{});
// <<<<<<< OLD CODE from 8414047bb1 (4b19041ca0) - COMMENTED OUT
//   auto expected = cudf::test::detail::make_null_mask(iter, iter + 10240);
//   auto actual   = cudf::detail::valid_if(thrust::make_counting_iterator(0),
//                                        thrust::make_counting_iterator(10240),
// =======
  auto expected = cudf::test::detail::make_null_mask(iter, iter + 10000);
  auto actual   = cudf::detail::valid_if(cuda::counting_iterator<cudf::size_type>{0},
                                       cuda::counting_iterator<cudf::size_type>{10000},
// >>>>>>> END NEW CODE (4b19041ca0)
                                       all_null{},
                                       cudf::get_default_stream(),
                                       cudf::get_current_device_resource_ref());
  CUDF_TEST_EXPECT_EQUAL_BUFFERS(expected.first.data(), actual.first.data(), expected.first.size());
  EXPECT_EQ(10240, actual.second);
  EXPECT_EQ(expected.second, actual.second);
}
