/*
 * SPDX-FileCopyrightText: Copyright (c) 2022-2026, NVIDIA CORPORATION.
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

#pragma once

#include <cudf/ast/detail/expression_evaluator.cuh>
#include <cudf/detail/cuco_helpers.hpp>
#include <cudf/detail/row_operator/equality.cuh>
#include <cudf/detail/row_operator/hashing.cuh>
#include <cudf/hashing/detail/murmurhash3_x86_32.cuh>
#include <cudf/join/join.hpp>
#include <cudf/types.hpp>
#include <cudf/utilities/span.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/mr/polymorphic_allocator.hpp>

#include <cuco/static_multiset.cuh>

namespace cudf::detail {

using pair_type = cuco::pair<hash_value_type, size_type>;

using hash_type = cuco::murmurhash3_32<hash_value_type>;

/**
 * @brief A custom comparator used for the mixed join multiset insertion
 */
struct mixed_join_always_not_equal {
  __device__ constexpr bool operator()(pair_type const&, pair_type const&) const noexcept
  {
    return false;
  }
};

/**
 * @brief Hash functions for double hashing in mixed joins.
 *
 * These hashers implement a double hashing scheme for the mixed join multiset:
 *
 * - mixed_join_hasher1: Determines the initial probe slot for a given key. We simply use
 *   the precomputed row hash value, which is the first element of our (row_hash, row_index) pair.
 *
 * - mixed_join_hasher2: Determines the step size for the probing sequence. This allows keys
 *   with the same hash value to have different step sizes, helping to avoid secondary clustering.
 *
 * Note: Strictly speaking, this setup does not truly avoid secondary clustering because rows with
 * the same hash value still receive the same step size. A true secondary clustering avoidance
 * method would compute a different hash value for each row. However, based on performance testing,
 * this current approach actually delivers better performance than computing row hashes with a
 * different hasher.
 */
struct mixed_join_hasher1 {
  __device__ constexpr hash_value_type operator()(pair_type const& key) const noexcept
  {
    return key.first;
  }
};

struct mixed_join_hasher2 {
  mixed_join_hasher2(hash_value_type seed) : _hash{seed} {}

  __device__ constexpr hash_value_type operator()(pair_type const& key) const noexcept
  {
    return _hash(key.first);
  }

 private:
  hash_type _hash;
};

using mixed_multiset_type =
  cuco::static_multiset<pair_type,
                        cuco::extent<std::size_t>,
                        cuda::thread_scope_device,
                        mixed_join_always_not_equal,
                        cuco::double_hashing<1, mixed_join_hasher1, mixed_join_hasher2>,
                        rmm::mr::polymorphic_allocator<char>,
                        cuco::storage<2>>;

using row_hash = cudf::detail::row::hash::device_row_hasher<cudf::hashing::detail::default_hash,
                                                            cudf::nullate::DYNAMIC>;

// // This alias is used by mixed_joins, which support only non-nested types
using row_equality = cudf::detail::row::equality::strong_index_comparator_adapter<
  cudf::detail::row::equality::device_row_comparator<false, cudf::nullate::DYNAMIC>>;

/**
 * @brief Base equality comparator for use with cuco set/multiset methods that require expression
 * evaluation.
 *
 * This class provides the common interface and attributes needed for equality
 * comparators that combine row equality checks with conditional expression evaluation.
 * It stores the expression evaluator, thread-local storage, table swap flag, and
 * the row equality comparator used for non-conditional equality checks.
 */
template <bool has_nulls>
struct expression_equality {
  __device__ expression_equality(
    cudf::ast::detail::expression_evaluator<has_nulls> const& evaluator,
    cudf::ast::detail::IntermediateDataType<has_nulls>* thread_intermediate_storage,
    bool const swap_tables,
    row_equality const& equality_probe)
    : evaluator{evaluator},
      thread_intermediate_storage{thread_intermediate_storage},
      swap_tables{swap_tables},
      equality_probe{equality_probe}
  {
  }

  cudf::ast::detail::IntermediateDataType<has_nulls>* thread_intermediate_storage;
  cudf::ast::detail::expression_evaluator<has_nulls> const& evaluator;
  bool const swap_tables;
  row_equality const& equality_probe;
};

/**
 * @brief Equality comparator for cuco::static_multiset queries.
 *
 * This equality comparator is designed for use with cuco::static_multiset's APIs.
 * A probe hit indicates that the hashes of the keys are equal, at which point
 * this comparator checks whether the keys themselves are equal (using the
 * provided row_equality comparator) and then evaluates the conditional expression
 */
template <bool has_nulls>
struct pair_expression_equality : public expression_equality<has_nulls> {
  using expression_equality<has_nulls>::expression_equality;

