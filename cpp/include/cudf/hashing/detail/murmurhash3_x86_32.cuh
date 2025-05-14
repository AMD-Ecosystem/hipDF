/*
 * Copyright (c) 2017-2025, NVIDIA CORPORATION.
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

#include <cudf/fixed_point/fixed_point.hpp>
#include <cudf/hashing.hpp>
#include <cudf/hashing/detail/hash_functions.cuh>
#include <cudf/lists/list_view.hpp>
#include <cudf/strings/string_view.cuh>
#include <cudf/structs/struct_view.hpp>
#include <cudf/types.hpp>

#include <cuco/hash_functions.cuh>
#include <cuda/std/cstddef>

namespace cudf::hashing::detail {

template <typename Key>
struct MurmurHash3_x86_32 {
  using result_type = hash_value_type;

  CUDF_HOST_DEVICE constexpr MurmurHash3_x86_32(uint32_t seed = cudf::DEFAULT_HASH_SEED)
    : _impl{seed}
  {
  }

  // FIXME(HIP/AMD): Cannot use constexpr here due to internal issue 254
  __device__ /*constexpr*/ result_type operator()(Key const& key) const { return this->_impl(key); }

  __device__ constexpr result_type compute_bytes(cuda::std::byte const* bytes,
                                                 std::uint64_t size) const
  {
    return this->_impl.compute_hash(bytes, size);
  }

 private:
  template <typename T>
  __device__ constexpr result_type compute(T const& key) const
  {
    return this->compute_bytes(reinterpret_cast<cuda::std::byte const*>(&key), sizeof(T));
  }

  cuco::murmurhash3_32<Key> _impl;
};

template <>
MurmurHash3_x86_32<bool>::result_type __device__ inline MurmurHash3_x86_32<bool>::operator()(
  bool const& key) const
{
  return this->compute(static_cast<uint8_t>(key));
}

template <>
MurmurHash3_x86_32<float>::result_type __device__ inline MurmurHash3_x86_32<float>::operator()(
  float const& key) const
{
  return this->compute(normalize_nans_and_zeros(key));
}

template <>
MurmurHash3_x86_32<double>::result_type __device__ inline MurmurHash3_x86_32<double>::operator()(
  double const& key) const
{
  return this->compute(normalize_nans_and_zeros(key));
}

template <>
MurmurHash3_x86_32<cudf::string_view>::result_type
  __device__ inline MurmurHash3_x86_32<cudf::string_view>::
  operator()(cudf::string_view const& key) const
{
  return this->compute_bytes(reinterpret_cast<cuda::std::byte const*>(key.data()),
                             key.size_bytes());
}

template <>
MurmurHash3_x86_32<numeric::decimal32>::result_type
  __device__ inline MurmurHash3_x86_32<numeric::decimal32>::
  operator()(numeric::decimal32 const& key) const
{
  return this->compute(key.value());
}

template <>
MurmurHash3_x86_32<numeric::decimal64>::result_type
  __device__ inline MurmurHash3_x86_32<numeric::decimal64>::
  operator()(numeric::decimal64 const& key) const
{
  return this->compute(key.value());
}

template <>
MurmurHash3_x86_32<numeric::decimal128>::result_type
  __device__ inline MurmurHash3_x86_32<numeric::decimal128>::
  operator()(numeric::decimal128 const& key) const
{
  return this->compute(key.value());
}

template <>
MurmurHash3_x86_32<cudf::list_view>::result_type
  __device__ inline MurmurHash3_x86_32<cudf::list_view>::
  operator()(cudf::list_view const& key) const
{
  CUDF_UNREACHABLE("List column hashing is not supported");
}

template <>
MurmurHash3_x86_32<cudf::struct_view>::result_type
  __device__ inline MurmurHash3_x86_32<cudf::struct_view>::
  operator()(cudf::struct_view const& key) const
{
  CUDF_UNREACHABLE("Direct hashing of struct_view is not supported");
}

}  // namespace cudf::hashing::detail
