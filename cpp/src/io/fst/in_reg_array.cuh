/*
 * SPDX-FileCopyrightText: Copyright (c) 2022-2025, NVIDIA CORPORATION.
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

#include <cudf/detail/utilities/integer_utils.hpp>
#include <cudf/types.hpp>

#include <hipcub/hipcub.hpp>

#include <cstdint>

namespace cudf::io::fst::detail {

/**
 * @brief A bit-packed array of items that can be backed by registers yet allows to be dynamically
 * addressed at runtime. The data structure is explained in greater detail in the paper <a
 * href="http://www.vldb.org/pvldb/vol13/p616-stehle.pdf">ParPaRaw: Massively Parallel Parsing of
 * Delimiter-Separated Raw Data</a>.
 *
 * @tparam NUM_ITEMS The maximum number of items this data structure is supposed to store
 * @tparam MAX_ITEM_VALUE The maximum value that one item can represent
 * @tparam BackingFragmentT The data type that is holding the fragments
 */
template <uint32_t NUM_ITEMS, uint32_t MAX_ITEM_VALUE, typename BackingFragmentT = uint32_t>
class MultiFragmentInRegArray {
 private:
  /// Minimum number of bits required to represent all values from [0, MAX_ITEM_VALUE]
  static constexpr uint32_t MIN_BITS_PER_ITEM =
    (MAX_ITEM_VALUE == 0) ? 1 : hipcub::Log2<(MAX_ITEM_VALUE + 1)>::VALUE;

  /// Number of bits that each fragment can store
  static constexpr uint32_t NUM_BITS_PER_FRAGMENT = sizeof(BackingFragmentT) * 8;

  /// The number of bits per fragment per item in the array
  static constexpr uint32_t AVAIL_BITS_PER_FRAG_ITEM = NUM_BITS_PER_FRAGMENT / NUM_ITEMS;

  /// The number of bits per item per fragment to be a power of two to avoid costly integer
  /// multiplication
  static constexpr uint32_t BITS_PER_FRAG_ITEM =
    0x01U << (hipcub::Log2<(AVAIL_BITS_PER_FRAG_ITEM + 1)>::VALUE - 1);

  // The total number of fragments required to store all the items
  static constexpr uint32_t FRAGMENTS_PER_ITEM =
    cudf::util::div_rounding_up_safe(MIN_BITS_PER_ITEM, BITS_PER_FRAG_ITEM);

  //------------------------------------------------------------------------------
  // HELPER FUNCTIONS
  //------------------------------------------------------------------------------
  /**
   * @brief Returns the \p num_bits bits starting at \p bit_start
   */
  // TODO(HIP/AMD): removed [[nodiscard]] for now
  CUDF_HOST_DEVICE uint32_t bfe(uint32_t const& data,
                                              uint32_t bit_start,
                                              uint32_t num_bits) const
  {
    uint32_t const MASK = (1 << num_bits) - 1;
    return (data >> bit_start) & MASK;
  }

  /**
   * @brief Replaces the \p num_bits bits in \p data starting from \p bit_start with the lower \p
   * num_bits from \p bits.
   */
  CUDF_HOST_DEVICE void bfi(uint32_t& data,
                            uint32_t bits,
                            uint32_t bit_start,
                            uint32_t num_bits) const
  {
    uint32_t x      = bits << bit_start;
    uint32_t y      = data;
    uint32_t MASK_X = ((1 << num_bits) - 1) << bit_start;
    uint32_t MASK_Y = ~MASK_X;
    data            = (y & MASK_Y) | (x & MASK_X);
  }

  BackingFragmentT data[FRAGMENTS_PER_ITEM];

  //------------------------------------------------------------------------------
  // ACCESSORS
  //------------------------------------------------------------------------------
 public:
 // TODO(HIP/AMD): removed [[nodiscard]] for now
  CUDF_HOST_DEVICE uint32_t Get(int32_t index) const
  {
    uint32_t val = 0;

    for (uint32_t i = 0; i < FRAGMENTS_PER_ITEM; ++i) {
      val = val | bfe(data[i], index * BITS_PER_FRAG_ITEM, BITS_PER_FRAG_ITEM)
                    << (i * BITS_PER_FRAG_ITEM);
    }
    return val;
  }

  CUDF_HOST_DEVICE void Set(uint32_t index, uint32_t value)
  {
    for (uint32_t i = 0; i < FRAGMENTS_PER_ITEM; ++i) {
      uint32_t frag_bits = bfe(value, i * BITS_PER_FRAG_ITEM, BITS_PER_FRAG_ITEM);
      bfi(data[i], frag_bits, index * BITS_PER_FRAG_ITEM, BITS_PER_FRAG_ITEM);
    }
  }

  //------------------------------------------------------------------------------
  // CONSTRUCTORS
  //------------------------------------------------------------------------------
  CUDF_HOST_DEVICE MultiFragmentInRegArray()
  {
    for (uint32_t i = 0; i < FRAGMENTS_PER_ITEM; ++i) {
      data[i] = 0;
    }
  }

  CUDF_HOST_DEVICE MultiFragmentInRegArray(uint32_t const (&array)[NUM_ITEMS])
  {
    for (uint32_t i = 0; i < NUM_ITEMS; ++i) {
      Set(i, array[i]);
    }
  }
};

}  // namespace cudf::io::fst::detail
