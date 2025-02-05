/*
 * Copyright (c) 2019-2025, NVIDIA CORPORATION.
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

#include "jit/cache.hpp"
#include "jit/parser.hpp"
#include "jit/util.hpp"

#include <cudf/column/column.hpp>
#include <cudf/column/column_factories.hpp>
#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/transform.hpp>
#include <cudf/null_mask.hpp>
#include <cudf/utilities/default_stream.hpp>
#include <cudf/utilities/jit_amd_utilities.hpp>
#include <cudf/utilities/traits.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <rmm/cuda_stream_view.hpp>

#include <jit_preprocessed_files/transform/jit/kernel.cu.jit.hpp>

namespace cudf {
namespace transformation {
namespace jit {
namespace {
void unary_operation(mutable_column_view output,
                     column_view input,
                     std::string const& udf,
                     data_type output_type,
                     bool is_ptx,
                     rmm::cuda_stream_view stream)
{
  std::string const kernel_name =
    jitify2::reflection::Template("cudf::transformation::jit::kernel")  //
      .instantiate(cudf::type_to_name(output.type()),  // list of template arguments
                   cudf::type_to_name(input.type()));

  std::string cuda_source; 
  std::string parsed_udf_llvm_ir;
  
  if(is_ptx && HIP_PLATFORM_AMD) {
    // NOTE(HIPRTC): This is a workaround for Jitify issue #55
    cuda_source = std::string("using int64_t = __hip_internal::int64_t;using uint64_t = __hip_internal::uint64_t;")
                + "extern \"C\" __device__ void GENERIC_UNARY_OP(" 
                + cudf::type_to_name(output.type()) +"*"
                + ","
                + cudf::type_to_name(input.type())
                + ");";
    parsed_udf_llvm_ir = cudf::jit::parse_single_function_llvm_ir(udf, "GENERIC_UNARY_OP");
    parsed_udf_llvm_ir = cudf::adapt_llvm_ir_attributes_for_current_arch(parsed_udf_llvm_ir);
  }
  else if(is_ptx && !HIP_PLATFORM_AMD) {
    cuda_source = cudf::jit::parse_single_function_ptx(
                              udf,  //
                              "GENERIC_UNARY_OP",
                              {
                                {0, "void *"},                         // output argument
                                {1, cudf::type_to_name(input.type())}  // input argument
                              });
  }
  else { 
    cuda_source = cudf::jit::parse_single_function_cuda(udf,  //
                                                   "GENERIC_UNARY_OP");
  }

  std::string architecture_string = HIP_PLATFORM_AMD ? "--offload-arch=gfx." : "-arch=sm.";
  jitify2::Kernel kernel;   

  if(is_ptx) {
    if constexpr(HIP_PLATFORM_AMD) {
      kernel = cudf::jit::get_program_cache(*transform_jit_kernel_cu_jit)
        .get_kernel(
          kernel_name, {}, {{"transform/jit/operation-udf.hpp", cuda_source}}, {architecture_string}, {}, &parsed_udf_llvm_ir); 
    }
    else {
      kernel = cudf::jit::get_program_cache(*transform_jit_kernel_cu_jit)
        .get_kernel(
          kernel_name, {}, {{"transform/jit/operation-udf.hpp", cuda_source}}, {architecture_string});
    }
  }
  else {
    kernel = cudf::jit::get_program_cache(*transform_jit_kernel_cu_jit)
      .get_kernel(
        kernel_name, {}, {{"transform/jit/operation-udf.hpp", cuda_source}}, {architecture_string}); 
  }
  kernel->configure_1d_max_occupancy(0, 0, nullptr, stream.value())                                   //
        ->launch(output.size(),                                                                 //
              cudf::jit::get_data_ptr(output),
              cudf::jit::get_data_ptr(input));    
}

}  // namespace
}  // namespace jit
}  // namespace transformation

namespace detail {
std::unique_ptr<column> transform(column_view const& input,
                                  std::string const& unary_udf,
                                  data_type output_type,
                                  bool is_ptx,
                                  rmm::cuda_stream_view stream,
                                  rmm::device_async_resource_ref mr)
{
  CUDF_EXPECTS(is_fixed_width(input.type()), "Unexpected non-fixed-width type.");

  std::unique_ptr<column> output = make_fixed_width_column(
    output_type, input.size(), copy_bitmask(input, stream, mr), input.null_count(), stream, mr);

  if (input.is_empty()) { return output; }

  mutable_column_view const output_view = *output;

  // transform
  transformation::jit::unary_operation(output_view, input, unary_udf, output_type, is_ptx, stream);

  return output;
}

}  // namespace detail

std::unique_ptr<column> transform(column_view const& input,
                                  std::string const& unary_udf,
                                  data_type output_type,
                                  bool is_ptx,
                                  rmm::cuda_stream_view stream,
                                  rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::transform(input, unary_udf, output_type, is_ptx, stream, mr);
}

}  // namespace cudf
