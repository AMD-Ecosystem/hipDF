/*
 * SPDX-FileCopyrightText: Copyright (c) 2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#pragma once

#include <cudf/io/parquet_schema.hpp>
#include <cudf/utilities/export.hpp>
#include <cudf/wrappers/timestamps.hpp>

#include <cuda/std/optional>

namespace cudf::io::parquet::detail {

/**
 * @brief Computes the timestamp scale between a Parquet timestamp logical type's
 * native precision and the output column's clock rate.
 *
 * @param logical_type Logical type of the column
 * @param clock_rate Clock rate of the output timestamp column (e.g. 1000 for ms)
 * @return Scale factor; <0 means divide by `-scale`, >0 means multiply by `scale`, 0 means no-op
 */
[[nodiscard]] CUDF_HOST_DEVICE inline int32_t calc_timestamp_scale(
  cuda::std::optional<LogicalType> logical_type, int32_t clock_rate)
{
  if (not logical_type.has_value()) { return 0; }

  auto units = 0;
  if (logical_type->is_timestamp_millis()) {
    units = cudf::timestamp_ms::period::den;
  } else if (logical_type->is_timestamp_micros()) {
    units = cudf::timestamp_us::period::den;
  } else if (logical_type->is_timestamp_nanos()) {
    units = cudf::timestamp_ns::period::den;
  }

  // NOTE(HIP/AMD): clock_rate can be 0 when the user does not specify a timestamp type in
  // parquet_reader_options (i.e., options.get_timestamp_type().id() == type_id::EMPTY). In this
  // case, timestamps are read in their native Parquet format without conversion. The check
  // "clock_rate and" prevents division by zero (UB) and correctly returns scale=0, meaning no
  // scaling is performed. This guard is exercised by the dictionary_page_filter.cu device path.
  if (units and clock_rate and units != clock_rate) {
    return (clock_rate < units) ? -(units / clock_rate) : (clock_rate / units);
  }

  return 0;
}

/**
 * @brief Apply timestamp scaling to a raw decoded value.
 *
 * @param value Raw decoded int64 integer value
 * @param ts_scale Timestamp scale
 * @return Scaled 64-bit timestamp value
 */
[[nodiscard]] CUDF_HOST_DEVICE inline int64_t apply_ts_scale(int64_t value, int32_t ts_scale)
{
  if (ts_scale == 0) {
    return value;
  } else if (ts_scale < 0) {
    // Floor division towards negative infinity
    auto const divisor   = -ts_scale;
    auto quotient        = value / divisor;
    auto const remainder = value % divisor;
    return (remainder < 0) ? quotient - 1 : quotient;
  } else {
    return value * ts_scale;
  }
}

}  // namespace cudf::io::parquet::detail
