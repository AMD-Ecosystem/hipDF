/*
 * SPDX-FileCopyrightText: Copyright (c) 2024-2026, NVIDIA CORPORATION.
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

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/cudf_gtest.hpp>
#include <cudf_test/type_lists.hpp>

#include <cudf/detail/utilities/batched_memset.hpp>
#include <cudf/detail/utilities/vector_factories.hpp>
#include <cudf/io/parquet.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/span.hpp>

#include <rmm/device_uvector.hpp>

#include <cuda/std/tuple>
#include <thrust/iterator/transform_iterator.h>
#include <thrust/iterator/zip_iterator.h>
// NOTE(HIP/AMD): thrust::make_zip_iterator dereferences to a thrust::tuple (rocThrust),
// so the zip-element accessors below use thrust::get instead of cuda::std::get (which
// finds no matching overload for thrust::tuple). thrust::get also works on CCCL's
// thrust::tuple, so this is portable.
#include <thrust/tuple.h>

#include <type_traits>

template <typename T>
struct MultiBufferTestIntegral : public cudf::test::BaseFixture {};

TEST(MultiBufferTestIntegral, BasicTest1)
{
  std::vector<size_t> const buffer_sizes{
    50000, 4, 1000, 0, 250000, 1, 100, 8000, 0, 1, 100, 1000, 10000, 100000, 0, 1, 100000};

  // Device init
  auto stream = cudf::get_default_stream();
  auto mr     = cudf::get_current_device_resource_ref();

  // Creating base vector for data and setting it to all 0xFF
  std::vector<std::vector<uint64_t>> expected;
  std::transform(
    buffer_sizes.begin(), buffer_sizes.end(), std::back_inserter(expected), [](auto size) {
      return std::vector<uint64_t>(size + 2000, std::numeric_limits<uint64_t>::max());
    });

  // set buffer region to other value
  std::for_each(
    thrust::make_zip_iterator(expected.begin(), buffer_sizes.begin()),
    thrust::make_zip_iterator(expected.end(), buffer_sizes.end()),
    [](auto elem) {
      std::fill_n(
        thrust::get<0>(elem).begin() + 1000, thrust::get<1>(elem), 0xEEEEEEEEEEEEEEEE);
    });

  // Copy host vector data to device
  std::vector<rmm::device_uvector<uint64_t>> device_buffers;
  std::transform(expected.begin(),
                 expected.end(),
                 std::back_inserter(device_buffers),
                 [stream, mr](auto const& vec) {
                   return cudf::detail::make_device_uvector_async(vec, stream, mr);
                 });

  // Initialize device buffers for memset
  auto buffers =
    cudf::detail::make_host_vector<cudf::device_span<uint64_t>>(device_buffers.size(), stream);
  std::transform(
    thrust::make_zip_iterator(device_buffers.begin(), buffer_sizes.begin()),
    thrust::make_zip_iterator(device_buffers.end(), buffer_sizes.end()),
    buffers.begin(),
    [](auto const& elem) {
      return cudf::device_span<uint64_t>(thrust::get<0>(elem).data() + 1000,
                                         thrust::get<1>(elem));
    });

  // Function call
  cudf::detail::batched_memset<uint64_t>(buffers, uint64_t{0}, stream);

  // Set all buffer regions to 0 for expected comparison
  std::for_each(
    thrust::make_zip_iterator(expected.begin(), buffer_sizes.begin()),
    thrust::make_zip_iterator(expected.end(), buffer_sizes.end()),
    [](auto elem) {
      std::fill_n(thrust::get<0>(elem).begin() + 1000, thrust::get<1>(elem), 0UL);
    });

  // Compare to see that only given buffers are zeroed out
  std::for_each(
    thrust::make_zip_iterator(device_buffers.begin(), expected.begin()),
    thrust::make_zip_iterator(device_buffers.end(), expected.end()),
    [stream](auto const& elem) {
      auto const after_memset = cudf::detail::make_host_vector(thrust::get<0>(elem), stream);
      EXPECT_TRUE(std::equal(
        thrust::get<1>(elem).begin(), thrust::get<1>(elem).end(), after_memset.begin()));
    });
}
