/*
 * SPDX-FileCopyrightText: Copyright (c) 2020-2026, NVIDIA CORPORATION.
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

#pragma once

#include <cudf/types.hpp>

// <<<<<<< OLD CODE from dc7eb3bf77 (2d6106360e) - COMMENTED OUT
// #include <cudf/cuda_runtime.h>
// =======
#include <cuda/std/limits>
#include <cuda_runtime.h>
// >>>>>>> END NEW CODE (2d6106360e)

/**
 * @file
 * @brief Concrete type definition for dictionary columns.
 */

namespace CUDF_EXPORT cudf {
/**
 * @addtogroup dictionary_classes
 * @{
 * @file
 */

/**
 * @brief A strongly typed wrapper for indices in a DICTIONARY type column.
 *
 * IndexType will be integer types like int32_t.
 *
 * For example, `dictionary32` is a strongly typed wrapper around an `int32_t`
 * value that holds the offset into the dictionary keys for a specific element.
 *
 * This wrapper provides common conversion and comparison operations for
 * the IndexType.
 */
template <typename IndexType>
struct dictionary_wrapper {
  using value_type = IndexType;  ///< The underlying type of the dictionary

  dictionary_wrapper()                          = default;
  ~dictionary_wrapper()                         = default;
  dictionary_wrapper(dictionary_wrapper&&)      = default;  ///< Move constructor
  dictionary_wrapper(dictionary_wrapper const&) = default;  ///< Copy constructor

  /**
   * @brief Move assignment operator
   *
   * @return The reference to this dictionary wrapper object
   */
  dictionary_wrapper& operator=(dictionary_wrapper&&) = default;

  /**
   * @brief Copy assignment operator
   *
   * @return The reference to this dictionary wrapper object
   */
  dictionary_wrapper& operator=(dictionary_wrapper const&) = default;

  /**
   * @brief Construct dictionary_wrapper from a value
   *
   * @param v The value to construct the dictionary_wrapper from
   */
  CUDF_HOST_DEVICE inline constexpr explicit dictionary_wrapper(value_type v) : _value{v} {}

  /**
   * @brief Conversion operator
   *
   * @return The value of this dictionary wrapper
   */
  CUDF_HOST_DEVICE inline explicit operator value_type() const { return _value; }

  /**
   * @brief Simple accessor
   *
   * @return The value of this dictionary wrapper
   */
  [[nodiscard]] CUDF_HOST_DEVICE inline value_type value() const { return _value; }

  /**
   * @brief Returns the maximum value of the value type.
   *
   * @return The maximum value of the value type
   */
  static CUDF_HOST_DEVICE inline constexpr value_type max_value()
  {
    return cuda::std::numeric_limits<value_type>::max();
  }

  /**
   * @brief Returns the minimum value of the value type.
   *
   * @return The minimum value of the value type
   */
  static CUDF_HOST_DEVICE inline constexpr value_type min_value()
  {
    return cuda::std::numeric_limits<value_type>::min();
  }

  /**
   * @brief Returns the lowest value of the value type.
   *
   * @return The lowest value of the value type
   */
  static CUDF_HOST_DEVICE inline constexpr value_type lowest_value()
  {
    return cuda::std::numeric_limits<value_type>::lowest();
  }

 private:
  value_type _value;
};

// comparison operators
/**
 * @brief Wqual to operator for dictionary_wrapper
 *
 * @tparam Integer Index type
 * @param lhs Left hand side of comparison
 * @param rhs Right hand side of comparison
 * @return Returns true if lhs is equal to rhs, false otherwise
 */
template <typename Integer>
CUDF_HOST_DEVICE inline bool operator==(dictionary_wrapper<Integer> const& lhs,
                                        dictionary_wrapper<Integer> const& rhs)
{
  return lhs.value() == rhs.value();
}

/**
 * @brief Not equal to operator for dictionary_wrapper
 *
 * @tparam Integer Index type
 * @param lhs Left hand side of comparison
 * @param rhs Right hand side of comparison
 * @return Returns true if lhs is not equal to rhs, false otherwise
 */
template <typename Integer>
CUDF_HOST_DEVICE inline bool operator!=(dictionary_wrapper<Integer> const& lhs,
                                        dictionary_wrapper<Integer> const& rhs)
{
  return lhs.value() != rhs.value();
}

/**
 * @brief Less than or equal to operator for dictionary_wrapper
 *
 * @tparam Integer Index type
 * @param lhs Left hand side of comparison
 * @param rhs Right hand side of comparison
 * @return Returns true if lhs is less than or equal to rhs, false otherwise
 */
template <typename Integer>
CUDF_HOST_DEVICE inline bool operator<=(dictionary_wrapper<Integer> const& lhs,
                                        dictionary_wrapper<Integer> const& rhs)
{
  return lhs.value() <= rhs.value();
}

/**
 * @brief Greater than or equal to operator for dictionary_wrapper
 *
 * @tparam Integer Index type
 * @param lhs Left hand side of comparison
 * @param rhs Right hand side of comparison
 * @return Returns true if lhs is greater than or equal to rhs, false otherwise
 */
template <typename Integer>
CUDF_HOST_DEVICE inline bool operator>=(dictionary_wrapper<Integer> const& lhs,
                                        dictionary_wrapper<Integer> const& rhs)
{
  return lhs.value() >= rhs.value();
}

/**
 * @brief Less than operator for dictionary_wrapper
 *
 * @tparam Integer Index type
 * @param lhs Left hand side of comparison
 * @param rhs Right hand side of comparison
 * @return Returns true if lhs is less than rhs, false otherwise
 */
template <typename Integer>
CUDF_HOST_DEVICE inline constexpr bool operator<(dictionary_wrapper<Integer> const& lhs,
                                                 dictionary_wrapper<Integer> const& rhs)
{
  return lhs.value() < rhs.value();
}

/**
 * @brief Greater than operator for dictionary_wrapper
 *
 * @tparam Integer Index type
 * @param lhs Left hand side of comparison
 * @param rhs Right hand side of comparison
 * @return Returns true if lhs is greater than rhs, false otherwise
 */
template <typename Integer>
CUDF_HOST_DEVICE inline bool operator>(dictionary_wrapper<Integer> const& lhs,
                                       dictionary_wrapper<Integer> const& rhs)
{
  return lhs.value() > rhs.value();
}

using dictionary32 = dictionary_wrapper<int32_t>;  ///< 32-bit integer indexed dictionary wrapper

/** @} */  // end of group
}  // namespace CUDF_EXPORT cudf
