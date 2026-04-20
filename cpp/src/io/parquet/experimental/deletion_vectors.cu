// <<<<<<< OLD CODE from 6da20d623c (7414d23ab6) - COMMENTED OUT
// /*
//  * Copyright (c) 2025, NVIDIA CORPORATION.
//  *
//  * Licensed under the Apache License, Version 2.0 (the "License");
//  * you may not use this file except in compliance with the License.
//  * You may obtain a copy of the License at
//  *
//  *     http://www.apache.org/licenses/LICENSE-2.0
//  *
//  * Unless required by applicable law or agreed to in writing, software
//  * distributed under the License is distributed on an "AS IS" BASIS,
//  * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  * See the License for the specific language governing permissions and
//  * limitations under the License.
//  */
//
// // MIT License
// //
// // Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
// //
// // Permission is hereby granted, free of charge, to any person obtaining a copy
// // of this software and associated documentation files (the "Software"), to deal
// // in the Software without restriction, including without limitation the rights
// // to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// // copies of the Software, and to permit persons to whom the Software is
// // furnished to do so, subject to the following conditions:
// //
// // The above copyright notice and this permission notice shall be included in all
// // copies or substantial portions of the Software.
// //
// // THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// // IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// // FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// // AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// // LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// // OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// // SOFTWARE.
//
// #include <cudf/detail/utilities/vector_factories.hpp>
// #include <cudf/io/experimental/deletion_vectors.hpp>
// #include <cudf/stream_compaction.hpp>
// #include <cudf/types.hpp>
// #include <cudf/utilities/error.hpp>
//
// #include <rmm/cuda_stream_view.hpp>
// #include <rmm/device_buffer.hpp>
// #include <rmm/exec_policy.hpp>
// #include <rmm/mr/device/device_memory_resource.hpp>
//
// #include <cuco/roaring_bitmap.cuh>
// #include <cuda/functional>
// #include <thrust/host_vector.h>
// #include <thrust/iterator/transform_output_iterator.h>
// #include <thrust/scatter.h>
// #include <thrust/sequence.h>
//
// #include <numeric>
//
// namespace cudf::io::parquet::experimental {
//
// namespace {
//
// /**
//  * @brief Computes a row index column from the specified row group row offsets and counts
//  *
//  * @param row_group_offsets Host span of row group offsets
//  * @param row_group_num_rows Host span of number of rows in each row group
//  * @param num_rows Total number of table rows
//  * @param stream CUDA stream for kernel launches and data transfers
//  * @param mr Device memory resource to allocate device memory for the row index column
//  *
//  * @return UINT64 column containing row indices
//  */
// std::unique_ptr<cudf::column> compute_row_index_column(
//   cudf::host_span<size_t const> row_group_offsets,
//   cudf::host_span<size_type const> row_group_num_rows,
//   size_type num_rows,
//   rmm::cuda_stream_view stream,
//   rmm::device_async_resource_ref mr)
// {
//   auto const num_row_groups = static_cast<size_type>(row_group_num_rows.size());
//
//   if (row_group_offsets.empty()) {
//     auto row_indices      = rmm::device_buffer(num_rows * sizeof(size_t), stream, mr);
//     auto row_indices_iter = static_cast<size_t*>(row_indices.data());
//     thrust::sequence(
//       rmm::exec_policy_nosync(stream), row_indices_iter, row_indices_iter + num_rows, 0);
//     return std::make_unique<cudf::column>(cudf::data_type{cudf::type_id::UINT64},
//                                           num_rows,
//                                           std::move(row_indices),
//                                           rmm::device_buffer{},
//                                           0);
//   }
//
//   // Convert number of rows in each row group to row group span offsets. Here, a span is the range
//   // of (table) rows that belong to a row group
//   auto row_group_span_offsets =
//     cudf::detail::make_host_vector<size_type>(num_row_groups + 1, stream);
//   row_group_span_offsets[0] = 0;
//   std::inclusive_scan(
//     row_group_num_rows.begin(), row_group_num_rows.end(), row_group_span_offsets.begin() + 1);
//
//   auto row_indices      = rmm::device_buffer(num_rows * sizeof(size_t), stream, mr);
//   auto row_indices_iter = static_cast<size_t*>(row_indices.data());
//   thrust::fill(rmm::exec_policy_nosync(stream), row_indices_iter, row_indices_iter + num_rows, 1);
//
//   auto row_group_keys = rmm::device_uvector<size_type>(num_rows, stream);
//   thrust::fill(rmm::exec_policy_nosync(stream), row_group_keys.begin(), row_group_keys.end(), 0);
//
//   // Scatter row group offsets and row group indices (or span indices) to their corresponding
//   // row group span offsets
//   auto d_row_group_offsets = cudf::detail::make_device_uvector_async(
//     row_group_offsets, stream, cudf::get_current_device_resource_ref());
//   auto d_row_group_span_offsets = cudf::detail::make_device_uvector_async(
//     row_group_span_offsets, stream, cudf::get_current_device_resource_ref());
//   auto in_iter =
//     thrust::make_zip_iterator(d_row_group_offsets.begin(), thrust::counting_iterator<size_type>(0));
//   auto out_iter = thrust::make_zip_iterator(row_indices_iter, row_group_keys.begin());
//   thrust::scatter(rmm::exec_policy_nosync(stream),
//                   in_iter,
//                   in_iter + num_row_groups,
//                   d_row_group_span_offsets.begin(),
//                   out_iter);
//
//   // Fill in the the rest of the row group span indices
//   // NOTE(HIP/AMD): libhipcxx 2.7.0 does not have cuda::maximum yet.
//   // Use thrust::maximum as a workaround for affected versions.
// #if defined(CCCL_VERSION) && CCCL_VERSION <= 2007000
//   thrust::inclusive_scan(rmm::exec_policy_nosync(stream),
//                          row_group_keys.begin(),
//                          row_group_keys.end(),
//                          row_group_keys.begin(),
//                          thrust::maximum<cudf::size_type>());
// #else
//   thrust::inclusive_scan(rmm::exec_policy_nosync(stream),
//                          row_group_keys.begin(),
//                          row_group_keys.end(),
//                          row_group_keys.begin(),
//                          cuda::maximum<cudf::size_type>());
// #endif
//
//   // Segmented inclusive scan to compute the rest of the row indices
//   thrust::inclusive_scan_by_key(rmm::exec_policy_nosync(stream),
//                                 row_group_keys.begin(),
//                                 row_group_keys.end(),
//                                 row_indices_iter,
//                                 row_indices_iter);
//
//   return std::make_unique<cudf::column>(cudf::data_type{cudf::type_id::UINT64},
//                                         num_rows,
//                                         std::move(row_indices),
//                                         rmm::device_buffer{},
//                                         0);
// }
//
// /**
//  * @brief Builds a BOOL8 row mask column from the specified host span of row indices and the
//  * roaring64 deletion vector
//  *
//  * @param row_indices Host span of row indices
//  * @param deletion_vector Pointer to the roaring64 deletion vector
//  * @param num_rows Number of rows in the column
//  * @param stream CUDA stream for kernel launches and data transfers
//  * @param mr Device memory resource to allocate device memory for the row mask column
//  *
//  * @return Unique pointer to the row mask column
//  */
// std::unique_ptr<cudf::column> build_row_mask_column(
//   cudf::column_view const& row_index_column,
//   cudf::host_span<cuda::std::byte const> deletion_vector,
//   size_type num_rows,
//   rmm::cuda_stream_view stream,
//   rmm::device_async_resource_ref mr)
// {
//   auto row_mask = rmm::device_buffer(num_rows, stream, mr);
//   cuco::experimental::roaring_bitmap<cuda::std::uint64_t> roaring_bitmap(
//     deletion_vector.data(), {}, stream);
//
//   // Iterator to negate and store the output value from `contains_async`
//   auto row_mask_iter = thrust::make_transform_output_iterator(
//     static_cast<bool*>(row_mask.data()), [] __device__(auto b) { return not b; });
//   roaring_bitmap.contains_async(
//     row_index_column.begin<size_t>(), row_index_column.end<size_t>(), row_mask_iter, stream);
//
//   return std::make_unique<cudf::column>(
//     cudf::data_type{cudf::type_id::BOOL8}, num_rows, std::move(row_mask), rmm::device_buffer{}, 0);
// }
//
// }  // namespace
//
// table_with_metadata read_parquet_and_apply_deletion_vector(
//   parquet_reader_options const& options,
//   cudf::host_span<cuda::std::byte const> serialized_roaring64,
//   cudf::host_span<size_t const> row_group_offsets,
//   cudf::host_span<size_type const> row_group_num_rows,
//   rmm::cuda_stream_view stream,
//   rmm::device_async_resource_ref mr)
// {
//   CUDF_EXPECTS(
//     row_group_offsets.size() == row_group_num_rows.size(),
//     "Encountered a mismatch in the number of row group offsets and row group row counts");
//   CUDF_EXPECTS(
//     not options.get_filter().has_value(),
//     "Encountered a non-empty AST filter expression. Use a roaring64 bitmap deletion vector to "
//     "filter the table instead");
//
//   // Use default mr to read parquet table and build row index column if we will be applying the
//   // deletion vector to produce a new table later
//   auto const table_mr =
//     serialized_roaring64.empty() ? mr : rmm::mr::get_current_device_resource_ref();
//
//   // Read the parquet table
//   auto [table, metadata] = cudf::io::read_parquet(options, stream, table_mr);
//   auto const num_rows    = table->num_rows();
//
//   CUDF_EXPECTS(
//     row_group_num_rows.empty() or
//       std::cmp_equal(metadata.num_input_row_groups, row_group_num_rows.size()),
//     "Encountered a mismatch in the number of row groups in parquet file and the specified "
//     "row group offsets/row counts vectors");
//
//   // Compute a row index column from the specified row group offsets and counts
//   auto row_index_column =
//     compute_row_index_column(row_group_offsets, row_group_num_rows, num_rows, stream, table_mr);
//
//   // Prepend row index column to the table columns
//   auto index_and_table_columns = std::vector<std::unique_ptr<cudf::column>>{};
//   index_and_table_columns.reserve(table->num_columns() + 1);
//   index_and_table_columns.push_back(std::move(row_index_column));
//   auto table_columns = table->release();
//   index_and_table_columns.insert(index_and_table_columns.end(),
//                                  std::make_move_iterator(table_columns.begin()),
//                                  std::make_move_iterator(table_columns.end()));
//
//   // Table with the index and table columns
//   auto table_with_index = std::make_unique<cudf::table>(std::move(index_and_table_columns));
//
//   // Also prepend the row index column's metadata to the table schema
//   auto updated_schema_info = std::vector<cudf::io::column_name_info>{};
//   updated_schema_info.reserve(metadata.schema_info.size() + 1);
//   updated_schema_info.emplace_back("index");
//   updated_schema_info.insert(updated_schema_info.end(),
//                              std::make_move_iterator(metadata.schema_info.begin()),
//                              std::make_move_iterator(metadata.schema_info.end()));
//   metadata.schema_info = std::move(updated_schema_info);
//
//   if (serialized_roaring64.empty()) {
//     return table_with_metadata{std::move(table_with_index), std::move(metadata)};
//   } else {
//     // Filter the table using the deletion vector
//     auto row_mask = build_row_mask_column(table_with_index->get_column(0).view(),
//                                           serialized_roaring64,
//                                           num_rows,
//                                           stream,
//                                           cudf::get_current_device_resource_ref());
//     return table_with_metadata{
//       // Supply user-provided mr to apply_boolean_mask to allocate output table's memory
//       cudf::apply_boolean_mask(table_with_index->view(), row_mask->view(), stream, mr),
//       std::move(metadata)};
//   }
// }
//
// }  // namespace cudf::io::parquet::experimental
// =======
/*
 * SPDX-FileCopyrightText: Copyright (c) 2025-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

#include "deletion_vectors_helpers.hpp"

#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/io/experimental/deletion_vectors.hpp>
#include <cudf/stream_compaction.hpp>
#include <cudf/utilities/error.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/mr/polymorphic_allocator.hpp>
#include <rmm/resource_ref.hpp>

#include <cuda/functional>
#include <cuda/iterator>
#include <cuda/std/tuple>

#include <numeric>

namespace cudf::io::parquet::experimental {

namespace detail {

[[nodiscard]] table_with_metadata read_parquet(parquet_reader_options const& options,
                                               deletion_vector_info const& deletion_vector_info,
                                               rmm::cuda_stream_view stream,
                                               rmm::device_async_resource_ref mr)
{
  auto const& serialized_roaring_bitmaps = deletion_vector_info.serialized_roaring_bitmaps;
  auto const& deletion_vector_row_counts = deletion_vector_info.deletion_vector_row_counts;
  auto const& row_group_offsets          = deletion_vector_info.row_group_offsets;
  auto const& row_group_num_rows         = deletion_vector_info.row_group_num_rows;

  CUDF_EXPECTS(
    row_group_offsets.size() == row_group_num_rows.size(),
    "Encountered a mismatch in the number of row group offsets and row group row counts");
  CUDF_EXPECTS(
    not options.get_filter().has_value(),
    "Encountered a non-empty AST filter expression. Use a roaring64 bitmap deletion vector to "
    "filter the table instead");
  CUDF_EXPECTS(serialized_roaring_bitmaps.empty() or
                 serialized_roaring_bitmaps.size() == deletion_vector_row_counts.size(),
               "Encountered a mismatch in the number of deletion vectors and the number of rows "
               "per deletion vector");

  // Use default mr to read parquet table and build row index column if we will be applying the
  // deletion vector to produce a new table later
  auto const table_mr =
    serialized_roaring_bitmaps.empty() ? mr : cudf::get_current_device_resource_ref();

  auto [table, metadata] = cudf::io::read_parquet(options, stream, table_mr);
  auto const num_rows    = table->num_rows();

  CUDF_EXPECTS(
    row_group_num_rows.empty() or
      std::cmp_equal(metadata.num_input_row_groups, row_group_num_rows.size()),
    "Encountered a mismatch in the number of row groups in parquet file and the specified "
    "row group offsets/row counts vectors");

  // Compute a row index column from the specified row group offsets and counts
  auto row_index_column = compute_row_index_column(
    row_group_offsets, row_group_num_rows, std::nullopt, num_rows, stream, table_mr);

  // Prepend row index column to the table columns
  auto table_with_index =
    prepend_index_column_to_table(std::move(table), std::move(row_index_column));

  prepend_index_column_to_table_metadata(metadata);

  if (serialized_roaring_bitmaps.empty()) {
    return table_with_metadata{std::move(table_with_index), std::move(metadata)};
  }

  // Construct all deletion vectors and store their references
  auto deletion_vectors      = std::vector<roaring_bitmap_type>{};
  auto deletion_vectors_refs = std::vector<std::reference_wrapper<roaring_bitmap_type>>{};
  deletion_vectors.reserve(serialized_roaring_bitmaps.size());
  deletion_vectors_refs.reserve(serialized_roaring_bitmaps.size());
  std::transform(serialized_roaring_bitmaps.begin(),
                 serialized_roaring_bitmaps.end(),
                 std::back_inserter(deletion_vectors_refs),
                 [&](auto const& serialized_roaring_bitmap) {
                   deletion_vectors.emplace_back(serialized_roaring_bitmap.data(),
                                                 rmm::mr::polymorphic_allocator<char>{},
                                                 stream);
                   return std::ref(deletion_vectors.back());
                 });
  auto row_mask = compute_row_mask_column(table_with_index->get_column(0).view(),
                                          deletion_vectors_refs,
                                          deletion_vector_row_counts,
                                          stream,
                                          cudf::get_current_device_resource_ref());
  // Filter the table using the deletion vector
  return table_with_metadata{
    // Supply user-provided mr to apply_boolean_mask to allocate output table's memory
    cudf::apply_boolean_mask(table_with_index->view(), row_mask->view(), stream, mr),
    std::move(metadata)};
}

[[nodiscard]] size_t compute_num_deleted_rows(deletion_vector_info const& deletion_vector_info,
                                              cudf::size_type max_chunk_rows,
                                              rmm::cuda_stream_view stream)
{
  auto const& serialized_roaring_bitmaps = deletion_vector_info.serialized_roaring_bitmaps;
  auto const& deletion_vector_row_counts = deletion_vector_info.deletion_vector_row_counts;
  auto const& row_group_offsets          = deletion_vector_info.row_group_offsets;
  auto const& row_group_num_rows         = deletion_vector_info.row_group_num_rows;

  if (serialized_roaring_bitmaps.empty()) { return 0; }

  // Validate input
  CUDF_EXPECTS(std::cmp_equal(serialized_roaring_bitmaps.size(), deletion_vector_row_counts.size()),
               "Encountered a mismatch in the number of deletion vector data spans and the number "
               "of rows per deletion vector");
  CUDF_EXPECTS(
    row_group_offsets.size() == row_group_num_rows.size(),
    "Encountered a mismatch in the number of row group offsets and row group row counts");
  CUDF_EXPECTS(max_chunk_rows > 0, "Encountered an invalid chunk size");

  auto const is_row_group_data_unspecified = row_group_offsets.empty();

  auto const num_rows = [&]() {
    auto const rows_in_dvs = std::accumulate(
      deletion_vector_row_counts.begin(), deletion_vector_row_counts.end(), size_t{0});
    if (not is_row_group_data_unspecified) {
      auto const rows_in_rgs =
        std::accumulate(row_group_num_rows.begin(), row_group_num_rows.end(), size_t{0});
      CUDF_EXPECTS(std::cmp_equal(rows_in_dvs, rows_in_rgs),
                   "Encountered a mismatch in the number of rows across deletion vectors and the "
                   "number of rows across row groups");
    }
    return rows_in_dvs;
  }();

  std::queue<size_t> rg_offsets_queue;
  std::queue<size_type> rg_counts_queue;
  for (size_t i = 0; i < row_group_offsets.size(); ++i) {
    rg_offsets_queue.push(row_group_offsets[i]);
    rg_counts_queue.push(row_group_num_rows[i]);
  }

  std::queue<chunked_parquet_reader::roaring_bitmap_impl> dv_queue;
  std::queue<cudf::size_type> dv_row_counts_queue;
  for (size_t i = 0; i < serialized_roaring_bitmaps.size(); ++i) {
    dv_queue.emplace(serialized_roaring_bitmaps[i]);
    dv_row_counts_queue.push(deletion_vector_row_counts[i]);
  }

  size_t deleted_rows   = 0;
  size_t remaining_rows = num_rows;
  size_t start_row      = 0;

  while (remaining_rows > 0) {
    // Maximum number of rows to process in this chunk
    auto const chunk_rows = std::min<size_t>(remaining_rows, max_chunk_rows);
    auto row_index_column =
      compute_partial_row_index_column(rg_offsets_queue,
                                       rg_counts_queue,
                                       start_row,
                                       static_cast<size_type>(chunk_rows),
                                       is_row_group_data_unspecified,
                                       stream,
                                       cudf::get_current_device_resource_ref());
    deleted_rows += compute_partial_deleted_row_count(
      row_index_column->view(), dv_queue, dv_row_counts_queue, stream);

    start_row += chunk_rows;
    remaining_rows -= chunk_rows;
  }

  return deleted_rows;
}

}  // namespace detail

/**
 * @copydoc
 * cudf::io::parquet::experimental::chunked_parquet_reader::chunked_parquet_reader
 */
