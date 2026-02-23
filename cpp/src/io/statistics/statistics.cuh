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

/**
 * @file statistics.cuh
 * @brief Common structures and utility functions for statistics
 */

#pragma once

#include "byte_array_view.cuh"

#include <cudf/column/column_device_view.cuh>
#include <cudf/lists/lists_column_view.hpp>
#include <cudf/strings/string_view.hpp>
#include <cudf/types.hpp>

#include <rmm/cuda_stream_view.hpp>

#include <cstdint>

namespace cudf {
namespace io {

enum statistics_dtype {
  dtype_none,
  dtype_bool,
  dtype_int8,
  dtype_int16,
  dtype_int32,
  dtype_date32,
  dtype_int64,
  dtype_timestamp64,
  dtype_decimal64,
  dtype_decimal128,
  dtype_float32,
  dtype_float64,
  dtype_string,
  dtype_byte_array,
};

struct stats_column_desc {
  statistics_dtype stats_dtype;  //!< physical data type of column
  uint32_t num_rows;             //!< number of rows in column
  uint32_t num_values;  //!< Number of data values in column. Different from num_rows in case of
                        //!< nested columns
  int32_t ts_scale;     //!< timestamp scale (>0: multiply by scale, <0: divide by -scale)

  column_device_view const* leaf_column;    //!< Pointer to leaf column
  column_device_view const* parent_column;  //!< Pointer to parent column; nullptr if not list type
};

template <typename ReturnType>
struct t_array_stats {
  using data_ptr_type = decltype(std::declval<ReturnType const>().data());
  data_ptr_type ptr{};  //!< ptr to data
  size_type length{};   //!< length of data

  __host__ __device__ t_array_stats& operator=(ReturnType const& val)
  {
    ptr    = val.data();
    length = val.size_bytes();
    return *this;
  }

  __host__ __device__ operator ReturnType() const { return ReturnType(ptr, length); }
};
using string_stats     = t_array_stats<string_view>;
using byte_array_view  = statistics::byte_array_view;
using byte_array_stats = t_array_stats<byte_array_view>;

union statistics_val {
  // NOTE(HIP/AMD): The largest type needs to come first
  // to ensure that all bytes of a union instance are zero-initialized.
  // Otherwise, we end up in UB situations where some bytes contain
  // arbitrary invalid statistics values which may be written into the
  // output file (seen for ORC + sum member in statistics_chunk struct).
  __int128_t d128_val;        //!< decimal128 columns
  string_stats str_val;       //!< string columns
  byte_array_stats byte_val;  //!< byte array columns
  double fp_val;              //!< float columns
  int64_t i_val;              //!< integer columns
  uint64_t u_val;             //!< unsigned integer columns
};

struct statistics_chunk {
  uint32_t non_nulls{};        //!< number of non-null values in chunk
  uint32_t null_count{};       //!< number of null values in chunk
  statistics_val min_value{};  //!< minimum value in chunk
  statistics_val max_value{};  //!< maximum value in chunk
  statistics_val sum{};        //!< sum of chunk
  uint8_t has_minmax{};        //!< Nonzero if min_value and max_values are valid
  uint8_t has_sum{};           //!< Nonzero if sum is valid
};

struct statistics_group {
  stats_column_desc const* col{};  //!< Column information
  uint32_t start_row{};            //!< Start row of this group
  uint32_t num_rows{};             //!< Number of rows in group
  uint32_t non_leaf_nulls{};       //!< Number of null non-leaf values in the group
};

struct statistics_merge_group {
  data_type col_dtype;                       //!< Column data type
  statistics_dtype stats_dtype{dtype_none};  //!< Statistics data type for this column
  uint32_t start_chunk{};                    //!< Start chunk of this group
  uint32_t num_chunks{};                     //!< Number of chunks in group
};

template <typename T>
__device__ T get_element(column_device_view const& col, uint32_t row)
  requires(!std::is_same_v<T, statistics::byte_array_view>)
{
  return col.element<T>(row);
}

template <typename T>
__device__ T get_element(column_device_view const& col, uint32_t row)
  requires(std::is_same_v<T, statistics::byte_array_view>)
{
  using et              = typename T::element_type;
  size_type const index = row + col.offset();  // account for this view's _offset
  auto const* d_offsets = col.child(lists_column_view::offsets_column_index).data<size_type>();
  auto const* d_data    = col.child(lists_column_view::child_column_index).data<et>();
  auto const offset     = d_offsets[index];
  return T(d_data + offset, d_offsets[index + 1] - offset);
}

}  // namespace io
}  // namespace cudf
