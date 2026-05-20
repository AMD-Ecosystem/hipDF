/*
 * SPDX-FileCopyrightText: Copyright (c) 2021-2026, NVIDIA CORPORATION.
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

#include "join_common_utils.cuh"
#include "join_common_utils.hpp"

#include <cudf/detail/algorithms/copy_if.cuh>
#include <cudf/detail/utilities/cuda_memcpy.hpp>
#include <cudf/detail/utilities/vector_factories.hpp>
#include <cudf/join/join.hpp>
#include <cudf/table/table_view.hpp>
#include <cudf/types.hpp>
#include <cudf/utilities/error.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>
#include <rmm/resource_ref.hpp>

#include <cuda/iterator>
#include <cuda/std/functional>
#include <cuda/std/iterator>
#include <cuda/std/tuple>
#include <thrust/iterator/transform_output_iterator.h>
#include <thrust/iterator/zip_iterator.h>
#include <thrust/scatter.h>
#include <thrust/sequence.h>
#include <thrust/uninitialized_fill.h>

#include <cstdint>
#include <memory>
#include <vector>

namespace cudf {
namespace detail {

VectorPair get_trivial_left_join_indices(table_view const& left,
                                         rmm::cuda_stream_view stream,
                                         rmm::device_async_resource_ref mr)
{
  auto left_indices = std::make_unique<rmm::device_uvector<size_type>>(left.num_rows(), stream, mr);
  thrust::sequence(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                   left_indices->begin(),
                   left_indices->end(),
                   0);
  auto right_indices =
    std::make_unique<rmm::device_uvector<size_type>>(left.num_rows(), stream, mr);
  thrust::uninitialized_fill(
    rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
    right_indices->begin(),
    right_indices->end(),
    cudf::JoinNoMatch);
  return std::pair(std::move(left_indices), std::move(right_indices));
}

namespace {

// Predicate: right row `idx` is unmatched iff its flag slot is zero.
// We use an int32 flag (one per right row) rather than a packed bit or a byte: byte stores
// from a dense 32-wide scatter don't coalesce into full-word transactions, which costs 2–3×
// in the mark kernel for skewed left/right ratios.
struct unmatched_flag {
  size_type const* flags;
  __device__ bool operator()(size_type idx) const noexcept { return flags[idx] == 0; }
};

// Transform a selected (unmatched) right index into a (JoinNoMatch, idx) pair that is stored
// through a zip iterator over (left_out_tail, right_out_tail).
struct to_no_match_pair {
  __device__ cuda::std::tuple<size_type, size_type> operator()(size_type idx) const noexcept
  {
    return cuda::std::make_tuple(cudf::JoinNoMatch, idx);
  }
};

}  // namespace

VectorPair finalize_full_join(VectorPair&& indices,
                              size_type left_table_num_rows,
                              size_type right_table_num_rows,
                              rmm::cuda_stream_view stream,
                              rmm::device_async_resource_ref mr)
{
  auto [left_out, right_out] = std::move(indices);
  CUDF_EXPECTS(left_out->size() == right_out->size(),
               "left/right index vectors must have equal size",
               std::invalid_argument);
  auto const match_total = left_out->size();

  // Empty-left fast path: every right row is unmatched.
  if (left_table_num_rows == 0) {
    auto const tail = static_cast<std::size_t>(right_table_num_rows);
    left_out->resize(match_total + tail, stream);
    right_out->resize(match_total + tail, stream);
    thrust::sequence(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                     right_out->begin() + match_total,
                     right_out->end(),
                     0);
    thrust::uninitialized_fill(
      rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
// <<<<<<< OLD CODE from 857435871d (1a9b0efc1a) - COMMENTED OUT
//       invalid_index_map->begin(),
//       invalid_index_map->end(),
//       int32_t{1});
//
//     // Functor to check for index validity since left joins can create invalid indices
//     valid_range<size_type> valid(0, right_table_row_count);
//
//     // invalid_index_map[index_ptr[i]] = 0 for i = 0 to right_table_row_count
//     // Thus specifying that those locations are valid
//     thrust::scatter_if(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
//                        cuda::make_constant_iterator(0),
//                        cuda::make_constant_iterator(0) + right_indices->size(),
//                        right_indices->begin(),      // Index locations
//                        right_indices->begin(),      // Stencil - Check if index location is valid
//                        invalid_index_map->begin(),  // Output indices
//                        valid);                      // Stencil Predicate
//     size_type begin_counter = static_cast<size_type>(0);
//     size_type end_counter   = static_cast<size_type>(right_table_row_count);
//
//     // Create list of indices that have been marked as invalid
// // <<<<<<< OLD CODE from 842ab4d885 (43f2f2dac5) - COMMENTED OUT
// // // <<<<<<< OLD CODE from ae65a9466f (820f9f7c3f) - COMMENTED OUT
// // //     // NOTE(HIP/AMD): ROCm 7.2.x and lower has a const-correctness issue where cuda::std::identity
// // //     // returns 'const bool&' from its operator() when the input is a prvalue bool. When used
// // //     // with transform_iterator<cuda::std::identity, bool*> in thrust::copy_if, rocPRIM's select
// // //     // tries to bind this 'const bool&' to a non-const reference ('bool&'), causing a compilation
// // //     // error: "binding reference of type 'bool' to value of type 'const bool' drops 'const'
// // //     // qualifier". The workaround is to use thrust::identity which returns a plain bool value.
// // // #if defined(__HIP_PLATFORM_AMD__) && defined(HIP_VERSION_MAJOR) && \
// // //     ((HIP_VERSION_MAJOR < 7) || (HIP_VERSION_MAJOR == 7 && HIP_VERSION_MINOR <= 12))
// // //     size_type indices_count = thrust::copy_if(rmm::exec_policy(stream),
// // //                                               thrust::make_counting_iterator(begin_counter),
// // //                                               thrust::make_counting_iterator(end_counter),
// // //                                               invalid_index_map->begin(),
// // //                                               right_indices_complement->begin(),
// // //                                               thrust::identity<size_type>()) -
// // //                               right_indices_complement->begin();
// // //     right_indices_complement->resize(indices_count, stream);
// // // #else
// // //     size_type indices_count = thrust::copy_if(rmm::exec_policy(stream),
// // // =======
// //     size_type indices_count = thrust::copy_if(rmm::exec_policy_nosync(stream),
// // // <<<<<<< OLD CODE from 8414047bb1 (4b19041ca0) - COMMENTED OUT
// // // // >>>>>>> END NEW CODE (820f9f7c3f)
// // //                                               thrust::make_counting_iterator(begin_counter),
// // //                                               thrust::make_counting_iterator(end_counter),
// // // =======
// //                                               cuda::counting_iterator{begin_counter},
// //                                               cuda::counting_iterator{end_counter},
// // // >>>>>>> END NEW CODE (4b19041ca0)
// //                                               invalid_index_map->begin(),
// //                                               right_indices_complement->begin(),
// //                                               cuda::std::identity{}) -
// //                               right_indices_complement->begin();
// // =======
//     size_type indices_count =
//       thrust::copy_if(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
//                       cuda::counting_iterator{begin_counter},
//                       cuda::counting_iterator{end_counter},
//                       invalid_index_map->begin(),
//                       right_indices_complement->begin(),
//                       cuda::std::identity{}) -
//       right_indices_complement->begin();
// // >>>>>>> END NEW CODE (43f2f2dac5)
//     right_indices_complement->resize(indices_count, stream);
// #endif
// =======
      left_out->begin() + match_total,
      left_out->end(),
      cudf::JoinNoMatch);
    return std::pair(std::move(left_out), std::move(right_out));
// >>>>>>> END NEW CODE (1a9b0efc1a)
  }

  if (right_table_num_rows == 0) { return std::pair(std::move(left_out), std::move(right_out)); }

  // Grow to the upper bound (match_total + right_table_num_rows); the complement is appended
  // into the tail. If the caller pre-reserved this capacity (see the span overload below),
  // these resizes don't reallocate.
  auto const upper = match_total + static_cast<std::size_t>(right_table_num_rows);
  left_out->resize(upper, stream);
  right_out->resize(upper, stream);

  // Mark matched right rows in an int32 flag array (one word per right row). Redundant stores
  // of the same value are idempotent, so no atomics are needed. Word-sized stores coalesce into
  // full 128-byte transactions per warp; byte-sized flags cost ~2–3× here because partial-word
  // stores from dense scatters serialize within each 32-bit sector.
  auto flags = cudf::detail::make_zeroed_device_uvector_async<size_type>(
    right_table_num_rows, stream, cudf::get_current_device_resource_ref());

  thrust::scatter_if(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                     cuda::make_constant_iterator(size_type{1}),
                     cuda::make_constant_iterator(size_type{1}) + match_total,
                     right_out->begin(),
                     right_out->begin(),
                     flags.begin(),
                     valid_range<size_type>{0, right_table_num_rows});

  // Fused compaction: for each unmatched right row, emit (JoinNoMatch, right_idx) into
  // (left_out_tail, right_out_tail) in a single CUB DeviceSelect pass.
  auto zip_tail =
    thrust::make_zip_iterator(left_out->data() + match_total, right_out->data() + match_total);
  auto out_iter = thrust::make_transform_output_iterator(zip_tail, to_no_match_pair{});

  auto const new_end =
    cudf::detail::copy_if(cuda::counting_iterator<size_type>{0},
                          cuda::counting_iterator<size_type>{right_table_num_rows},
                          out_iter,
                          unmatched_flag{flags.data()},
                          stream);

  auto const comp_size = cuda::std::distance(out_iter, new_end);
  left_out->resize(match_total + comp_size, stream);
  right_out->resize(match_total + comp_size, stream);

  return std::pair(std::move(left_out), std::move(right_out));
}

VectorPair finalize_full_join(
  cudf::host_span<cudf::device_span<size_type const> const> left_partials,
  cudf::host_span<cudf::device_span<size_type const> const> right_partials,
  size_type left_table_num_rows,
  size_type right_table_num_rows,
  rmm::cuda_stream_view stream,
  rmm::device_async_resource_ref mr)
{
  CUDF_EXPECTS(left_partials.size() == right_partials.size(),
               "left_partials and right_partials must have the same length",
               std::invalid_argument);

  std::size_t match_total = 0;
  for (std::size_t i = 0; i < left_partials.size(); ++i) {
    CUDF_EXPECTS(left_partials[i].size() == right_partials[i].size(),
                 "matching partials must have equal left/right sizes",
                 std::invalid_argument);
    match_total += left_partials[i].size();
  }

  // Pre-allocate at the upper bound so the VectorPair overload's resize-up becomes a no-op
  // (capacity is already there).
  auto const upper = match_total + static_cast<std::size_t>(right_table_num_rows);
  auto left_out    = std::make_unique<rmm::device_uvector<size_type>>(upper, stream, mr);
  auto right_out   = std::make_unique<rmm::device_uvector<size_type>>(upper, stream, mr);

  // Concatenate every partial into the head of the output via one batched memcpy.
  if (match_total > 0) {
    auto const n = left_partials.size();
    std::vector<void*> dsts;
    std::vector<void const*> srcs;
    std::vector<std::size_t> sizes;
    dsts.reserve(2 * n);
    srcs.reserve(2 * n);
    sizes.reserve(2 * n);
    std::size_t offset = 0;
    for (std::size_t i = 0; i < n; ++i) {
      auto const sz = left_partials[i].size() * sizeof(size_type);
      dsts.push_back(left_out->data() + offset);
      srcs.push_back(left_partials[i].data());
      sizes.push_back(sz);
      dsts.push_back(right_out->data() + offset);
      srcs.push_back(right_partials[i].data());
      sizes.push_back(sz);
      offset += left_partials[i].size();
    }
    CUDF_CUDA_TRY(cudf::detail::memcpy_batch_async(
      dsts.data(), srcs.data(), sizes.data(), dsts.size(), stream));
  }

  // Shrink the uvectors' logical size to match_total (capacity stays at upper bound), then
  // delegate to the VectorPair overload which resizes back up and appends the complement.
  left_out->resize(match_total, stream);
  right_out->resize(match_total, stream);

  return finalize_full_join(std::pair(std::move(left_out), std::move(right_out)),
                            left_table_num_rows,
                            right_table_num_rows,
                            stream,
                            mr);
}

}  // namespace detail
}  // namespace cudf