chunked_parquet_reader::chunked_parquet_reader(std::size_t chunk_read_limit,
                                               std::size_t pass_read_limit,
                                               parquet_reader_options const& options,
                                               deletion_vector_info const& deletion_vector_info,
                                               rmm::cuda_stream_view stream,
                                               rmm::device_async_resource_ref mr)
  : _start_row{0},
    _is_unspecified_row_group_data{deletion_vector_info.row_group_offsets.empty()},
    _stream{stream},
    _mr{mr},
    // Use default mr for the internal chunked reader and row index column if we will
    // be applying the deletion vector to produce the output table
    _table_mr{deletion_vector_info.serialized_roaring_bitmaps.empty()
                ? mr
                : cudf::get_current_device_resource_ref()}
{
  auto const& serialized_roaring_bitmaps = deletion_vector_info.serialized_roaring_bitmaps;
  auto const& deletion_vector_row_counts = deletion_vector_info.deletion_vector_row_counts;
  auto const& row_group_offsets          = deletion_vector_info.row_group_offsets;
  auto const& row_group_num_rows         = deletion_vector_info.row_group_num_rows;

  CUDF_EXPECTS(
    row_group_offsets.size() == row_group_num_rows.size(),
    "Encountered a mismatch in the number of row group offsets and row group row counts");
  CUDF_EXPECTS(
    not options.get_filter().has_value(),
    "Encountered a non-empty AST filter expression. Use a roaring64 bitmap deletion vector to "
    "filter the table instead");
  CUDF_EXPECTS(serialized_roaring_bitmaps.empty() or
                 serialized_roaring_bitmaps.size() == deletion_vector_row_counts.size(),
               "Encountered a mismatch in the number of deletion vectors and the number of rows "
               "per deletion vector");

  // Initialize the internal chunked parquet reader
  _reader = std::make_unique<cudf::io::chunked_parquet_reader>(
    chunk_read_limit, pass_read_limit, options, _stream, _table_mr);

  // Push row group offsets and counts to the internal queues
  if (not row_group_offsets.empty()) {
    auto iter = cuda::make_zip_iterator(row_group_offsets.begin(), row_group_num_rows.begin());
    std::for_each(iter, iter + row_group_offsets.size(), [&](auto const& elem) {
      _row_group_row_offsets.push(cuda::std::get<0>(elem));
      _row_group_row_counts.push(cuda::std::get<1>(elem));
    });
  }

  // Push deletion vector data spans and row counts to the internal queues
  if (not serialized_roaring_bitmaps.empty()) {
    auto iter = cuda::make_zip_iterator(serialized_roaring_bitmaps.begin(),
                                        deletion_vector_row_counts.begin());
    std::for_each(iter, iter + serialized_roaring_bitmaps.size(), [&](auto const& elem) {
      _deletion_vectors.emplace(cuda::std::get<0>(elem));
      _deletion_vector_row_counts.push(cuda::std::get<1>(elem));
    });
  }
}

