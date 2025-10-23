/*
 * SPDX-FileCopyrightText: Copyright (c) 2022-2024, NVIDIA CORPORATION.
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

#include <cudf/column/column_device_view.cuh>
#include <cudf/types.hpp>

namespace CUDF_EXPORT cudf {

namespace detail {

/**
 * @brief Given a column_device_view, an instance of this class provides a
 * wrapper on this compound column for struct operations.
 * Analogous to struct_column_view.
 */
class structs_column_device_view : private column_device_view {
 public:
  structs_column_device_view()                                  = delete;
  ~structs_column_device_view()                                 = default;
  structs_column_device_view(structs_column_device_view const&) = default;  ///< Copy constructor
  structs_column_device_view(structs_column_device_view&&)      = default;  ///< Move constructor
  /**
   * @brief Copy assignment operator
   *
   * @return The reference to this structs column
   */
  structs_column_device_view& operator=(structs_column_device_view const&) = default;

  /**
   * @brief Move assignment operator
   *
   * @return The reference to this structs column
   */
  structs_column_device_view& operator=(structs_column_device_view&&) = default;

  /**
   * @brief Construct a new structs column device view object from a column device view.
   *
   * @param underlying_ The column device view to wrap
   */
  CUDF_HOST_DEVICE structs_column_device_view(column_device_view const& underlying_)
    : column_device_view(underlying_)
  {
#if __HIP_DEVICE_COMPILE__
    cudf_assert(underlying_.type().id() == type_id::STRUCT and
                "structs_column_device_view only supports structs");
#else
    CUDF_EXPECTS(underlying_.type().id() == type_id::STRUCT,
                 "structs_column_device_view only supports structs");
#endif
  }

  using column_device_view::child;
  using column_device_view::is_null;
  using column_device_view::nullable;
  using column_device_view::offset;
  using column_device_view::size;

  /**
   * @brief Fetches the child column of the underlying struct column.
   *
   * @param idx The index of the child column to fetch
   * @return The child column sliced relative to the parent's offset and size
   */
  [[nodiscard]] __device__ inline column_device_view get_sliced_child(size_type idx) const
  {
    return child(idx).slice(offset(), size());
  }
};

}  // namespace detail

}  // namespace CUDF_EXPORT cudf