  __device__ __forceinline__ bool operator()(pair_type const& left_row,
                                             pair_type const& right_row) const noexcept
  {
    using cudf::detail::row::lhs_index_type;
    using cudf::detail::row::rhs_index_type;

    auto output_dest = cudf::ast::detail::value_expression_result<bool, has_nulls>();
    // Three levels of checks:
    // 1. Row hashes of the columns involved in the equality condition are equal.
    // 2. The contents of the columns involved in the equality condition are equal.
    // 3. The predicate evaluated on the relevant columns (already encoded in the evaluator)
    // evaluates to true.
    if ((left_row.first == right_row.first) &&
        this->equality_probe(lhs_index_type{left_row.second}, rhs_index_type{right_row.second})) {
      auto const lrow_idx = this->swap_tables ? right_row.second : left_row.second;
      auto const rrow_idx = this->swap_tables ? left_row.second : right_row.second;
      this->evaluator.evaluate(
        output_dest, lrow_idx, rrow_idx, 0, this->thread_intermediate_storage);
      return (output_dest.is_valid() && output_dest.value());
    }
    return false;
  }
};

/**
 * @brief Common utility for probing a hash table bucket and checking slot equality
 *
 * This encapsulates the common logic of reading bucket slots and checking for
 * empty slots and key equality, used by both count and retrieve operations.
 */
template <bool has_nulls>
struct hash_probe_result {
  bool first_slot_is_empty_;
  bool second_slot_is_empty_;
  bool first_slot_equals_;
  bool second_slot_equals_;

  __device__ __forceinline__ hash_probe_result(
    pair_expression_equality<has_nulls> const& key_equal,
    cudf::device_span<cuco::pair<hash_value_type, cudf::size_type>> hash_table_storage,
    cuco::pair<hash_value_type, cudf::size_type> const& probe_key,
    std::size_t probe_idx)
  {
    // NOTE(HIP/AMD): upstream discards the result of `__builtin_assume_aligned`, which makes
    // `-Wunused-value` an error under the HIP toolchain's -Werror. Consuming the result is both
    // warning-free and strictly more correct: verified on ROCm 7.14 that the discarded form still
    // emits `llvm.assume ["align"(ptr, 16)]` under clang (so simply deleting the call loses the
    // alignment fact), while this form emits the identical assume.
    using slot_type   = cuco::pair<hash_value_type, cudf::size_type>;
    auto const* data  = static_cast<slot_type const*>(
      __builtin_assume_aligned(hash_table_storage.data(), 2 * sizeof(slot_type)));
    auto const first  = *(data + probe_idx);
    auto const second = *(data + probe_idx + 1);

    first_slot_is_empty_  = first.second == cudf::JoinNoMatch;
    second_slot_is_empty_ = second.second == cudf::JoinNoMatch;
    first_slot_equals_    = (not first_slot_is_empty_ and key_equal(probe_key, first));
    second_slot_equals_   = (not second_slot_is_empty_ and key_equal(probe_key, second));
  }

  __device__ __forceinline__ bool has_empty_slot() const noexcept
  {
    return first_slot_is_empty_ or second_slot_is_empty_;
  }

  __device__ __forceinline__ cudf::size_type match_count() const noexcept
  {
    return static_cast<cudf::size_type>(first_slot_equals_) +
           static_cast<cudf::size_type>(second_slot_equals_);
  }

  __device__ __forceinline__ bool has_match() const noexcept
  {
    return first_slot_equals_ or second_slot_equals_;
  }
};

/**
 * @brief Iterator-style wrapper for probing through a hash table
 *
 * This encapsulates the common double hashing probe sequence used by both
 * count and retrieve kernels.
 */
template <bool has_nulls>
struct hash_table_prober {
  cudf::device_span<cuco::pair<hash_value_type, cudf::size_type>> hash_table_storage_;
  pair_expression_equality<has_nulls> const& key_equal_;
  cuco::pair<hash_value_type, cudf::size_type> const& probe_key_;
  std::size_t probe_idx_;
  std::size_t step_;
  std::size_t extent_;

  __device__ __forceinline__ hash_table_prober(
    pair_expression_equality<has_nulls> const& key_equal,
    cudf::device_span<cuco::pair<hash_value_type, cudf::size_type>> hash_table_storage,
    cuco::pair<hash_value_type, cudf::size_type> const& probe_key,
    cuda::std::pair<hash_value_type, hash_value_type> const& hash_idx)
    : hash_table_storage_{hash_table_storage},
      key_equal_{key_equal},
      probe_key_{probe_key},
      probe_idx_{static_cast<std::size_t>(hash_idx.first)},
      step_{static_cast<std::size_t>(hash_idx.second)},
      extent_{hash_table_storage.size()}
  {
  }

  __device__ __forceinline__ hash_probe_result<has_nulls> probe_current_bucket() const
  {
    return hash_probe_result<has_nulls>{key_equal_, hash_table_storage_, probe_key_, probe_idx_};
  }

  __device__ __forceinline__ void advance() noexcept
  {
    probe_idx_ = (probe_idx_ + step_) % extent_;
  }

  __device__ __forceinline__ auto get_bucket_slots() const noexcept
  {
    // NOTE(HIP/AMD): see hash_probe_result's ctor - consume the __builtin_assume_aligned result
    // rather than discarding it (upstream form is a -Wunused-value error under -Werror here).
    using slot_type   = cuco::pair<hash_value_type, cudf::size_type>;
    auto const* data  = static_cast<slot_type const*>(
      __builtin_assume_aligned(hash_table_storage_.data(), 2 * sizeof(slot_type)));
    auto const first  = *(data + probe_idx_);
    auto const second = *(data + probe_idx_ + 1);
    return cuda::std::pair{first, second};
  }
};

}  // namespace cudf::detail
