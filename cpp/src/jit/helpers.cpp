/*
 * SPDX-FileCopyrightText: Copyright (c) 2025-2026, NVIDIA CORPORATION.
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

#include "helpers.hpp"

#include <cudf/detail/nvtx/ranges.hpp>

#include <jit/cache.hpp>

namespace cudf {
namespace jit {

bool is_scalar(cudf::size_type base_column_size, cudf::size_type column_size)
{
  return column_size == 1 && column_size != base_column_size;
}

typename std::vector<column_view>::const_iterator get_transform_base_column(
  std::vector<column_view> const& inputs)
{
  if (inputs.empty()) { return inputs.end(); }

  auto [smallest, largest] = std::minmax_element(
    inputs.begin(), inputs.end(), [](auto const& a, auto const& b) { return a.size() < b.size(); });

  /// when the largest size is 1, the size-1 column could be a scalar or an actual column, it would
  /// be a scalar if it has columns that are zero-sized
  if (largest->size() != 1) { return largest; }

  if (smallest->size() == 0) { return smallest; }

  return largest;
}

size_type get_projection_size(column_view const& col) { return col.size(); }

/// @brief Scalar columns don't contribute to the row-size of a transform.
size_type get_projection_size(scalar_column_view const& col) { return 0; }

size_type get_projection_size(std::span<std::variant<column_view, scalar_column_view> const> inputs)
{
  CUDF_EXPECTS(
    !inputs.empty(), "Transform must have at least 1 input column", std::invalid_argument);

  auto get_size = [](auto const& var) {
    return std::visit([](auto& a) { return get_projection_size(a); }, var);
  };

  return *std::max_element(thrust::make_transform_iterator(inputs.begin(), get_size),
                           thrust::make_transform_iterator(inputs.end(), get_size));
}

std::map<uint32_t, std::string> build_ptx_params(std::span<std::string const> output_typenames,
                                                 std::span<std::string const> input_typenames,
                                                 bool has_user_data)
{
  std::map<uint32_t, std::string> params;
  uint32_t index = 0;

  if (has_user_data) {
    params.emplace(index++, "void *");
    params.emplace(index++, jitify2::reflection::reflect<cudf::size_type>());
  }

  for (auto& name : output_typenames) {
    params.emplace(index++, name + "*");
  }

  for (auto& name : input_typenames) {
    params.emplace(index++, name);
  }

  return params;
}

std::vector<std::string> input_type_names(
  std::span<std::variant<column_view, scalar_column_view> const> views)
{
  std::vector<std::string> names;

  std::transform(views.begin(), views.end(), std::back_inserter(names), [&](auto const& view) {
    return std::visit([](auto& a) { return type_to_name(a.type()); }, view);
  });

  return names;
}

jitify2::Kernel get_udf_kernel(jitify2::PreprocessedProgramData const& preprocessed_program_data,
                               std::string const& kernel_name,
                               std::string const& cuda_source,
                               std::vector<std::string> const& extra_options,
                               std::string const* parsed_udf_llvm_ir)
{
  CUDF_FUNC_RANGE();

  std::vector<std::string> options;

  if constexpr (HIP_PLATFORM_AMD) {
    // NOTE(HIP/AMD): emit the AMD offload arch instead of NVIDIA's -arch=sm_., and skip the
    // CUDA-version-gated -minimal/-pch options (and the cudaRuntimeGetVersion query, which
    // reports the HIP runtime version on AMD and would mis-gate those NVRTC-only flags).
    options.emplace_back("--offload-arch=gfx.");
  } else {
    int runtime_version;
    CUDF_CUDA_TRY(cudaRuntimeGetVersion(&runtime_version));

    constexpr int min_pch_cuda_version     = 12800;  // CUDA 12.8
    constexpr int min_minimal_cuda_version = 12800;  // CUDA 12.8

    options.emplace_back("-arch=sm_.");

    if (runtime_version >= min_minimal_cuda_version) { options.emplace_back("-minimal"); }

    if (runtime_version >= min_pch_cuda_version) { options.emplace_back("-pch"); }
  }

  for (auto& opt : extra_options) {
    options.push_back(opt);
  }

  // NOTE(HIP/AMD): on AMD the arch-adapted LLVM IR (parsed_udf_llvm_ir) is linked into the
  // kernel as extra bitcode (jitify2 get_kernel's last argument). CAUTION(HIP/AMD): we assume
  // the IR has already been compiled for the current arch (must match the kernel program,
  // otherwise the linker errors). On NVIDIA parsed_udf_llvm_ir is null and PTX is used.
  return cudf::jit::get_program_cache(preprocessed_program_data)
    .get_kernel(kernel_name,
                {},
                {{"cudf/detail/operation-udf.hpp", cuda_source}},
                options,
                {},
                parsed_udf_llvm_ir);
}

}  // namespace jit
}  // namespace cudf
