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

#include "cudf/cuda_runtime.h"

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/cudf_gtest.hpp>
#include <cudf_test/type_list_utilities.hpp>
#include <cudf_test/type_lists.hpp>

#include <cudf/detail/utilities/vector_factories.hpp>
#include <cudf/scalar/scalar.hpp>
#include <cudf/scalar/scalar_device_view.cuh>
#include <cudf/strings/string_view.cuh>
#include <cudf/types.hpp>
#include <cudf/utilities/default_stream.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <thrust/sequence.h>

#include <random>

template <typename T>
struct TypedScalarDeviceViewTest : public cudf::test::BaseFixture {};

TYPED_TEST_SUITE(TypedScalarDeviceViewTest, cudf::test::FixedWidthTypesWithoutFixedPoint);

template <typename ScalarDeviceViewType>
CUDF_KERNEL void test_set_value(ScalarDeviceViewType s, ScalarDeviceViewType s1)
{
  s1.set_value(s.value());
  s1.set_valid(true);
}

template <typename ScalarDeviceViewType>
CUDF_KERNEL void test_value(ScalarDeviceViewType s, ScalarDeviceViewType s1, bool* result)
{
  *result = (s.value() == s1.value());
}

TYPED_TEST(TypedScalarDeviceViewTest, Value)
{
  TypeParam value  = cudf::test::make_type_param_scalar<TypeParam>(7);
  TypeParam value1 = cudf::test::make_type_param_scalar<TypeParam>(11);
  cudf::scalar_type_t<TypeParam> s(value);
  cudf::scalar_type_t<TypeParam> s1{value1};

  auto scalar_device_view  = cudf::get_scalar_device_view(s);
  auto scalar_device_view1 = cudf::get_scalar_device_view(s1);
  rmm::device_scalar<bool> result{cudf::get_default_stream()};

  test_set_value<<<1, 1, 0, cudf::get_default_stream().value()>>>(scalar_device_view,
                                                                  scalar_device_view1);
  CUDF_CHECK_CUDA(0);

  EXPECT_EQ(s1.value(), value);
  EXPECT_TRUE(s1.is_valid());

  test_value<<<1, 1, 0, cudf::get_default_stream().value()>>>(
    scalar_device_view, scalar_device_view1, result.data());
  CUDF_CHECK_CUDA(0);

  EXPECT_TRUE(result.value(cudf::get_default_stream()));
}

template <typename ScalarDeviceViewType>
CUDF_KERNEL void test_null(ScalarDeviceViewType s, bool* result)
{
  *result = s.is_valid();
}

TYPED_TEST(TypedScalarDeviceViewTest, ConstructNull)
{
  TypeParam value = cudf::test::make_type_param_scalar<TypeParam>(5);
  cudf::scalar_type_t<TypeParam> s(value, false);
  auto scalar_device_view = cudf::get_scalar_device_view(s);
  rmm::device_scalar<bool> result{cudf::get_default_stream()};

  test_null<<<1, 1, 0, cudf::get_default_stream().value()>>>(scalar_device_view, result.data());
  CUDF_CHECK_CUDA(0);

  EXPECT_FALSE(result.value(cudf::get_default_stream()));
}

template <typename ScalarDeviceViewType>
CUDF_KERNEL void test_setnull(ScalarDeviceViewType s)
{
  s.set_valid(false);
}

TYPED_TEST(TypedScalarDeviceViewTest, SetNull)
{
  TypeParam value = cudf::test::make_type_param_scalar<TypeParam>(5);
  cudf::scalar_type_t<TypeParam> s{value};
  auto scalar_device_view = cudf::get_scalar_device_view(s);
  s.set_valid_async(true);
  EXPECT_TRUE(s.is_valid());

  test_setnull<<<1, 1, 0, cudf::get_default_stream().value()>>>(scalar_device_view);
  CUDF_CHECK_CUDA(0);

  EXPECT_FALSE(s.is_valid());
}

struct StringScalarDeviceViewTest : public cudf::test::BaseFixture {};

CUDF_KERNEL void test_string_value(cudf::string_scalar_device_view s,
                                   char const* value,
                                   cudf::size_type size,
                                   bool* result)
{
  *result = (s.value() == cudf::string_view(value, size));
}

TEST_F(StringScalarDeviceViewTest, Value)
{
  std::string value("test string");
  cudf::string_scalar s(value);

  auto scalar_device_view = cudf::get_scalar_device_view(s);
  rmm::device_scalar<bool> result{cudf::get_default_stream()};
  auto value_v = cudf::detail::make_device_uvector(
    value, cudf::get_default_stream(), cudf::get_current_device_resource_ref());

  test_string_value<<<1, 1, 0, cudf::get_default_stream().value()>>>(
    scalar_device_view, value_v.data(), value.size(), result.data());
  CUDF_CHECK_CUDA(0);

  EXPECT_TRUE(result.value(cudf::get_default_stream()));
}
