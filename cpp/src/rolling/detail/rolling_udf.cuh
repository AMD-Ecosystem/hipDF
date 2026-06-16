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

#pragma once

#include "jit/cache.hpp"
#include "jit/helpers.hpp"
#include "jit/parser.hpp"
#include "jit/util.hpp"
#include "rolling.hpp"

#include <cudf/detail/rolling/rolling_jit.hpp>

#include <cudf/aggregation.hpp>
#include <cudf/column/column_factories.hpp>
#include <cudf/column/column_view.hpp>
#include <cudf/detail/aggregation/aggregation.hpp>
#include <cudf/types.hpp>
#include <cudf/utilities/error.hpp>

#include <rmm/cuda_stream_view.hpp>

#include <jit_preprocessed_files/rolling/jit/kernel.cu.jit.hpp>

#include <memory>

namespace cudf {
namespace detail {

// Applies a user-defined rolling window function to the values in a column.
template <typename PrecedingWindowIterator, typename FollowingWindowIterator>
std::unique_ptr<column> rolling_window_udf(column_view const& input,
                                           PrecedingWindowIterator preceding_window,
                                           std::string const& preceding_window_str,
                                           FollowingWindowIterator following_window,
                                           std::string const& following_window_str,
                                           size_type min_periods,
                                           rolling_aggregation const& agg,
                                           rmm::cuda_stream_view stream,
                                           rmm::device_async_resource_ref mr)
{
  static_assert(warp_size == cudf::detail::size_in_bits<cudf::bitmask_type>(),
                "bitmask_type size does not match CUDA warp size");

  if (input.has_nulls()) {
    CUDF_FAIL("Currently the UDF version of rolling window does NOT support inputs with nulls.");
  }

  min_periods = std::max(min_periods, 0);

  auto& udf_agg = dynamic_cast<udf_aggregation const&>(agg);

  std::string hash = "prog_rolling." + std::to_string(std::hash<std::string>{}(udf_agg._source));

  std::unique_ptr<column> output = make_numeric_column(
    udf_agg._output_type, input.size(), cudf::mask_state::UNINITIALIZED, stream, mr);

  auto output_view = output->mutable_view();
  cudf::detail::device_scalar<size_type> device_valid_count{
    0, stream, cudf::get_current_device_resource_ref()};

  std::string cuda_source;
  [[maybe_unused]] std::string parsed_udf_llvm_ir;

  switch (udf_agg.kind) {
    case aggregation::Kind::PTX:
      if constexpr (HIP_PLATFORM_AMD) {
        // NOTE(HIPRTC): This is a workaround for Jitify issue #55.
        // NOTE(HIP/AMD): the kernel (rolling/jit/kernel.cu) calls GENERIC_ROLLING_OP, which is the
        // UDF function name (udf_agg._function_name == "GENERIC_ROLLING_OP"). The forward
        // declaration and the linked LLVM IR must use that same name, otherwise HIPRTC fails with
        // "use of undeclared identifier 'GENERIC_ROLLING_OP'". Mirror the transform PTX path.
        cuda_source = std::string("using int64_t = __hip_internal::int64_t;using uint64_t = __hip_internal::uint64_t;")
             + "extern \"C\" __device__ void " + udf_agg._function_name + "("
             + cudf::type_to_name(output->type()) + "*,"
             + "void*, void*, long long, long long, "
             + "const " + cudf::type_to_name(input.type()) + "*,"
             + "long long, long long);";

        parsed_udf_llvm_ir = cudf::jit::parse_single_function_llvm_ir(udf_agg._source,
                                                                      udf_agg._function_name);
        parsed_udf_llvm_ir = cudf::adapt_llvm_ir_attributes_for_current_arch(parsed_udf_llvm_ir);
      }
      else {
        cuda_source += cudf::jit::parse_single_function_ptx(udf_agg._source,
                                                            udf_agg._function_name,
							    {{0, cudf::type_to_name(udf_agg._output_type) + " *"},
                                                             {5, "void const *"}});  // args 0 and 5 are pointers
      }
      break;
    case aggregation::Kind::CUDA:
      // NOTE(HIPRTC): This is a workaround for Jitify issue #55
      cuda_source += std::string("using int64_t = __hip_internal::int64_t;using uint64_t = __hip_internal::uint64_t;");
      cuda_source += cudf::jit::parse_single_function_cuda(udf_agg._source, udf_agg._function_name);
      break;
    default: CUDF_FAIL("Unsupported UDF type.");
  }

  //: TODO(HIP/AMD): use type_to_name once hipRTC has been fixed
  std::string kernel_reflection =
    jitify2::reflection::Template("cudf::rolling::jit::gpu_rolling_new")  //
      .instantiate(cudf::type_to_name(input.type()),  // list of template arguments
                   cudf::type_to_name(output->type()),
                   udf_agg._operator_name,
                   preceding_window_str.c_str(),
                   following_window_str.c_str());

  // NOTE(HIP/AMD): on AMD forward the arch-adapted LLVM IR (only set for the PTX UDF kind)
  // so it is linked into the rolling kernel as extra bitcode; get_udf_kernel also emits
  // --offload-arch=gfx. on AMD. On NVIDIA / CUDA-kind UDFs no LLVM IR is passed.
  std::string const* udf_llvm_ir =
    (HIP_PLATFORM_AMD && !parsed_udf_llvm_ir.empty()) ? &parsed_udf_llvm_ir : nullptr;

  cudf::jit::get_udf_kernel(
    *rolling_jit_kernel_cu_jit, kernel_reflection, cuda_source, {}, udf_llvm_ir)
    ->configure_1d_max_occupancy(0, 0, nullptr, stream.value())
    ->launch(input.size(),
             cudf::jit::get_data_ptr(input),
             input.null_mask(),
             cudf::jit::get_data_ptr(output_view),
             output_view.null_mask(),
             device_valid_count.data(),
             preceding_window,
             following_window,
             min_periods);

  output->set_null_count(output->size() - device_valid_count.value(stream));

  // check the stream for debugging
  CUDF_CHECK_CUDA(stream.value());

  return output;
}

}  // namespace detail
}  // namespace cudf
