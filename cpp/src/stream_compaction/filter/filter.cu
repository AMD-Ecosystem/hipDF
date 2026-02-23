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
#include <cudf/null_mask.hpp>
#include <cudf/stream_compaction.hpp>
// <<<<<<< OLD CODE from 59b8f88be1 (442af46486) - COMMENTED OUT
// #include <cudf/table/table.hpp>
// #include <cudf/utilities/jit_amd_utilities.hpp>
// #include <cudf/utilities/span.hpp>
// #include <cudf/utilities/traits.hpp>
// =======
#include <cudf/transform.hpp>
// >>>>>>> END NEW CODE (442af46486)

#include <rmm/cuda_stream_view.hpp>

#include <jit/helpers.hpp>
// <<<<<<< OLD CODE from 59b8f88be1 (442af46486) - COMMENTED OUT
// #include <jit/parser.hpp>
// #include <cudf/detail/jit/span.cuh>
// #include <jit_preprocessed_files/stream_compaction/filter/jit/kernel.cu.jit.hpp>
// =======
// >>>>>>> END NEW CODE (442af46486)

#include <variant>
#include <vector>

namespace cudf {

// <<<<<<< OLD CODE from 59b8f88be1 (442af46486) - COMMENTED OUT
// namespace {
//
// void launch_filter_kernel(jitify2::ConfiguredKernel& kernel,
//                           cudf::jit::device_span<bool> output,
//                           std::vector<column_view> const& input_columns,
//                           std::optional<void*> user_data,
//                           rmm::cuda_stream_view stream,
//                           rmm::device_async_resource_ref mr)
// {
//   auto outputs = cudf::jit::to_device_vector(
//     std::vector{cudf::jit::device_optional_span<bool>{output, nullptr}}, stream, mr);
//
//   auto [input_handles, inputs] =
//     cudf::jit::column_views_to_device<column_device_view, column_view>(input_columns, stream, mr);
//
//   cudf::jit::device_optional_span<bool> const* p_outputs = outputs.data();
//   column_device_view const* p_inputs                     = inputs.data();
//   void* p_user_data                                      = user_data.value_or(nullptr);
//
// // <<<<<<< OLD CODE from a6f9f97c33 (7019418598) - COMMENTED OUT
// //   std::array<void*, 3> args{&outputs_ptr, &inputs_ptr, &p_user_data};
// //   // NOTE(HIP/AMD): Using launch() instead of launch_raw() for compatibility with
// //   // the current jitify-hip on HIP/ROCm.
// //   // TODO(HIP/AMD): Switch back to launch_raw() when supported again.
// //   kernel->launch(args.data());
// // =======
//   std::array<void*, 3> args{&p_outputs, &p_inputs, &p_user_data};
//
//   kernel->launch_raw(args.data());
// // >>>>>>> END NEW CODE (7019418598)
// }
//
// void perform_checks(column_view base_column,
//                     std::vector<column_view> const& predicate_columns,
//                     std::vector<column_view> const& filter_columns)
// {
//   auto check_columns = [&](std::vector<column_view> const& columns) {
//     CUDF_EXPECTS(std::all_of(columns.begin(),
//                              columns.end(),
//                              [](auto& input) {
//                                return is_fixed_width(input.type()) ||
//                                       (input.type().id() == type_id::STRING);
//                              }),
//                  "Filters only support fixed-width and string types",
//                  std::invalid_argument);
//
//     CUDF_EXPECTS(std::all_of(columns.begin(),
//                              columns.end(),
//                              [&](auto& input) {
//                                return cudf::jit::is_scalar(base_column.size(), input.size()) ||
//                                       (input.size() == base_column.size());
//                              }),
//                  "All filter columns must have the same size or be scalar (have size 1)",
//                  std::invalid_argument);
//   };
//
//   for (auto const& col : filter_columns) {
//     CUDF_EXPECTS(col.size() == base_column.size(),
//                  "All filter columns must have the same size",
//                  std::invalid_argument);
//   }
//
//   check_columns(predicate_columns);
//   check_columns(filter_columns);
// }
//
// // <<<<<<< OLD CODE from f8aec98e1e (d4e12e2fee) - COMMENTED OUT
// // jitify2::Kernel get_kernel(std::string const& kernel_name,
// //                            std::string const& cuda_source,
// //                            std::string const* llvm_ir = nullptr)
// // {
// // // <<<<<<< OLD CODE from dd0d19a1f1 (df596fd490) - COMMENTED OUT
// // //   const std::string arch_flag = HIP_PLATFORM_AMD ? "--offload-arch=gfx." : "-arch=sm.";
// // //   if (llvm_ir != nullptr && HIP_PLATFORM_AMD) {
// // //     return cudf::jit::get_program_cache(*stream_compaction_filter_jit_kernel_cu_jit)
// // //       .get_kernel(kernel_name,
// // //                   {},
// // //                   {{"cudf/detail/operation-udf.hpp", cuda_source}},
// // //                   {arch_flag},
// // //                   {},
// // //                   llvm_ir);
// // //   } else {
// // //     return cudf::jit::get_program_cache(*stream_compaction_filter_jit_kernel_cu_jit)
// // //       .get_kernel(kernel_name, {}, {{"cudf/detail/operation-udf.hpp", cuda_source}}, {arch_flag});
// // //   }
// // // =======
// //   CUDF_FUNC_RANGE();
// //
// //   return cudf::jit::get_program_cache(*stream_compaction_filter_jit_kernel_cu_jit)
// //     .get_kernel(kernel_name, {}, {{"cudf/detail/operation-udf.hpp", cuda_source}}, {"-arch=sm_."});
// // // >>>>>>> END NEW CODE (df596fd490)
// // }
// //
// // =======
// // >>>>>>> END NEW CODE (d4e12e2fee)
// jitify2::StringVec build_jit_template_params(
//   null_aware is_null_aware,
//   bool has_user_data,
//   std::vector<std::string> const& span_outputs,
//   std::vector<cudf::jit::input_column_reflection> const& column_inputs)
// {
//   jitify2::StringVec tparams;
//
//   tparams.emplace_back(jitify2::reflection::reflect(is_null_aware));
//   tparams.emplace_back(jitify2::reflection::reflect(has_user_data));
//
//   std::transform(thrust::counting_iterator<size_t>(0),
//                  thrust::counting_iterator(span_outputs.size()),
//                  std::back_inserter(tparams),
//                  [&](auto i) {
//                    return jitify2::reflection::Template("cudf::jit::span_accessor")
//                      .instantiate(span_outputs[i], i);
//                  });
//
//   std::transform(thrust::counting_iterator<size_t>(0),
//                  thrust::counting_iterator(column_inputs.size()),
//                  std::back_inserter(tparams),
//                  [&](auto i) { return column_inputs[i].accessor(i); });
//
//   return tparams;
// }
//
// jitify2::ConfiguredKernel build_kernel(std::string const& kernel_name,
//                                        size_type base_column_size,
//                                        std::vector<std::string> const& span_outputs,
//                                        std::vector<column_view> const& input_columns,
//                                        bool has_user_data,
//                                        null_aware is_null_aware,
//                                        std::string const& udf,
//                                        bool is_ptx,
//                                        rmm::cuda_stream_view stream,
//                                        rmm::device_async_resource_ref mr)
// {
//   CUDF_FUNC_RANGE();
//
//   CUDF_EXPECTS(!(is_null_aware == null_aware::YES && is_ptx),
//                "Optional types are not supported in PTX UDFs",
//                std::invalid_argument);
//   std::string cuda_source;
//   std::string parsed_udf_llvm_ir;
//
//   if (is_ptx && HIP_PLATFORM_AMD) {
//     // NOTE(HIPRTC): This is a workaround for Jitify issue #55
//     // For AMD HIP, we need to handle LLVM IR instead of PTX
//     auto input_types = cudf::jit::column_type_names(input_columns);
//
//     cuda_source = "using int64_t = __hip_internal::int64_t;using uint64_t = __hip_internal::uint64_t;";
//     cuda_source += "extern \"C\" __device__ void GENERIC_FILTER_OP(";
//
//     // Build function signature
//     for (size_t i = 0; i < span_outputs.size(); ++i) {
//       if (i > 0) cuda_source += ",";
//       cuda_source += span_outputs[i] + "*";
//     }
//     if (!input_types.empty()) cuda_source += ",";
//     for (size_t i = 0; i < input_types.size(); ++i) {
//       if (i > 0) cuda_source += ",";
//       cuda_source += input_types[i];
//     }
//     if (has_user_data) cuda_source += ",void*";
//     cuda_source += ");";
//
//     parsed_udf_llvm_ir = cudf::jit::parse_single_function_llvm_ir(udf, "GENERIC_FILTER_OP");
//     parsed_udf_llvm_ir = cudf::adapt_llvm_ir_attributes_for_current_arch(parsed_udf_llvm_ir);
//
//   } else {
//     cuda_source =
//       is_ptx ? cudf::jit::parse_single_function_ptx(
//                  udf,
//                  "GENERIC_FILTER_OP",
//                  cudf::jit::build_ptx_params(
//                    span_outputs, cudf::jit::column_type_names(input_columns), has_user_data))
//              : cudf::jit::parse_single_function_cuda(udf, "GENERIC_FILTER_OP");
//   }
//
// // <<<<<<< OLD CODE from f8aec98e1e (d4e12e2fee) - COMMENTED OUT
// //   return get_kernel(jitify2::reflection::Template(kernel_name)
// //                       .instantiate(build_jit_template_params(
// //                         is_null_aware,
// //                         has_user_data,
// //                         span_outputs,
// //                         cudf::jit::reflect_input_columns(base_column_size, input_columns))),
// //                     cuda_source,
// //                     (is_ptx && HIP_PLATFORM_AMD) ? &parsed_udf_llvm_ir : nullptr)
// // =======
//   auto kernel_reflection = jitify2::reflection::Template(kernel_name)
//                              .instantiate(build_jit_template_params(
//                                is_null_aware,
//                                has_user_data,
//                                span_outputs,
//                                cudf::jit::reflect_input_columns(base_column_size, input_columns)));
//
//   return cudf::jit::get_udf_kernel(
//            *stream_compaction_filter_jit_kernel_cu_jit, kernel_reflection, cuda_source)
// // >>>>>>> END NEW CODE (d4e12e2fee)
//     ->configure_1d_max_occupancy(0, 0, nullptr, stream.value());
// }
//
// std::vector<std::unique_ptr<column>> filter_operation(
//   column_view base_column,
//   std::vector<column_view> const& predicate_columns,
// =======
namespace detail {
std::vector<std::unique_ptr<column>> filter(
  std::span<std::variant<column_view, scalar_column_view> const> predicate_inputs,
// >>>>>>> END NEW CODE (442af46486)
  std::string const& predicate_udf,
  std::vector<column_view> const& filter_columns,
  bool is_ptx,
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
                                            is_ptx,
                                            user_data,
                                            is_null_aware,
                                            row_size,
                                            predicate_nullability,
                                            stream,
                                            mr);

  return apply_boolean_mask(cudf::table_view{filter_columns}, predicate->view(), stream, mr)
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
                                                      args.is_ptx,
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
  bool is_ptx,
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
                        is_ptx,
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
  auto base_column = jit::get_transform_base_column(predicate_columns);
  for (auto const& col : predicate_columns) {
    if (jit::is_scalar(base_column->size(), col.size())) {
      inputs.emplace_back(scalar_column_view{col});
    } else {
      inputs.emplace_back(col);
    }
  }

  return detail::filter(inputs,
                        predicate_udf,
                        filter_columns,
                        is_ptx,
                        user_data,
                        is_null_aware,
                        predicate_nullability,
                        stream,
                        mr);
}

}  // namespace cudf
