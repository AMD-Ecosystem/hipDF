/*
 * SPDX-FileCopyrightText: Copyright 2018-2019 BlazingDB, Inc.
 * SPDX-FileCopyrightText: Copyright 2018 Christian Noboa Mardini <christian@blazingdb.com>
 * SPDX-FileCopyrightText: Copyright (c) 2019-2025, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */
/*
 * Copyright 2018-2019 BlazingDB, Inc.
 *     Copyright 2018 Christian Noboa Mardini <christian@blazingdb.com>
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

#include <cudf_test/column_utilities.hpp>
#include <cudf_test/cudf_gtest.hpp>

#include <cudf/scalar/scalar.hpp>
#include <cudf/utilities/traits.hpp>

#include <limits>

// This is used to convert the expected binop result computed by the test utilities and the
// result returned by the binop operation into string, which is then used for display purposes
// when the values do not match.
struct stringify_out_values {
  template <typename TypeOut>
  std::string operator()(cudf::size_type i, TypeOut lhs, TypeOut rhs) const
  {
    std::stringstream out_str;
    out_str << "[" << i << "]:\n";
    if constexpr (cudf::is_fixed_point<TypeOut>()) {
      out_str << "lhs: " << std::string(lhs) << "\nrhs: " << std::string(rhs);
    } else if constexpr (cudf::is_timestamp<TypeOut>()) {
      out_str << "lhs: " << lhs.time_since_epoch().count()
              << "\nrhs: " << rhs.time_since_epoch().count();
    } else if constexpr (cudf::is_duration<TypeOut>()) {
      out_str << "lhs: " << lhs.count() << "\nrhs: " << rhs.count();
    } else {
      out_str << "lhs: " << lhs << "\nrhs: " << rhs;
    }
    return out_str.str();
  }
};

// This comparator can be used to compare two values that are within a max ULP error.
// This is typically used to compare floating point values computed on CPU and GPU which is
// expected to be *near* equal, or when computing large numbers can yield ULP errors
//
// TODO: This should not be used in favor of the built-in one in column_utilities
template <typename TypeOut>
struct NearEqualComparator {
  double ulp_;

  NearEqualComparator(double ulp) : ulp_(ulp) {}

  bool operator()(TypeOut const& lhs, TypeOut const& rhs) const
  {
    return (std::fabs(lhs - rhs) <=
              std::numeric_limits<TypeOut>::epsilon() * std::fabs(lhs + rhs) * ulp_ ||
            std::fabs(lhs - rhs) < std::numeric_limits<TypeOut>::min());
  }
};

template <typename TypeLhs, typename ScalarType>
TypeLhs scalar_host_value(cudf::scalar const& lhs)
{
  auto sclr   = static_cast<ScalarType const&>(lhs);
  auto stream = cudf::get_default_stream();
  if constexpr (std::is_same_v<ScalarType, cudf::string_scalar>) {
    return sclr.to_string(stream);
  } else if constexpr (std::is_same_v<ScalarType, cudf::fixed_point_scalar<TypeLhs>>) {
    return sclr.fixed_point_value(stream);
  } else {
    return sclr.value(stream);
  }
}

template <typename TypeOut,
          typename TypeLhs,
          typename TypeRhs,
          typename TypeOp,
          typename ValueComparator = std::equal_to<TypeOut>,
          typename ScalarType      = cudf::scalar_type_t<TypeLhs>>
void ASSERT_BINOP(cudf::column_view const& out,
                  cudf::scalar const& lhs,
                  cudf::column_view const& rhs,
                  TypeOp&& op,
                  ValueComparator const& value_comparator = ValueComparator())
{
  auto lhs_h    = scalar_host_value<TypeLhs, ScalarType>(lhs);
  auto rhs_h    = cudf::test::to_host<TypeRhs>(rhs);
  auto rhs_data = rhs_h.first;
  auto out_h    = cudf::test::to_host<TypeOut>(out);
  auto out_data = out_h.first;

  ASSERT_EQ(out_data.size(), rhs_data.size());
  for (size_t i = 0; i < out_data.size(); ++i) {
    auto lhs = out_data[i];
    auto rhs = (TypeOut)(op(lhs_h, rhs_data[i]));
    // TODO: This is incorrectly comparing row values that may be null
    EXPECT_TRUE(value_comparator(lhs, rhs)) << stringify_out_values{}(i, lhs, rhs);
  }

  if (rhs.nullable()) {
    EXPECT_TRUE(out.nullable());
    auto rhs_valid = rhs_h.second;
    auto out_valid = out_h.second;

    cudf::bitmask_type lhs_valid = (lhs.is_valid() ? std::numeric_limits<cudf::bitmask_type>::max() : 0);
    ASSERT_EQ(out_valid.size(), rhs_valid.size());
    for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
      EXPECT_EQ(out_valid[i], (lhs_valid & rhs_valid[i]));
    }
  } else {
    if (lhs.is_valid()) {
      EXPECT_FALSE(out.nullable());
    } else {
      auto out_valid = out_h.second;
      for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
        EXPECT_EQ(out_valid[i], cudf::bitmask_type{0});
      }
    }
  }
}

template <typename TypeOut,
          typename TypeLhs,
          typename TypeRhs,
          typename TypeOp,
          typename ValueComparator = std::equal_to<TypeOut>,
          typename ScalarType      = cudf::scalar_type_t<TypeRhs>>
void ASSERT_BINOP(cudf::column_view const& out,
                  cudf::column_view const& lhs,
                  cudf::scalar const& rhs,
                  TypeOp&& op,
                  ValueComparator const& value_comparator = ValueComparator())
{
  auto rhs_h    = scalar_host_value<TypeRhs, ScalarType>(rhs);
  auto lhs_h    = cudf::test::to_host<TypeLhs>(lhs);
  auto lhs_data = lhs_h.first;
  auto out_h    = cudf::test::to_host<TypeOut>(out);
  auto out_data = out_h.first;

  ASSERT_EQ(out_data.size(), lhs_data.size());
  for (size_t i = 0; i < out_data.size(); ++i) {
    auto lhs = out_data[i];
    auto rhs = (TypeOut)(op(lhs_data[i], rhs_h));
    // TODO: This is incorrectly comparing row values that may be null
    EXPECT_TRUE(value_comparator(lhs, rhs)) << stringify_out_values{}(i, lhs, rhs);
  }

  if (lhs.nullable()) {
    EXPECT_TRUE(out.nullable());
    auto lhs_valid = lhs_h.second;
    auto out_valid = out_h.second;

    cudf::bitmask_type rhs_valid = (rhs.is_valid() ? std::numeric_limits<cudf::bitmask_type>::max() : 0);
    ASSERT_EQ(out_valid.size(), lhs_valid.size());
    for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
      EXPECT_EQ(out_valid[i], (rhs_valid & lhs_valid[i]));
    }
  } else {
    if (rhs.is_valid()) {
      EXPECT_FALSE(out.nullable());
    } else {
      auto out_valid = out_h.second;
      for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
        EXPECT_EQ(out_valid[i], cudf::bitmask_type{0});
      }
    }
  }
}

template <typename TypeOut,
          typename TypeLhs,
          typename TypeRhs,
          typename TypeOp,
          typename ValueComparator = std::equal_to<TypeOut>>
void ASSERT_BINOP(cudf::column_view const& out,
                  cudf::column_view const& lhs,
                  cudf::column_view const& rhs,
                  TypeOp&& op,
                  ValueComparator const& value_comparator = ValueComparator())
{
  auto lhs_h    = cudf::test::to_host<TypeLhs>(lhs);
  auto lhs_data = lhs_h.first;
  auto rhs_h    = cudf::test::to_host<TypeRhs>(rhs);
  auto rhs_data = rhs_h.first;
  auto out_h    = cudf::test::to_host<TypeOut>(out);
  auto out_data = out_h.first;

  ASSERT_EQ(out_data.size(), lhs_data.size());
  ASSERT_EQ(out_data.size(), rhs_data.size());
  for (size_t i = 0; i < out_data.size(); ++i) {
    auto lhs = out_data[i];
    auto rhs = (TypeOut)(op(lhs_data[i], rhs_data[i]));
    // TODO: This is incorrectly comparing row values that may be null
    EXPECT_TRUE(value_comparator(lhs, rhs)) << stringify_out_values{}(i, lhs, rhs);
  }

  if (lhs.nullable() and rhs.nullable()) {
    EXPECT_TRUE(out.nullable());
    auto lhs_valid = lhs_h.second;
    auto rhs_valid = rhs_h.second;
    auto out_valid = out_h.second;

    ASSERT_EQ(out_valid.size(), lhs_valid.size());
    ASSERT_EQ(out_valid.size(), rhs_valid.size());
    for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
      EXPECT_EQ(out_valid[i], (lhs_valid[i] & rhs_valid[i]));
    }
  } else if (not lhs.nullable() and rhs.nullable()) {
    EXPECT_TRUE(out.nullable());
    auto rhs_valid = rhs_h.second;
    auto out_valid = out_h.second;

    ASSERT_EQ(out_valid.size(), rhs_valid.size());
    for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
      EXPECT_EQ(out_valid[i], rhs_valid[i]);
    }
  } else if (lhs.nullable() and not rhs.nullable()) {
    EXPECT_TRUE(out.nullable());
    auto lhs_valid = lhs_h.second;
    auto out_valid = out_h.second;

    ASSERT_EQ(out_valid.size(), lhs_valid.size());
    for (cudf::size_type i = 0; i < cudf::num_bitmask_words(out_data.size()); ++i) {
      EXPECT_EQ(out_valid[i], lhs_valid[i]);
    }
  } else {
    EXPECT_FALSE(out.nullable());
  }
}
