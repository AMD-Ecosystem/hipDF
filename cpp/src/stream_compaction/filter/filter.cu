/*
 * SPDX-FileCopyrightText: Copyright (c) 2025-2026, NVIDIA CORPORATION.
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

#include "jit/row_ir.hpp"

#include <cudf/column/column_device_view.cuh>
#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/stream_compaction.hpp>
#include <cudf/null_mask.hpp>
#include <cudf/stream_compaction.hpp>
#include <cudf/transform.hpp>

#include <rmm/cuda_stream_view.hpp>

#include <jit/helpers.hpp>

#include <variant>
#include <vector>

namespace cudf {

namespace detail {
std::vector<std::unique_ptr<column>> filter(
  std::span<std::variant<column_view, scalar_column_view> const> predicate_inputs,
  std::string const& predicate_udf,
  std::vector<column_view> const& filter_columns,
  cudf::udf_source_type source_type,
  std::optional<void*> user_data,
  null_aware is_null_aware,
  output_nullability predicate_nullability,
  rmm::cuda_stream_view stream,
  rmm::device_async_resource_ref mr)
{
  CUDF_EXPECTS(!filter_columns.empty(),
               "At least one column must be provided to filter.",
               std::invalid_argument);
  auto row_size = filter_columns[0].size();
  CUDF_EXPECTS(std::all_of(filter_columns.begin(),
                           filter_columns.end(),
                           [&](auto const& col) { return col.size() == row_size; }),
               "All columns to filter must have the same number of rows.",
               std::invalid_argument);

  auto predicate = cudf::transform_extended(predicate_inputs,
                                            predicate_udf,
                                            data_type{type_id::BOOL8},
                                            source_type,
                                            user_data,
                                            is_null_aware,
                                            row_size,
                                            predicate_nullability,
                                            stream,
                                            mr);

  return apply_mask(
           cudf::table_view{filter_columns}, predicate->view(), mask_type::RETENTION, stream, mr)
    ->release();
}

}  // namespace detail

std::unique_ptr<table> filter(table_view const& predicate_table,
                              ast::expression const& predicate_expr,
                              table_view const& filter_table,
                              rmm::cuda_stream_view stream,
                              rmm::device_async_resource_ref mr)
{
  cudf::detail::row_ir::ast_args ast_args{.table = predicate_table};
  auto args = cudf::detail::row_ir::ast_converter::filter(
    cudf::detail::row_ir::target::CUDA, predicate_expr, ast_args, filter_table, stream, mr);

  return std::make_unique<table>(cudf::detail::filter(args.inputs,
                                                      args.udf,
                                                      args.filter_columns,
                                                      args.source_type,
                                                      args.user_data,
                                                      args.is_null_aware,
                                                      args.predicate_nullability,
                                                      stream,
                                                      mr));
}

std::vector<std::unique_ptr<column>> filter_extended(
  std::span<std::variant<column_view, scalar_column_view> const> predicate_inputs,
  std::string const& predicate_udf,
  std::vector<column_view> const& filter_columns,
  cudf::udf_source_type source_type,
  std::optional<void*> user_data,
  null_aware is_null_aware,
  output_nullability predicate_nullability,
  rmm::cuda_stream_view stream,
  rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::filter(predicate_inputs,
                        predicate_udf,
                        filter_columns,
                        source_type,
                        user_data,
                        is_null_aware,
                        predicate_nullability,
                        stream,
                        mr);
}

std::vector<std::unique_ptr<column>> filter(std::vector<column_view> const& predicate_columns,
                                            std::string const& predicate_udf,
                                            std::vector<column_view> const& filter_columns,
                                            bool is_ptx,
                                            std::optional<void*> user_data,
                                            null_aware is_null_aware,
                                            output_nullability predicate_nullability,
                                            rmm::cuda_stream_view stream,
                                            rmm::device_async_resource_ref mr)
{
  // legacy behavior was to detect which column were scalars based on their sizes
  std::vector<std::variant<column_view, scalar_column_view>> inputs;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  auto base_column = jit::get_transform_base_column(predicate_columns);
  for (auto const& col : predicate_columns) {
    if (jit::is_scalar(base_column->size(), col.size())) {
#pragma GCC diagnostic pop
      inputs.emplace_back(scalar_column_view{col});
    } else {
      inputs.emplace_back(col);
    }
  }

  return detail::filter(inputs,
                        predicate_udf,
                        filter_columns,
                        is_ptx ? cudf::udf_source_type::PTX : cudf::udf_source_type::CUDA,
                        user_data,
                        is_null_aware,
                        predicate_nullability,
                        stream,
                        mr);
}

}  // namespace cudf
