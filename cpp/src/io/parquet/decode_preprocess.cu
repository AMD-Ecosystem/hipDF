/*
 * SPDX-FileCopyrightText: Copyright (c) 2023-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */
// MIT License
//
// Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
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

#include "cudf/cuda_runtime.h"

#include "delta_binary.cuh"
#include "io/utilities/column_buffer.hpp"
#include "page_decode.cuh"
#include "reader_impl_chunking_utils.cuh"

#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/hashing/detail/default_hash.cuh>

#include <rmm/exec_policy.hpp>

#ifdef __HIP_PLATFORM_AMD__
#include <hip/hip_cooperative_groups.h>
#else
#include <cooperative_groups.h>
#endif
#include <cuda/std/iterator>

namespace cudf::io::parquet::detail {

namespace cg = cooperative_groups;

namespace {

// # of threads we're decoding with
constexpr int preprocess_block_size   = 512;
constexpr int level_decode_block_size = 128;

using unused_state_buf = page_state_buffers_s<0, 0, 0>;

/**
// <<<<<<< OLD CODE from 0d2d7680e0 (c4f73b46d9) - COMMENTED OUT
//  * @brief Calculate string bytes for DELTA_LENGTH_BYTE_ARRAY encoded pages
//  *
//  * Operates at thread block level. Result is valid only on thread 0.
//  *
//  * @param s The local page info
//  * @param block Thread block cooperative group
//  */
// __device__ size_type delta_length_page_string_size(page_state_s* s, cg::thread_block const& block)
// {
//   if (block.thread_rank() == 0) {
//     // find the beginning of char data
//     delta_binary_decoder string_lengths;
//     auto const* string_start = string_lengths.find_end_of_block(s->data_start, s->data_end);
//     // distance is size of string data
//     return static_cast<size_type>(cuda::std::distance(string_start, s->data_end));
//   }
//   return 0;
// }
//
// /**
//  * @brief Calculate string bytes for DELTA_BYTE_ARRAY encoded pages
//  *
//  * Operates at thread block level of size preprocess_block_size.
//  *
//  * @param s The local page info
//  * @param block Thread block cooperative group
//  */
// __device__ size_type delta_page_string_size(page_state_s* s, cg::thread_block const& block)
// {
//   using WarpReduce = hipcub::WarpReduce<uleb128_t>;
//   __shared__ typename WarpReduce::TempStorage temp_storage[2];
//
//   __shared__ __align__(16) delta_binary_decoder prefixes;
//   __shared__ __align__(16) delta_binary_decoder suffixes;
//
//   auto const warp = cg::tiled_partition<cudf::detail::warp_size>(block);
//
//   if (block.thread_rank() == 0) {
//     auto const* suffix_start = prefixes.find_end_of_block(s->data_start, s->data_end);
//     suffixes.init_binary_block(suffix_start, s->data_end);
//   }
//   block.sync();
//
//   // two warps will traverse the prefixes and suffixes and sum them up
//   auto const db = warp.meta_group_rank() == 0   ? &prefixes
//                   : warp.meta_group_rank() == 1 ? &suffixes
//                                                 : nullptr;
//
//   size_t total_bytes = 0;
//   if (db != nullptr) {
//     // initialize with first value (which is stored in last_value)
//     if (warp.thread_rank() == 0) { total_bytes = db->last_value; }
//
//     uleb128_t lane_sum = 0;
//     while (db->current_value_idx < db->num_encoded_values(true)) {
//       // calculate values for current mini-block
//       db->calc_mini_block_values(warp.thread_rank());
//
//       // get per lane sum for mini-block
//       for (uint32_t i = 0; i < db->values_per_mb; i += warp.size()) {
//         uint32_t const idx = db->current_value_idx + i + warp.thread_rank();
//         // NOTE(HIP/AMD): We ensure here that only values_per_mb threads access db->value[]
//         if (idx < db->value_count && warp.thread_rank() < db->values_per_mb) {
//           lane_sum += db->value[rolling_index<delta_rolling_buf_size>(idx)];
//         }
//       }
//
//       if (warp.thread_rank() == 0) { db->setup_next_mini_block(true); }
//       // NOTE(HIP/AMD): On AMD GPUs, warp.sync() uses __builtin_amdgcn_fence(__ATOMIC_ACQ_REL, "agent")
//       // which is a heavyweight system-wide memory fence. For warp-level coordination after thread-0
//       // updates decoder state, __syncwarp() is sufficient (wavefront-scoped fence + execution barrier)
//       // and provides significantly better performance.
// #ifndef __HIP_PLATFORM_AMD__
//       warp.sync();
// #else
//       __syncwarp();
// #endif
//     }
//
//     // get sum for warp.
//     // note: warp_sum will only be valid on lane 0.
//     auto const warp_sum = WarpReduce(temp_storage[warp.meta_group_rank()]).Sum(lane_sum);
//
//     if (warp.thread_rank() == 0) { total_bytes += warp_sum; }
//   }
//   block.sync();
//
//   // now sum up total_bytes from the two warps. result is only valid on thread 0.
//   auto const final_bytes =
//     cudf::detail::single_lane_block_sum_reduce<preprocess_block_size, 0>(total_bytes);
//
//   return static_cast<size_type>(final_bytes);
// }
//
// /**
//  * @brief Calculate the number of string bytes in the page.
//  *
//  * This function expects the dictionary position to be at 0 and will traverse
//  * the entire thing (for plain and dictionary encoding).
//  *
//  * Operates at thread block level of size preprocess_block_size. Result is only
//  * valid on thread 0.
//  *
//  * @param s The local page info
//  * @param block Thread block cooperative group
//  *
//  * @return The number of string bytes in the page
//  */
// __device__ size_type decode_total_page_string_size(page_state_s* s, cg::thread_block const& block)
// {
//   auto const warp      = cg::tiled_partition<cudf::detail::warp_size>(block);
//   size_type target_pos = s->num_input_values;
//   size_type str_len    = 0;
//   switch (s->page.encoding) {
//     case Encoding::PLAIN_DICTIONARY:
//     case Encoding::RLE_DICTIONARY:
//       // Use warp 0 to decode dictionary indices and return the new target position
//       if (warp.meta_group_rank() == 0 && s->dict_base) {
//         auto const [new_target_pos, len] =
//           decode_dictionary_indices<is_calc_sizes_only::YES, unused_state_buf>(
//             s, nullptr, target_pos, warp);
//         target_pos = new_target_pos;
//         str_len    = len;
//       }
//       break;
//
//     case Encoding::PLAIN:
//       // For V2 headers, we know how many values are present, so can skip an expensive scan.
//       if ((s->page.flags & PAGEINFO_FLAGS_V2) != 0) {
//         auto const num_values = s->page.num_input_values - s->page.num_nulls;
//         str_len               = s->dict_size - sizeof(int) * num_values;
//       }
//       // For V1, the choice is an overestimate (s->dict_size), or an exact number that's
//       // expensive to compute. For now we're going with the latter.
//       else {
//         str_len = initialize_string_descriptors<is_calc_sizes_only::YES, unused_state_buf>(
//           s, nullptr, target_pos, block);
//       }
//       break;
//
//     case Encoding::DELTA_LENGTH_BYTE_ARRAY:
//       str_len = delta_length_page_string_size(s, block);
//       break;
//
//     case Encoding::DELTA_BYTE_ARRAY: str_len = delta_page_string_size(s, block); break;
//
//     default:
//       // not a valid string encoding, so just return 0
//       break;
//   }
//   if (!block.thread_rank()) { s->dict_pos = target_pos; }
//   return str_len;
// }
//
// /**
// =======
// >>>>>>> END NEW CODE (c4f73b46d9)
 * @brief Update output column sizes for every nesting level based on a batch
 * of incoming decoded definition and repetition level values.
 *
 * If bounds_set is true, computes skipped_values and skipped_leaf_values for the
 * page to indicate where we need to skip to based on min/max row.
 *
 * Operates at thread block level.
 *
 * @param s The local page info
 * @param target_value_count The target value count to process up to
 * @param rep Repetition level buffer
 * @param def Definition level buffer
 * @param bounds_set Boolean indicating whether min/max row bounds have been set
 * @param block The cooperative thread block
 */
template <typename level_t>
__device__ void update_page_sizes(page_state_s* s,
                                  int target_value_count,
                                  level_t const* const rep,
                                  level_t const* const def,
                                  bool bounds_set,
                                  cg::thread_block const& block)
{
  // max nesting depth of the column
  int const max_depth          = s->col.max_nesting_depth;
  int const t                  = block.thread_rank();
  constexpr int num_warps      = preprocess_block_size / cudf::detail::warp_size;
  constexpr int max_batch_size = num_warps * cudf::detail::warp_size;

  using block_reduce = hipcub::BlockReduce<int, preprocess_block_size>;
  using block_scan   = hipcub::BlockScan<int, preprocess_block_size>;
  __shared__ union {
    typename block_reduce::TempStorage reduce_storage;
    typename block_scan::TempStorage scan_storage;
  } temp_storage;

  // how many input level values we've processed in the page so far
  int value_count = s->input_value_count;
  // how many rows we've processed in the page so far
  int row_count = s->input_row_count;
  // how many leaf values we've processed in the page so far
  int leaf_count = s->input_leaf_count;
  // whether or not we need to continue checking for the first row
  bool skipped_values_set = s->page.skipped_values >= 0;

  while (value_count < target_value_count) {
    int const batch_size =
      cuda::std::min<int32_t>(max_batch_size, target_value_count - value_count);

    // start/end depth
    int start_depth, end_depth, d;
    get_nesting_bounds<level_t>(
      start_depth, end_depth, d, s, rep, def, value_count, value_count + batch_size, t);

    // is this thread within row bounds? in the non skip_rows/num_rows case this will always
    // be true.
    int in_row_bounds = 1;

    // if we are in the skip_rows/num_rows case, we need to check against these limits
    if (bounds_set) {
      // get absolute thread row index
      int const is_new_row = start_depth == 0;
      int thread_row_count, block_row_count;
      block_scan(temp_storage.scan_storage)
        .InclusiveSum(is_new_row, thread_row_count, block_row_count);
      block.sync();

      // get absolute thread leaf index
      int const is_new_leaf = (d >= s->nesting_info[max_depth - 1].max_def_level);
      int thread_leaf_count, block_leaf_count;
      block_scan(temp_storage.scan_storage)
        .InclusiveSum(is_new_leaf, thread_leaf_count, block_leaf_count);
      block.sync();

      // if this thread is in row bounds
      int const row_index = (thread_row_count + row_count) - 1;
      in_row_bounds =
        (row_index >= s->row_index_lower_bound) && (row_index < (s->first_row + s->num_rows));

      // if we have not set skipped values yet, see if we found the first in-bounds row
      if (!skipped_values_set) {
        int local_count, global_count;
        block_scan(temp_storage.scan_storage)
          .InclusiveSum(in_row_bounds, local_count, global_count);
        block.sync();

        // we found it
        if (global_count > 0) {
          // this is the thread that represents the first row.
          if (local_count == 1 && in_row_bounds) {
            s->page.skipped_values = value_count + t;
            s->page.skipped_leaf_values =
              leaf_count + (is_new_leaf ? thread_leaf_count - 1 : thread_leaf_count);
          }
          skipped_values_set = true;
        }
      }

      row_count += block_row_count;
      leaf_count += block_leaf_count;
    }

    // increment value counts across all nesting depths
    for (int s_idx = 0; s_idx < max_depth; s_idx++) {
      int const in_nesting_bounds = (s_idx >= start_depth && s_idx <= end_depth && in_row_bounds);
      int const count = block_reduce(temp_storage.reduce_storage).Sum(in_nesting_bounds);
      block.sync();
      if (!t) {
        PageNestingInfo* pni = &s->page.nesting[s_idx];
        pni->batch_size += count;
      }
    }

    value_count += batch_size;
  }

  // update final outputs
  if (!t) {
    s->input_value_count = value_count;

    // only used in the skip_rows/num_rows case
    s->input_leaf_count = leaf_count;
    s->input_row_count  = row_count;
  }

  block.sync();
}

/**
 * @brief Updates size information for a pruned page across all nesting levels
 *
 * @param[in,out] page The page to compute sizes for
 * @param[in] state The local page info
 * @param[in] has_repetition Whether the page has repetition
 * @param[in] is_base_pass Whether this is the base pass
 * @param[in] block The current thread block cooperative group
 */
__device__ void compute_page_sizes_for_pruned_pages(PageInfo* page,
                                                    page_state_s* const state,
                                                    bool has_repetition,
                                                    bool is_base_pass,
                                                    cg::thread_block const& block)
{
  auto const max_depth = page->num_output_nesting_levels;
  // Return early if no repetition and max depth is 1
  if (not has_repetition and max_depth == 1) {
    if (!block.thread_rank()) {
      if (is_base_pass) { page->nesting[0].size = page->num_rows; }
      page->nesting[0].batch_size = state->num_rows;
    }
    return;
  }

  // Use warp 0 to set nesting size information for all depths
  auto const warp = cg::tiled_partition<cudf::detail::warp_size>(block);
  if (warp.meta_group_rank() == 0) {
    auto list_depth = 0;
    // Find the depth of the first list
    if (has_repetition) {
      auto depth = 0;
      while (depth < max_depth) {
        auto const thread_depth = depth + warp.thread_rank();
        auto const is_list =
          thread_depth < max_depth and page->nesting[thread_depth].type == type_id::LIST;
        uint32_t const list_mask = warp.ballot(is_list);
        if (list_mask != 0) {
          auto const first_list_lane = cuda::std::countr_zero(list_mask);
          list_depth                 = warp.shfl(thread_depth, first_list_lane);
          break;
        }
        depth += warp.size();
      }
      // Zero out size information for all depths beyond the first list depth
      for (auto depth = list_depth + 1 + warp.thread_rank(); depth < max_depth;
           depth += warp.size()) {
        if (is_base_pass) { page->nesting[depth].size = 0; }
        page->nesting[depth].batch_size = 0;
      }
    }
    // Write size information for all depths up to the list depth
    for (auto depth = warp.thread_rank(); depth < list_depth; depth += warp.size()) {
      if (is_base_pass) { page->nesting[depth].size = page->num_rows; }
      page->nesting[depth].batch_size = state->num_rows;
    }
    // Write size information at the list depth (zero if no list)
    if (warp.thread_rank() == 0) {
      if (is_base_pass) { page->nesting[list_depth].size = page->num_rows; }
      page->nesting[list_depth].batch_size = state->num_rows;
    }
  }
}

/**
 * @brief Kernel for computing per-page column size information for all nesting levels.
 *
 * This function will write out the size field for each level of nesting.
 *
 * @param pages List of pages
 * @param chunks List of column chunks
 * @param min_row Row index to start reading at
 * @param num_rows Maximum number of rows to read. Pass as INT_MAX to guarantee reading all rows
 * @param is_base_pass Whether or not this is the base pass.  We first have to compute
 * the full size information of every page before we come through in a second (trim) pass
 * to determine what subset of rows in this page we should be reading
 * @param compute_string_sizes Whether or not we should be computing string sizes
 * (PageInfo::str_bytes) as part of the pass
 */
template <typename level_t>
CUDF_KERNEL void __launch_bounds__(preprocess_block_size)
  compute_page_sizes_kernel(PageInfo* pages,
                            device_span<ColumnChunkDesc const> chunks,
                            device_span<bool const> page_mask,
                            size_t min_row,
                            size_t num_rows,
                            bool is_base_pass)
{
  //extern __shared__ __align__(16) page_state_s state_g[];
  extern __shared__ page_state_s state_g[];

  page_state_s* const s = &state_g[0];
  auto const block      = cg::this_thread_block();
  // TODO(HIP/AMD): Replace cg::this_grid().block_rank() with blockIdx.x since block_rank() API is
  // currently missing in HIP cooperative groups
  int const page_idx    = blockIdx.x;
  int const t           = block.thread_rank();
  PageInfo* pp          = &pages[page_idx];

  // whether or not we have repetition levels (lists)
  bool has_repetition = chunks[pp->chunk_idx].max_level[level_type::REPETITION] > 0;

  // setup page info
  if (!setup_local_page_info(
        s, pp, chunks, min_row, num_rows, all_types_filter{}, page_processing_stage::PREPROCESS)) {
    return;
  }

  // Return early if this page is pruned
  if (not page_mask.empty() and not page_mask[page_idx]) {
    return compute_page_sizes_for_pruned_pages(pp, s, has_repetition, is_base_pass, block);
  }

  // - if this is a flat hierarchy (no lists), we don't need
  // to do the expensive work of traversing the level data to determine sizes.  we can just compute
  // it directly.
  if (!has_repetition) {
    int depth = 0;
    while (depth < s->page.num_output_nesting_levels) {
      auto const thread_depth = depth + t;
      if (thread_depth < s->page.num_output_nesting_levels) {
        if (is_base_pass) { pp->nesting[thread_depth].size = pp->num_input_values; }
        pp->nesting[thread_depth].batch_size = pp->num_input_values;
      }
      depth += block.size();
    }
    return;
  }

  // in the trim pass, for anything with lists, we only need to fully process bounding pages (those
  // at the beginning or the end of the row bounds)
  if (!is_base_pass && !is_bounds_page(s, min_row, num_rows, has_repetition)) {
    int depth = 0;
    while (depth < s->page.num_output_nesting_levels) {
      auto const thread_depth = depth + t;
      if (thread_depth < s->page.num_output_nesting_levels) {
        // if we are not a bounding page (as checked above) then we are either
        // returning all rows/values from this page, or 0 of them
        pp->nesting[thread_depth].batch_size =
          (s->num_rows == 0 && !is_page_contained(s, min_row, num_rows))
            ? 0
            : pp->nesting[thread_depth].size;
      }
      depth += block.size();
    }
    return;
  }

  // zero sizes
  int depth = 0;
  while (depth < s->page.num_output_nesting_levels) {
    auto const thread_depth = depth + t;
    if (thread_depth < s->page.num_output_nesting_levels) {
      s->page.nesting[thread_depth].batch_size = 0;
    }
    depth += blockDim.x;
  }

  auto* const rep          = reinterpret_cast<level_t*>(pp->lvl_decode_buf[level_type::REPETITION]);
  bool const process_nulls = should_process_nulls(s);
  level_t* const def       = !process_nulls
                               ? nullptr
                               : reinterpret_cast<level_t*>(pp->lvl_decode_buf[level_type::DEFINITION]);

  if (!t) {
    s->page.skipped_values      = -1;
    s->page.skipped_leaf_values = 0;
    s->input_row_count          = 0;
    s->input_value_count        = 0;

    // in the base pass, we're computing the number of rows, make sure we visit absolutely
    // everything
    if (is_base_pass) {
      s->first_row             = 0;
      s->num_rows              = std::numeric_limits<int32_t>::max();
      s->row_index_lower_bound = -1;
    }
  }

  block.sync();

  // update_page_sizes
  update_page_sizes<level_t>(s, s->page.num_input_values, rep, def, !is_base_pass, block);

  // update output results:
  // - real number of rows for the whole page
  // - nesting sizes for the whole page
  // - skipped value information for trimmed pages
  // - string bytes
  if (is_base_pass) {
    // nesting level 0 is the root column, so the size is also the # of rows
    if (!t) { pp->num_rows = s->page.nesting[0].batch_size; }

    // store off this batch size as the "full" size
    int depth = 0;
    while (depth < s->page.num_output_nesting_levels) {
      auto const thread_depth = depth + t;
      if (thread_depth < s->page.num_output_nesting_levels) {
        pp->nesting[thread_depth].size = pp->nesting[thread_depth].batch_size;
      }
      depth += block.size();
    }
  }

  if (!t) {
    pp->skipped_values      = s->page.skipped_values;
    pp->skipped_leaf_values = s->page.skipped_leaf_values;
  }
}

/**
 * @brief Kernel for preprocessing definition and repetition levels
 *
 * This kernel decodes definition and repetition levels for all pages in advance,
 * storing them in the pre-allocated level decode buffers. This allows other
 * kernels to skip RLE decoding and directly access the decoded levels.
 *
 * @param pages List of pages
 * @param chunks List of column chunks
 * @param page_mask Boolean vector indicating which pages need to be processed
 * @param min_row Minimum row index to read
 * @param num_rows Number of rows to read starting from min_row
 */
template <typename level_t, int level_decode_block_size>
CUDF_KERNEL void __launch_bounds__(level_decode_block_size)
  preprocess_levels_kernel(PageInfo* pages,
                           device_span<ColumnChunkDesc const> chunks,
                           cudf::device_span<bool const> page_mask,
                           size_t min_row,
                           size_t num_rows)
{
  __shared__ __align__(16) page_state_s state_g;

  page_state_s* const s = &state_g;
  auto const block      = cg::this_thread_block();
  int const page_idx    = cg::this_grid().block_rank();
  int const t           = block.thread_rank();
  PageInfo* pp          = &pages[page_idx];

  // Return early if this page is pruned
  if (not page_mask.empty() and not page_mask[page_idx]) { return; }

  // setup page info - use all_types_filter since we need to preprocess levels for all page types
  if (!setup_local_page_info(
        s, pp, chunks, min_row, num_rows, all_types_filter{}, page_processing_stage::PREPROCESS)) {
    return;
  }

  // whether or not we have repetition levels (lists)
  bool const has_repetition = chunks[pp->chunk_idx].max_level[level_type::REPETITION] > 0;

  // the required number of runs in shared memory we will need to provide the
  // rle_stream object
  constexpr int rle_run_buffer_size =
    rle_stream_required_run_buffer_size<level_decode_block_size>();

  // the level stream decoders. max_output_values is max to remove rolling buffer
  __shared__ rle_run def_runs[rle_run_buffer_size];
  __shared__ rle_run rep_runs[rle_run_buffer_size];
  static constexpr int max_output_values = std::numeric_limits<int>::max();
  rle_stream<level_t, level_decode_block_size, max_output_values>
    decoders[level_type::NUM_LEVEL_TYPES] = {{def_runs}, {rep_runs}};

  // Get the level decode buffers for this page
  auto* const def = reinterpret_cast<level_t*>(pp->lvl_decode_buf[level_type::DEFINITION]);
  auto* const rep = reinterpret_cast<level_t*>(pp->lvl_decode_buf[level_type::REPETITION]);

  // Determine how many values need to be decoded
  size_t const num_to_decode =
    precompute_page_num_values_in_range(*pp, chunks[pp->chunk_idx], min_row, num_rows);
  if (num_to_decode == 0) { return; }

  // Initialize the stream decoders
  bool const process_nulls = should_process_nulls(s);
  if (process_nulls) {
    decoders[level_type::DEFINITION].init(s->col.level_bits[level_type::DEFINITION],
                                          s->abs_lvl_start[level_type::DEFINITION],
                                          s->abs_lvl_end[level_type::DEFINITION],
                                          def,
                                          num_to_decode);
  }
  if (has_repetition) {
    decoders[level_type::REPETITION].init(s->col.level_bits[level_type::REPETITION],
                                          s->abs_lvl_start[level_type::REPETITION],
                                          s->abs_lvl_end[level_type::REPETITION],
                                          rep,
                                          num_to_decode);
  }
  block.sync();

  // Decode levels for this page up to the last row needed.
  // If skipping the first rows, we still need to decode their levels.
  // This is because we need to determine the number of non-null values we skipped.
  // Note that for lists we haven't computed skipped_leaf_values yet; this is used as input for
  // that.
  if (has_repetition) { decoders[level_type::REPETITION].decode_next(t, num_to_decode); }

  // Must sync as shared variables in decode_next() are shared between decoders!!
  block.sync();

  if (process_nulls) { decoders[level_type::DEFINITION].decode_next(t, num_to_decode); }
}

}  // anonymous namespace

/**
 * @copydoc cudf::io::parquet::gpu::compute_page_sizes
 */
void compute_page_sizes(cudf::detail::hostdevice_span<PageInfo> pages,
                        cudf::detail::hostdevice_span<ColumnChunkDesc const> chunks,
                        cudf::device_span<bool const> page_mask,
                        size_t min_row,
                        size_t num_rows,
                        bool compute_num_rows,
                        int level_type_size,
                        rmm::cuda_stream_view stream)
{
  CUDF_FUNC_RANGE();

  dim3 dim_block(preprocess_block_size, 1);
  dim3 dim_grid(pages.size(), 1);  // 1 threadblock per page

  // computes:
  // PageNestingInfo::size for each level of nesting, for each page.
  // This computes the size for the entire page, not taking row bounds into account.
  // If uses_custom_row_bounds is set to true, we have to do a second pass later that "trims"
  // the starting and ending read values to account for these bounds.
  if (level_type_size == 1) {
// <<<<<<< OLD CODE from 0d2d7680e0 (c4f73b46d9) - COMMENTED OUT
//     compute_page_sizes_kernel<uint8_t><<<dim_grid, dim_block, sizeof(page_state_s), stream.value()>>>(
//       pages.device_ptr(), chunks, min_row, num_rows, compute_num_rows, compute_string_sizes);
//   } else {
//     compute_page_sizes_kernel<uint16_t><<<dim_grid, dim_block, sizeof(page_state_s), stream.value()>>>(
//       pages.device_ptr(), chunks, min_row, num_rows, compute_num_rows, compute_string_sizes);
// =======
    compute_page_sizes_kernel<uint8_t><<<dim_grid, dim_block, 0, stream.value()>>>(
      pages.device_ptr(), chunks, page_mask, min_row, num_rows, compute_num_rows);
  } else {
    compute_page_sizes_kernel<uint16_t><<<dim_grid, dim_block, 0, stream.value()>>>(
// <<<<<<< OLD CODE from 929ac51935 (d71ca42e83) - COMMENTED OUT
//       pages.device_ptr(), chunks, min_row, num_rows, compute_num_rows);
// // >>>>>>> END NEW CODE (c4f73b46d9)
// =======
      pages.device_ptr(), chunks, page_mask, min_row, num_rows, compute_num_rows);
// >>>>>>> END NEW CODE (d71ca42e83)
  }
}

/**
 * @copydoc cudf::io::parquet::detail::preprocess_levels
 */
void preprocess_levels(cudf::detail::hostdevice_span<PageInfo> pages,
                       cudf::detail::hostdevice_span<ColumnChunkDesc const> chunks,
                       cudf::device_span<bool const> page_mask,
                       size_t min_row,
                       size_t num_rows,
                       int level_type_size,
                       rmm::cuda_stream_view stream)
{
  CUDF_FUNC_RANGE();

  if (pages.size() == 0) { return; }

  dim3 dim_block(level_decode_block_size, 1);
  dim3 dim_grid(pages.size(), 1);  // 1 threadblock per page

  if (level_type_size == 1) {
    preprocess_levels_kernel<uint8_t, level_decode_block_size>
      <<<dim_grid, dim_block, 0, stream.value()>>>(
        pages.device_ptr(), chunks, page_mask, min_row, num_rows);
  } else {
    preprocess_levels_kernel<uint16_t, level_decode_block_size>
      <<<dim_grid, dim_block, 0, stream.value()>>>(
        pages.device_ptr(), chunks, page_mask, min_row, num_rows);
  }
}

}  // namespace cudf::io::parquet::detail
