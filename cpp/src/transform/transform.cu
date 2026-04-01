/*
 * SPDX-FileCopyrightText: Copyright (c) 2019-2026, NVIDIA CORPORATION.
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

#include <cudf/column/column.hpp>
#include <cudf/column/column_device_view.cuh>
#include <cudf/column/column_factories.hpp>
#include <cudf/detail/null_mask.hpp>
#include <cudf/detail/nvtx/ranges.hpp>
#include <cudf/detail/transform.hpp>
#include <cudf/detail/valid_if.cuh>
#include <cudf/null_mask.hpp>
#include <cudf/stream_compaction.hpp>
#include <cudf/utilities/jit_amd_utilities.hpp>
#include <cudf/utilities/traits.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <rmm/cuda_stream_view.hpp>

#include <cuda/iterator>

#include <jit/cache.hpp>
#include <jit/helpers.hpp>
#include <jit/parser.hpp>
#include <jit/row_ir.hpp>
#include <cudf/detail/jit/span.cuh>
#include <jit/util.hpp>
#include <jit_preprocessed_files/transform/jit/kernel.cu.jit.hpp>

#include <span>
#include <variant>

namespace cudf {
using InputsView = std::span<std::variant<column_view, scalar_column_view> const>;

namespace transformation {

namespace jit {
namespace {

// <<<<<<< OLD CODE from 59b8f88be1 (442af46486) - COMMENTED OUT
// // <<<<<<< OLD CODE from f8aec98e1e (d4e12e2fee) - COMMENTED OUT
// // jitify2::Kernel get_kernel(std::string const& kernel_name,
// //                            std::string const& cuda_source,
// //                            std::string const* llvm_ir = nullptr)
// // {
// // // <<<<<<< OLD CODE from dd0d19a1f1 (df596fd490) - COMMENTED OUT
// // //   const std::string arch_flag = HIP_PLATFORM_AMD ? "--offload-arch=gfx." : "-arch=sm.";
// // //   if (llvm_ir != nullptr && HIP_PLATFORM_AMD) {
// // //     return cudf::jit::get_program_cache(*transform_jit_kernel_cu_jit)
// // //       .get_kernel(kernel_name,
// // //                   {},
// // //                   {{"cudf/detail/operation-udf.hpp", cuda_source}},
// // //                   {arch_flag},
// // //                   {},
// // //                   llvm_ir);
// // //   } else {
// // //     return cudf::jit::get_program_cache(*transform_jit_kernel_cu_jit)
// // //       .get_kernel(kernel_name, {}, {{"cudf/detail/operation-udf.hpp", cuda_source}}, {arch_flag});
// // //   }
// // // =======
// //   CUDF_FUNC_RANGE();
// //   return cudf::jit::get_program_cache(*transform_jit_kernel_cu_jit)
// //     .get_kernel(kernel_name, {}, {{"cudf/detail/operation-udf.hpp", cuda_source}}, {"-arch=sm_."});
// // // >>>>>>> END NEW CODE (df596fd490)
// // }
// //
// // =======
// // >>>>>>> END NEW CODE (d4e12e2fee)
// jitify2::StringVec build_jit_template_params(
//   null_aware is_null_aware,
//   bool may_evaluate_null,
//   bool has_user_data,
//   std::vector<std::string> const& span_outputs,
//   std::vector<std::string> const& column_outputs,
//   std::vector<cudf::jit::input_column_reflection> const& column_inputs)
// =======
jitify2::StringVec build_jit_template_params(null_aware is_null_aware,
                                             bool may_evaluate_null,
                                             bool has_user_data,
                                             std::span<std::string const> span_outputs,
                                             std::span<std::string const> column_outputs,
                                             std::span<cudf::jit::input_reflection const> inputs)
// >>>>>>> END NEW CODE (442af46486)
{
  jitify2::StringVec tparams;

  tparams.emplace_back(jitify2::reflection::reflect(is_null_aware));
  tparams.emplace_back(jitify2::reflection::reflect(may_evaluate_null));
  tparams.emplace_back(jitify2::reflection::reflect(has_user_data));

  std::transform(cuda::counting_iterator<std::size_t>{0},
                 cuda::counting_iterator{span_outputs.size()},
                 std::back_inserter(tparams),
                 [&](auto i) {
                   return jitify2::reflection::Template("cudf::jit::span_accessor")
                     .instantiate(span_outputs[i], i);
                 });

  std::transform(cuda::counting_iterator<std::size_t>{0},
                 cuda::counting_iterator{column_outputs.size()},
                 std::back_inserter(tparams),
                 [&](auto i) {
                   return jitify2::reflection::Template("cudf::jit::column_accessor")
                     .instantiate(column_outputs[i], i);
                 });

  std::transform(cuda::counting_iterator<std::size_t>{0},
                 cuda::counting_iterator{inputs.size()},
                 std::back_inserter(tparams),
                 [&](auto i) { return inputs[i].accessor(i); });

  return tparams;
}

jitify2::ConfiguredKernel build_transform_kernel(
  std::string_view kernel_name,
  std::span<mutable_column_view const> output_columns,
  InputsView inputs,
  null_aware is_null_aware,
  bool may_evaluate_null,
  bool has_user_data,
  std::string const& udf,
  cudf::udf_source_type source_type,
  rmm::cuda_stream_view stream,
  rmm::device_async_resource_ref mr)
{
// <<<<<<< OLD CODE from 59b8f88be1 (442af46486) - COMMENTED OUT
//   std::string cuda_source;
//   std::string parsed_udf_llvm_ir;
//
//   if (is_ptx && HIP_PLATFORM_AMD) {
//     // NOTE(HIPRTC): This is a workaround for Jitify issue #55
//     // For AMD HIP, we need to handle LLVM IR instead of PTX
//     auto output_types = cudf::jit::column_type_names(output_columns);
//     auto input_types  = cudf::jit::column_type_names(input_columns);
//
//     cuda_source = "using int64_t = __hip_internal::int64_t;using uint64_t = __hip_internal::uint64_t;";
//     cuda_source += "extern \"C\" __device__ void GENERIC_TRANSFORM_OP(";
//
//     // Build function signature
//     for (size_t i = 0; i < output_types.size(); ++i) {
//       if (i > 0) cuda_source += ",";
//       cuda_source += output_types[i] + "*";
//     }
//     if (!input_types.empty()) cuda_source += ",";
//     for (size_t i = 0; i < input_types.size(); ++i) {
//       if (i > 0) cuda_source += ",";
//       cuda_source += input_types[i];
//     }
//     if (has_user_data) cuda_source += ",void*";
//     cuda_source += ");";
//
//     parsed_udf_llvm_ir = cudf::jit::parse_single_function_llvm_ir(udf, "GENERIC_TRANSFORM_OP");
//     parsed_udf_llvm_ir = cudf::adapt_llvm_ir_attributes_for_current_arch(parsed_udf_llvm_ir);
//
//   } else {
//     cuda_source =
//       is_ptx ? cudf::jit::parse_single_function_ptx(
//                  udf,
//                  "GENERIC_TRANSFORM_OP",
//                  cudf::jit::build_ptx_params(cudf::jit::column_type_names(output_columns),
//                                              cudf::jit::column_type_names(input_columns),
//                                              has_user_data))
//              : cudf::jit::parse_single_function_cuda(udf, "GENERIC_TRANSFORM_OP");
//   }
//
// // <<<<<<< OLD CODE from f8aec98e1e (d4e12e2fee) - COMMENTED OUT
// //   return get_kernel(jitify2::reflection::Template(kernel_name)
// //                       .instantiate(build_jit_template_params(
// //                         is_null_aware,
// //                         may_evaluate_null,
// //                         has_user_data,
// //                         {},
// //                         cudf::jit::column_type_names(output_columns),
// //                         cudf::jit::reflect_input_columns(base_column_size, input_columns))),
// //                     cuda_source,
// //                     (is_ptx && HIP_PLATFORM_AMD) ? &parsed_udf_llvm_ir : nullptr)
// // =======
//   auto kernel_reflection = jitify2::reflection::Template(kernel_name)
//                              .instantiate(build_jit_template_params(
//                                is_null_aware,
//                                may_evaluate_null,
//                                has_user_data,
//                                {},
//                                cudf::jit::column_type_names(output_columns),
//                                cudf::jit::reflect_input_columns(base_column_size, input_columns)));
// =======
  auto output_typenames  = cudf::jit::output_type_names(output_columns);
  auto input_typenames   = cudf::jit::input_type_names(inputs);
  auto input_reflections = cudf::jit::reflect_inputs(inputs);

  auto const cuda_source =
    (source_type == cudf::udf_source_type::PTX)
      ? cudf::jit::parse_single_function_ptx(
          udf,
          "GENERIC_TRANSFORM_OP",
          cudf::jit::build_ptx_params(output_typenames, input_typenames, has_user_data))
      : cudf::jit::parse_single_function_cuda(udf, "GENERIC_TRANSFORM_OP");

  auto kernel_reflection =
    jitify2::reflection::Template(kernel_name)
      .instantiate(build_jit_template_params(
        is_null_aware, may_evaluate_null, has_user_data, {}, output_typenames, input_reflections));
// >>>>>>> END NEW CODE (442af46486)

  return cudf::jit::get_udf_kernel(*transform_jit_kernel_cu_jit, kernel_reflection, cuda_source)
// >>>>>>> END NEW CODE (d4e12e2fee)
    ->configure_1d_max_occupancy(0, 0, nullptr, stream.value());
}

jitify2::ConfiguredKernel build_span_kernel(std::string_view kernel_name,
                                            std::span<std::string const> span_outputs,
                                            InputsView inputs,
                                            null_aware is_null_aware,
                                            bool may_evaluate_null,
                                            bool has_user_data,
                                            std::string const& udf,
                                            cudf::udf_source_type source_type,
                                            rmm::cuda_stream_view stream,
                                            rmm::device_async_resource_ref mr)
{
// <<<<<<< OLD CODE from dd0d19a1f1 (df596fd490) - COMMENTED OUT
//   std::string cuda_source;
//   std::string parsed_udf_llvm_ir;
//
//   if (is_ptx && HIP_PLATFORM_AMD) {
//     // NOTE(HIPRTC): This is a workaround for Jitify issue #55
//     // For AMD HIP, we need to handle LLVM IR instead of PTX
//     auto input_types = cudf::jit::column_type_names(input_columns);
//
//     cuda_source = "using int64_t = __hip_internal::int64_t;using uint64_t = __hip_internal::uint64_t;";
//     cuda_source += "extern \"C\" __device__ void GENERIC_TRANSFORM_OP(";
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
//     parsed_udf_llvm_ir = cudf::jit::parse_single_function_llvm_ir(udf, "GENERIC_TRANSFORM_OP");
//     parsed_udf_llvm_ir = cudf::adapt_llvm_ir_attributes_for_current_arch(parsed_udf_llvm_ir);
//
//   } else {
//     cuda_source =
//       is_ptx ? cudf::jit::parse_single_function_ptx(
//                  udf,
//                  "GENERIC_TRANSFORM_OP",
//                  cudf::jit::build_ptx_params(
//                    span_outputs, cudf::jit::column_type_names(input_columns), has_user_data))
//              : cudf::jit::parse_single_function_cuda(udf, "GENERIC_TRANSFORM_OP");
//   }
// =======
  CUDF_FUNC_RANGE();
  auto output_typenames  = span_outputs;
  auto input_typenames   = cudf::jit::input_type_names(inputs);
  auto input_reflections = cudf::jit::reflect_inputs(inputs);

  auto const cuda_source =
// <<<<<<< OLD CODE from 6a900b7215 (924d3073fb) - COMMENTED OUT
//     is_ptx ? cudf::jit::parse_single_function_ptx(
//                udf,
//                "GENERIC_TRANSFORM_OP",
//                cudf::jit::build_ptx_params(output_typenames, input_typenames, has_user_data))
//            : cudf::jit::parse_single_function_cuda(udf, "GENERIC_TRANSFORM_OP");
// // <<<<<<< OLD CODE from 59b8f88be1 (442af46486) - COMMENTED OUT
// // // >>>>>>> END NEW CODE (df596fd490)
// //
// // // <<<<<<< OLD CODE from f8aec98e1e (d4e12e2fee) - COMMENTED OUT
// // //   return get_kernel(jitify2::reflection::Template(kernel_name)
// // //                       .instantiate(build_jit_template_params(
// // //                         is_null_aware,
// // //                         may_evaluate_null,
// // //                         has_user_data,
// // //                         span_outputs,
// // //                         {},
// // //                         cudf::jit::reflect_input_columns(base_column_size, input_columns))),
// // //                     cuda_source,
// // //                     (is_ptx && HIP_PLATFORM_AMD) ? &parsed_udf_llvm_ir : nullptr)
// // // =======
// //   auto kernel_reflection = jitify2::reflection::Template(kernel_name)
// //                              .instantiate(build_jit_template_params(
// //                                is_null_aware,
// //                                may_evaluate_null,
// //                                has_user_data,
// //                                span_outputs,
// //                                {},
// //                                cudf::jit::reflect_input_columns(base_column_size, input_columns)));
// // =======
// =======
    (source_type == cudf::udf_source_type::PTX)
      ? cudf::jit::parse_single_function_ptx(
          udf,
          "GENERIC_TRANSFORM_OP",
          cudf::jit::build_ptx_params(output_typenames, input_typenames, has_user_data))
      : cudf::jit::parse_single_function_cuda(udf, "GENERIC_TRANSFORM_OP");
// >>>>>>> END NEW CODE (924d3073fb)

  auto kernel_reflection =
    jitify2::reflection::Template(kernel_name)
      .instantiate(build_jit_template_params(
        is_null_aware, may_evaluate_null, has_user_data, span_outputs, {}, input_reflections));
// >>>>>>> END NEW CODE (442af46486)

  return cudf::jit::get_udf_kernel(*transform_jit_kernel_cu_jit, kernel_reflection, cuda_source)
// >>>>>>> END NEW CODE (d4e12e2fee)
    ->configure_1d_max_occupancy(0, 0, nullptr, stream.value());
}

column_view to_column_view(column_view const& col) { return col; }

column_view to_column_view(scalar_column_view const& scalar) { return scalar.as_column_view(); }

auto to_device_input_arg(InputsView inputs,
                         rmm::cuda_stream_view stream,
                         rmm::device_async_resource_ref mr)
{
  std::vector<column_view> columns;

  for (auto const& input : inputs) {
    columns.emplace_back(std::visit([](auto const& col) { return to_column_view(col); }, input));
  }

  return cudf::jit::column_views_to_device<column_device_view, column_view>(columns, stream, mr);
}

auto to_device_output_arg(std::span<mutable_column_view const> outputs,
                          rmm::cuda_stream_view stream,
                          rmm::device_async_resource_ref mr)
{
  return cudf::jit::column_views_to_device<mutable_column_device_view, mutable_column_view>(
    outputs, stream, mr);
}

void launch_column_output_kernel(jitify2::ConfiguredKernel& kernel,
                                 std::span<mutable_column_view const> output_columns,
                                 InputsView inputs,
                                 std::optional<bool*> intermediate_null_mask,
                                 std::optional<void*> user_data,
                                 rmm::cuda_stream_view stream,
                                 rmm::device_async_resource_ref mr)
{
  auto [output_arg_handles, output_args] = to_device_output_arg(output_columns, stream, mr);
  auto [input_arg_handles, input_args]   = to_device_input_arg(inputs, stream, mr);

  mutable_column_device_view const* p_outputs = output_args.data();
  column_device_view const* p_inputs          = input_args.data();
  bool* p_intermediate_null_mask              = intermediate_null_mask.value_or(nullptr);
  void* p_user_data                           = user_data.value_or(nullptr);

  std::array<void*, 4> args{&p_outputs, &p_inputs, &p_intermediate_null_mask, &p_user_data};

  // NOTE(HIP/AMD): Using launch() instead of launch_raw() for compatibility with
  // the current jitify-hip on HIP/ROCm.
  // TODO(HIP/AMD): Switch back to launch_raw() when supported again.
  kernel->launch(args.data());
}

template <typename T>
void launch_span_kernel(jitify2::ConfiguredKernel& kernel,
                        cudf::jit::device_optional_span<T> const& output,
                        InputsView inputs,
                        std::optional<bool*> intermediate_null_mask,
                        std::optional<void*> user_data,
                        rmm::cuda_stream_view stream,
                        rmm::device_async_resource_ref mr)
{
  auto output_args = cudf::jit::to_device_vector(std::vector{output}, stream, mr);

  auto [input_arg_handles, input_args] = to_device_input_arg(inputs, stream, mr);

  cudf::jit::device_optional_span<T> const* p_outputs = output_args.data();
  column_device_view const* p_inputs                  = input_args.data();
  bool* p_intermediate_null_mask                      = intermediate_null_mask.value_or(nullptr);
  void* p_user_data                                   = user_data.value_or(nullptr);

  std::array<void*, 4> args{&p_outputs, &p_inputs, &p_intermediate_null_mask, &p_user_data};

  // NOTE(HIP/AMD): Using launch() instead of launch_raw() for compatibility with
  // the current jitify-hip on HIP/ROCm.
  // TODO(HIP/AMD): Switch back to launch_raw() when supported again.
  kernel->launch(args.data());
}

std::tuple<rmm::device_buffer, size_type> and_null_mask(size_type row_size,
                                                        InputsView inputs,
                                                        rmm::cuda_stream_view stream,
                                                        rmm::device_async_resource_ref mr)
{
  // collect the non-scalar elements that contribute to the resulting bitmask
  std::vector<column_view> bitmask_columns;

  // to handle null masks for scalars, we just check if the scalar element is null. If it is null,
  // then all the rows of the transform output will be null. This helps us prevent creating
  // column-sized bitmasks for each scalar.
  for (auto const& in : inputs) {
    if (std::holds_alternative<scalar_column_view>(in)) {
      auto& scalar = std::get<scalar_column_view>(in);
      // all nulls
      if (scalar.has_nulls()) {
        return std::make_tuple(create_null_mask(row_size, mask_state::ALL_NULL, stream, mr),
                               row_size);
      }
    } else {
      auto& col = std::get<column_view>(in);
      bitmask_columns.emplace_back(col);
    }
  }

  if (bitmask_columns.empty()) {
    // if there are no non-scalar columns contributing to the null-mask, then the output is all
    // valid (scalar projection) given that the scalar is not null (checked above)
    return std::make_tuple(create_null_mask(row_size, mask_state::ALL_VALID, stream, mr), 0);
  }

  return cudf::bitmask_and(table_view{bitmask_columns}, stream, mr);
}

bool may_evaluate_null(InputsView inputs, null_aware is_null_aware, output_nullability null_out)
{
  // null-aware UDFs will evaluate nulls unless explicitly marked as not producing nulls
  if (is_null_aware == null_aware::YES) {
    return null_out != output_nullability::ALL_VALID;
  } else {
    /// null-unaware UDFs will evaluate nulls if any input is nullable unless explicitly marked
    /// as not producing nulls
    bool any_nullable = std::any_of(inputs.begin(), inputs.end(), [](auto const& input) {
      return std::visit([](auto const& col) { return col.nullable(); }, input);
    });
    return any_nullable && null_out == output_nullability::PRESERVE;
  }
}

std::unique_ptr<column> transform_operation(size_type row_size,
                                            InputsView inputs,
                                            std::string const& udf,
                                            data_type output_type,
                                            cudf::udf_source_type source_type,
                                            std::optional<void*> user_data,
                                            null_aware is_null_aware,
                                            output_nullability null_policy,
                                            rmm::cuda_stream_view stream,
                                            rmm::device_async_resource_ref mr)
{
  auto output =
    make_fixed_width_column(output_type, row_size, cudf::mask_state::UNALLOCATED, stream, mr);

  auto may_return_nulls = may_evaluate_null(inputs, is_null_aware, null_policy);

  std::optional<rmm::device_uvector<bool>> intermediate_null_mask = std::nullopt;

  if (is_null_aware == null_aware::NO) {
    if (may_return_nulls) {
      auto [and_mask_buffer, and_mask_null_count] = and_null_mask(row_size, inputs, stream, mr);
      output->set_null_mask(std::move(and_mask_buffer), and_mask_null_count);
    }
  } else if (is_null_aware == null_aware::YES) {
    if (may_return_nulls) { intermediate_null_mask.emplace(row_size, stream, mr); }
  }

  mutable_column_view outputs[] = {{*output}};
  auto kernel                   = build_transform_kernel(is_fixed_point(output_type)
                                         ? "cudf::transformation::jit::fixed_point_kernel"
                                         : "cudf::transformation::jit::kernel",
                                       outputs,
                                       inputs,
                                       is_null_aware,
                                       may_return_nulls,
                                       user_data.has_value(),
                                       udf,
                                       source_type,
                                       stream,
                                       mr);

  launch_column_output_kernel(kernel,
                              outputs,
                              inputs,
                              intermediate_null_mask.has_value()
                                ? std::optional<bool*>(intermediate_null_mask->data())
                                : std::nullopt,
                              user_data,
                              stream,
                              mr);

  if (intermediate_null_mask.has_value()) {
    auto [null_mask, null_count] = detail::valid_if(
      intermediate_null_mask->begin(),
      intermediate_null_mask->end(),
      [] __device__(bool element) { return element; },
      stream,
      mr);

    output->set_null_mask(std::move(null_mask), null_count);
  }

  return output;
}

std::unique_ptr<column> string_view_operation(size_type row_size,
                                              InputsView inputs,
                                              std::string const& udf,
                                              data_type output_type,
                                              cudf::udf_source_type source_type,
                                              std::optional<void*> user_data,
                                              null_aware is_null_aware,
                                              output_nullability null_policy,
                                              rmm::cuda_stream_view stream,
                                              rmm::device_async_resource_ref mr)
{
  rmm::device_uvector<string_view> string_views(row_size, stream, mr);

  auto may_return_nulls = may_evaluate_null(inputs, is_null_aware, null_policy);

  std::optional<rmm::device_uvector<bool>> intermediate_null_mask   = std::nullopt;
  std::optional<std::tuple<rmm::device_buffer, size_type>> and_mask = std::nullopt;

  if (is_null_aware == null_aware::NO) {
    if (may_return_nulls) { and_mask = and_null_mask(row_size, inputs, stream, mr); }
  } else if (is_null_aware == null_aware::YES) {
    if (may_return_nulls) { intermediate_null_mask.emplace(row_size, stream, mr); }
  }

  auto output_span = cudf::jit::device_optional_span<string_view>{
    cudf::jit::device_span<string_view>{string_views.data(), string_views.size()},
    and_mask.has_value() ? static_cast<bitmask_type*>(std::get<0>(*and_mask).data()) : nullptr};

  std::string output_typenames[] = {"cudf::string_view"};

  auto kernel = build_span_kernel("cudf::transformation::jit::span_kernel",
                                  output_typenames,
                                  inputs,
                                  is_null_aware,
                                  may_return_nulls,
                                  user_data.has_value(),
                                  udf,
                                  source_type,
                                  stream,
                                  mr);

  launch_span_kernel<string_view>(kernel,
                                  output_span,
                                  inputs,
                                  intermediate_null_mask.has_value()
                                    ? std::optional<bool*>(intermediate_null_mask->data())
                                    : std::nullopt,
                                  user_data,
                                  stream,
                                  mr);

  auto output = make_strings_column(string_views, cudf::string_view{}, stream, mr);

  if (and_mask.has_value()) {
    auto [and_mask_buffer, and_mask_null_count] = std::move(*and_mask);
    output->set_null_mask(std::move(and_mask_buffer), and_mask_null_count);
  } else if (intermediate_null_mask.has_value()) {
    auto [null_mask, null_count] = detail::valid_if(
      intermediate_null_mask->begin(),
      intermediate_null_mask->end(),
      [] __device__(bool element) { return element; },
      stream,
      mr);

    output->set_null_mask(std::move(null_mask), null_count);
  }

  return output;
}

void check_row_size(std::optional<size_type> in_row_size, InputsView inputs)
{
  auto row_size = in_row_size.value_or(cudf::jit::get_projection_size(inputs));

  if (!in_row_size.has_value()) {
    CUDF_EXPECTS(
      std::any_of(inputs.begin(),
                  inputs.end(),
                  [](auto const& input) { return std::holds_alternative<column_view>(input); }),
      "At least one input of a transform must be a non-scalar column if row size is not provided",
      std::invalid_argument);
  }

  CUDF_EXPECTS(std::all_of(inputs.begin(),
                           inputs.end(),
                           [&](auto const& input) {
                             if (std::holds_alternative<column_view>(input)) {
                               return std::get<column_view>(input).size() == row_size;
                             }

                             return true;
                           }),
               "All transform input columns must have the same size",
               std::invalid_argument);
}

void perform_checks(std::optional<size_type> in_row_size, data_type output_type, InputsView inputs)
{
  CUDF_EXPECTS(is_fixed_width(output_type) || output_type.id() == type_id::STRING,
               "Transforms only support output of fixed-width or string types",
               std::invalid_argument);

  auto get_type = [](auto const& in) {
    return std::visit([](auto const& col) { return col.type(); }, in);
  };

  CUDF_EXPECTS(
    std::all_of(thrust::make_transform_iterator(inputs.begin(), get_type),
                thrust::make_transform_iterator(inputs.end(), get_type),
                [](data_type t) { return is_fixed_width(t) || (t.id() == type_id::STRING); }),
    "Transforms only support input of fixed-width or string types",
    std::invalid_argument);

  check_row_size(in_row_size, inputs);
}

}  // namespace

}  // namespace jit
}  // namespace transformation

namespace detail {

std::unique_ptr<column> transform(InputsView inputs,
                                  std::string const& udf,
                                  data_type output_type,
                                  cudf::udf_source_type source_type,
                                  std::optional<void*> user_data,
                                  null_aware is_null_aware,
                                  std::optional<size_type> in_row_size,
                                  output_nullability null_policy,
                                  rmm::cuda_stream_view stream,
                                  rmm::device_async_resource_ref mr)
{
  CUDF_EXPECTS(
    !inputs.empty(), "Transform must have at least 1 input column", std::invalid_argument);
  CUDF_EXPECTS(!(is_null_aware == null_aware::YES && source_type == cudf::udf_source_type::PTX),
               "Optional types are not supported in PTX UDFs",
               std::invalid_argument);

  transformation::jit::perform_checks(in_row_size, output_type, inputs);

  auto row_size = in_row_size.value_or(cudf::jit::get_projection_size(inputs));

  if (is_fixed_width(output_type)) {
    return transformation::jit::transform_operation(row_size,
                                                    inputs,
                                                    udf,
                                                    output_type,
                                                    source_type,
                                                    user_data,
                                                    is_null_aware,
                                                    null_policy,
                                                    stream,
                                                    mr);
  } else if (output_type.id() == type_id::STRING) {
    return transformation::jit::string_view_operation(row_size,
                                                      inputs,
                                                      udf,
                                                      output_type,
                                                      source_type,
                                                      user_data,
                                                      is_null_aware,
                                                      null_policy,
                                                      stream,
                                                      mr);
  } else {
    CUDF_FAIL("Unsupported output type for transform operation");
  }
}

}  // namespace detail

std::unique_ptr<column> transform_extended(
  std::span<std::variant<column_view, scalar_column_view> const> inputs,
  std::string const& udf,
  data_type output_type,
  udf_source_type source_type,
  std::optional<void*> user_data,
  null_aware is_null_aware,
  std::optional<size_type> row_size,
  output_nullability null_policy,
  rmm::cuda_stream_view stream,
  rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  return detail::transform(inputs,
                           udf,
                           output_type,
                           source_type,
                           user_data,
                           is_null_aware,
                           row_size,
                           null_policy,
                           stream,
                           mr);
}

std::unique_ptr<column> transform(std::vector<column_view> const& columns,
                                  std::string const& transform_udf,
                                  data_type output_type,
                                  bool is_ptx,
                                  std::optional<void*> user_data,
                                  null_aware is_null_aware,
                                  output_nullability null_policy,
                                  rmm::cuda_stream_view stream,
                                  rmm::device_async_resource_ref mr)
{
  CUDF_FUNC_RANGE();
  // legacy behavior was to detect which column were scalars based on their sizes
  std::vector<std::variant<column_view, scalar_column_view>> inputs;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
  auto base_column = jit::get_transform_base_column(columns);
  for (auto const& col : columns) {
    if (jit::is_scalar(base_column->size(), col.size())) {
#pragma GCC diagnostic pop
      inputs.emplace_back(scalar_column_view{col});
    } else {
      inputs.emplace_back(col);
    }
  }

  return detail::transform(inputs,
                           transform_udf,
                           output_type,
                           is_ptx ? udf_source_type::PTX : udf_source_type::CUDA,
                           user_data,
                           is_null_aware,
                           base_column->size(),
                           null_policy,
                           stream,
                           mr);
}

std::unique_ptr<column> compute_column_jit(table_view const& table,
                                           ast::expression const& expr,
                                           rmm::cuda_stream_view stream,
                                           rmm::device_async_resource_ref mr)
{
  cudf::detail::row_ir::ast_args ast_args{.table = table};
  auto args = cudf::detail::row_ir::ast_converter::compute_column(
    cudf::detail::row_ir::target::CUDA, expr, ast_args, stream, mr);

  return cudf::transform_extended(args.inputs,
                                  args.udf,
                                  args.output_type,
                                  args.source_type,
                                  args.user_data,
                                  args.is_null_aware,
                                  args.row_size,
                                  args.null_policy,
                                  stream,
                                  mr);
}

}  // namespace cudf
