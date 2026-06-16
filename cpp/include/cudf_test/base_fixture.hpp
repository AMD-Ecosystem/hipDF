/*
 * SPDX-FileCopyrightText: Copyright (c) 2020-2026, NVIDIA CORPORATION.
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

#pragma once

#include <cudf_test/cudf_gtest.hpp>
#include <cudf_test/file_utilities.hpp>

#include <cudf/utilities/export.hpp>
#include <cudf/utilities/memory_resource.hpp>
#include <cudf/utilities/traits.hpp>

#include <rmm/resource_ref.hpp>

#include <cuda/memory_resource>

// TODO(HIP/AMD): Workaround for the libhipcxx cuda::std::swap vs thrust::swap ADL
// ambiguity (libhipcxx 3.3.4). thrust::detail::contiguous_storage::swap on host vectors
// of cuda::std::chrono types (time_point/duration), used pervasively by the column
// wrappers below, finds both cuda::std::swap and thrust::swap and cannot disambiguate.
// Mirrors the same WAR in cpp/src/datetime/timezone.cpp; injecting std::swap into
// namespace thrust forces it to be preferred for these host containers. Placed in this
// widely-included test base header so it covers every gtest TU that uses chrono columns.
#if defined(__HIP_PLATFORM_AMD__)
#include <utility>
namespace thrust {
using std::swap;
}
#endif

namespace CUDF_EXPORT cudf {
namespace test {

/**
 * @brief Base test fixture class from which all libcudf tests should inherit.
 *
 * Example:
 * ```
 * class MyTestFixture : public cudf::test::BaseFixture {};
 * ```
 */
class BaseFixture : public ::testing::Test {
  cuda::mr::any_resource<cuda::mr::device_accessible> _mr{cudf::get_current_device_resource_ref()};

 public:
  /**
   * @brief Returns reference to `device_async_resource_ref` that should be used for
   * all tests inheriting from this fixture
   * @return reference to memory resource
   */
  rmm::device_async_resource_ref mr() { return _mr; }
};

/**
 * @brief Base test fixture that takes a parameter.
 *
 * Example:
 * ```
 * class MyIntTestFixture : public cudf::test::BaseFixtureWithParam<int> {};
 * ```
 */
template <typename T>
class BaseFixtureWithParam : public ::testing::TestWithParam<T> {
  cuda::mr::any_resource<cuda::mr::device_accessible> _mr{cudf::get_current_device_resource_ref()};

 public:
  /**
   * @brief Returns reference to `device_async_resource_ref` that should be used for
   * all tests inheriting from this fixture
   * @return reference to memory resource
   */
  [[nodiscard]] rmm::device_async_resource_ref mr() { return _mr; }
};

/**
 * @brief Provides temporary directory for temporary test files.
 *
 * Example:
 * ```c++
 * ::testing::Environment* const temp_env =
 *    ::testing::AddGlobalTestEnvironment(new TempDirTestEnvironment);
 * ```
 */
class TempDirTestEnvironment : public ::testing::Environment {
  temp_directory const tmpdir{"gtest"};

 public:
  /**
   * @brief Get directory path to use for temporary files
   *
   * @return std::string The temporary directory path
   */
  std::string get_temp_dir() { return tmpdir.path(); }

  /**
   * @brief Get a temporary filepath to use for the specified filename
   *
   * @param filename name of the file to be placed in temporary directory.
   * @return std::string The temporary filepath
   */
  std::string get_temp_filepath(std::string filename) { return tmpdir.path() + filename; }
};

}  // namespace test
}  // namespace CUDF_EXPORT cudf
