/*
 * SPDX-FileCopyrightText: Copyright (c) 2019-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

// MIT License
//
// Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
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
#include <cudf/utilities/bit.hpp>

namespace cudf {

namespace jit {

/**
 * @brief C++20 std::span with reduced feature set.
 *
 */
template <typename T>
struct device_span {
  using element_type = T;  ///< The type of the elements in the span

 private:
  element_type* _data = nullptr;
  size_t _size        = 0;

 public:
  CUDF_HOST_DEVICE constexpr device_span() {}

  /**
   * @brief Constructs a span from a pointer and a size.
   *
   * @param data Pointer to the first element in the span.
   * @param size The number of elements in the span.
   */
  CUDF_HOST_DEVICE constexpr device_span(element_type* data, size_t size) : _data{data}, _size{size}
  {
  }

  /**
   * @brief Returns a pointer to the beginning of the sequence.
   *
   * @return A pointer to the first element of the span
   */
  [[nodiscard]] CUDF_HOST_DEVICE constexpr element_type* data() const { return _data; }

  /**
   * @brief Returns the number of elements in the span.
   *
   * @return The number of elements in the span
   */
  [[nodiscard]] CUDF_HOST_DEVICE constexpr size_t size() const { return _size; }

  /**
   * @brief Checks if the span is empty.
   *
   * @return True if the span is empty, false otherwise
   */
  [[nodiscard]] CUDF_HOST_DEVICE constexpr bool empty() const { return _size == 0; }

  /**
   * @brief Returns a reference to the idx-th element of the sequence.
   *
   * The behavior is undefined if idx is out of range (i.e., if it is greater than or equal to
   * size()).
   *
   * @param idx the index of the element to access
   * @return A reference to the idx-th element of the sequence, i.e., `data()[idx]`
   */
  CUDF_HOST_DEVICE constexpr element_type& operator[](size_t idx) const { return _data[idx]; }

  /**
   * @brief Returns an iterator to the first element of the span.
   *
   * If the span is empty, the returned iterator will be equal to end().
   *
   * @return An iterator to the first element of the span
   */
  [[nodiscard]] CUDF_HOST_DEVICE constexpr element_type* begin() const { return _data; }

  /**
   * @brief Returns an iterator to the element following the last element of the span.
   *
   * This element acts as a placeholder; attempting to access it results in undefined behavior.
   *
   * @return An iterator to the element following the last element of the span
   */
  [[nodiscard]] CUDF_HOST_DEVICE constexpr element_type* end() const { return _data + _size; }

  [[nodiscard]] CUDF_HOST_DEVICE constexpr device_span<T const> as_const() const
  {
    return device_span<T const>{_data, _size};
  }
};

}  // namespace jit
}  // namespace cudf
