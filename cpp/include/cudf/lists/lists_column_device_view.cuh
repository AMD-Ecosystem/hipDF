/*
 * Copyright (c) 2020-2024, NVIDIA CORPORATION.
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
#include <cudf/column/column_device_view.cuh>
#include <cudf/lists/lists_column_view.hpp>
#include <cudf/types.hpp>

namespace cudf::detail {

/**
 * @brief Given a column_device_view, an instance of this class provides a
 * wrapper on this compound column for list operations.
 * Analogous to list_column_view.
 */
class lists_column_device_view : private column_device_view {
 public:
  lists_column_device_view()                                = delete;
  ~lists_column_device_view()                               = default;
  lists_column_device_view(lists_column_device_view const&) = default;  ///< Copy constructor
  lists_column_device_view(lists_column_device_view&&)      = default;  ///< Move constructor
  /**
   * @brief Copy assignment operator
   *
   * @return The reference to this lists column device view
   */
  lists_column_device_view& operator=(lists_column_device_view const&) = default;
  /**
   * @brief Move assignment operator
   *
   * @return The reference to this lists column device view
   */
  lists_column_device_view& operator=(lists_column_device_view&&) = default;

  /**
   * @brief Construct a new lists column device view object from a column device view.
   *
   * @param underlying_ The column device view to wrap
   */
  CUDF_HOST_DEVICE lists_column_device_view(column_device_view const& underlying_)
    : column_device_view(underlying_)
  {
#if __HIP_DEVICE_COMPILE__
    cudf_assert(underlying_.type().id() == type_id::LIST and
                "lists_column_device_view only supports lists");
#else
    CUDF_EXPECTS(underlying_.type().id() == type_id::LIST,
                 "lists_column_device_view only supports lists");
#endif
  }

  using column_device_view::is_null;
  using column_device_view::nullable;
  using column_device_view::offset;
  using column_device_view::size;

  /**
   * @brief Fetches the offsets column of the underlying list column.
   *
   * @return The offsets column of the underlying list column
   */
  [[nodiscard]] __device__ inline column_device_view offsets() const
  {
    return column_device_view::child(lists_column_view::offsets_column_index);
  }

  /**
   * @brief Fetches the list offset value at a given row index while taking column offset into
   * account.
   *
   * @param idx The row index to fetch the list offset value at
   * @return The list offset value at a given row index while taking column offset into account
   */
  [[nodiscard]] __device__ inline size_type offset_at(size_type idx) const
  {
    return offsets().size() > 0 ? offsets().element<size_type>(offset() + idx) : 0;
  }

  /**
   * @brief Fetches the child column of the underlying list column.
   *
   * @return The child column of the underlying list column
   */
  [[nodiscard]] __device__ inline column_device_view child() const
  {
    return column_device_view::child(lists_column_view::child_column_index);
  }

  /**
   * @brief Fetches the child column of the underlying list column with offset and size applied
   *
   * @return The child column sliced relative to the parent's offset and size
   */
  [[nodiscard]] __device__ inline column_device_view get_sliced_child() const
  {
    auto start = offset_at(0);
    auto end   = offset_at(size());
    return child().slice(start, end - start);
  }
};

}  // namespace cudf::detail