/**
 * @copydoc
 * cudf::io::parquet::experimental::chunked_parquet_reader::chunked_parquet_reader
 */
chunked_parquet_reader::chunked_parquet_reader(std::size_t chunk_read_limit,
                                               parquet_reader_options const& options,
                                               deletion_vector_info const& deletion_vector_info,
                                               rmm::cuda_stream_view stream,
                                               rmm::device_async_resource_ref mr)
  : chunked_parquet_reader(
      chunk_read_limit, std::size_t{0}, options, deletion_vector_info, stream, mr)
{
}

/**
 * @copydoc cudf::io::parquet::experimental::chunked_parquet_reader::~chunked_parquet_reader
 */
chunked_parquet_reader::~chunked_parquet_reader() = default;

/**
 * @copydoc cudf::io::parquet::experimental::chunked_parquet_reader::has_next
 */
bool chunked_parquet_reader::has_next() const { return _reader->has_next(); }

/**
 * @copydoc cudf::io::parquet::experimental::chunked_parquet_reader::read_chunk
 */
table_with_metadata chunked_parquet_reader::read_chunk()
{
  CUDF_FUNC_RANGE();

  // Read a chunk of the parquet table
  auto [table, metadata] = _reader->read_chunk();
  auto const num_rows    = table->num_rows();

  // Compute a chunk of the row index column from the specified row group offsets and counts
  auto row_index_column = compute_partial_row_index_column(_row_group_row_offsets,
                                                           _row_group_row_counts,
                                                           _start_row,
                                                           num_rows,
                                                           _is_unspecified_row_group_data,
                                                           _stream,
                                                           _table_mr);
  // Update the start row index for the next chunk
  _start_row += num_rows;

  // Prepend row index column to the table columns
  auto table_with_index =
    prepend_index_column_to_table(std::move(table), std::move(row_index_column));

  // Also prepend the row index column's metadata to the table schema
  prepend_index_column_to_table_metadata(metadata);

  // Return early if deletion vector is not present
  if (_deletion_vectors.empty()) {
    return table_with_metadata{std::move(table_with_index), std::move(metadata)};
  }

  // Filter the table using the deletion vectors
  auto row_mask = compute_partial_row_mask_column(table_with_index->get_column(0).view(),
                                                  _deletion_vectors,
                                                  _deletion_vector_row_counts,
                                                  _stream,
                                                  cudf::get_current_device_resource_ref());
  return table_with_metadata{
    // Supply user-provided mr to apply_boolean_mask to allocate output table's memory
    cudf::apply_boolean_mask(table_with_index->view(), row_mask->view(), _stream, _mr),
    std::move(metadata)};
}

/**
 * @copydoc cudf::io::parquet::experimental::read_parquet
 */
table_with_metadata read_parquet(parquet_reader_options const& options,
                                 deletion_vector_info const& deletion_vector_info,
                                 rmm::cuda_stream_view stream,
                                 rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::read_parquet(options, deletion_vector_info, stream, mr);
}

/**
 * @copydoc cudf::io::parquet::experimental::compute_num_deleted_rows
 */
size_t compute_num_deleted_rows(deletion_vector_info const& deletion_vector_info,
                                cudf::size_type max_chunk_rows,
                                rmm::cuda_stream_view stream)
{
  CUDF_FUNC_RANGE();
  return detail::compute_num_deleted_rows(deletion_vector_info, max_chunk_rows, stream);
}

}  // namespace cudf::io::parquet::experimental
// >>>>>>> END NEW CODE (7414d23ab6)
