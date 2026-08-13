/*
 * SPDX-FileCopyrightText: Copyright (c) 2023-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

// MIT License
//
// Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

#include "compression.hpp"

#include <cudf/utilities/memory_resource.hpp>

#include <rmm/exec_policy.hpp>

#include <cuda/functional>
#include <cuda/std/tuple>
#include <thrust/transform_reduce.h>

namespace cudf::io::detail {

writer_compression_statistics collect_compression_statistics(
  device_span<device_span<uint8_t const> const> inputs,
  device_span<codec_exec_result const> results,
  rmm::cuda_stream_view stream)
{
  // bytes_written on success
  auto const output_size_successful = thrust::transform_reduce(
    rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
    results.begin(),
    results.end(),
    cuda::proclaim_return_type<size_t>([] __device__(codec_exec_result const& res) {
      return res.status == codec_status::SUCCESS ? res.bytes_written : 0;
    }),
    0ul,
    cuda::std::plus<size_t>());

  auto input_size_with_status = [inputs, results, stream](codec_status status) {
    auto const zipped_begin =
      thrust::make_zip_iterator(inputs.begin(), results.begin());
    auto const zipped_end = zipped_begin + inputs.size();

    return thrust::transform_reduce(
      rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
      zipped_begin,
      zipped_end,
      cuda::proclaim_return_type<size_t>([status] __device__(auto tup) {
        // FIXME(HIP/AMD, <ROCTHRUST-TUPLE>): rocThrust zip dereference is a thrust::tuple; use
        // thrust::get.
        return thrust::get<1>(tup).status == status ? thrust::get<0>(tup).size() : 0;
      }),
      0ul,
      cuda::std::plus<size_t>());
  };

  return writer_compression_statistics{input_size_with_status(codec_status::SUCCESS),
                                       input_size_with_status(codec_status::FAILURE),
                                       input_size_with_status(codec_status::SKIPPED),
                                       output_size_successful};
}

}  // namespace cudf::io::detail
