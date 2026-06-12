/*
 * SPDX-FileCopyrightText: Copyright (c) 2024-2025, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

// MIT License
//
// Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

#include <cudf/detail/utilities/cuda.hpp>
#include <cudf/types.hpp>
#include <cudf/utilities/error.hpp>

namespace cudf::detail {

cudf::size_type num_multiprocessors()
{
  int device = 0;
  CUDF_CUDA_TRY(cudaGetDevice(&device));
  int num_sms = 0;
  CUDF_CUDA_TRY(cudaDeviceGetAttribute(&num_sms, cudaDevAttrMultiProcessorCount, device));
  return num_sms;
}

[[nodiscard]] bool has_integrated_memory()
{
  static auto const cached_result = []() {
    int device = 0;
    CUDF_CUDA_TRY(cudaGetDevice(&device));
    int is_integrated = 0;
    CUDF_CUDA_TRY(cudaDeviceGetAttribute(&is_integrated, cudaDevAttrIntegrated, device));
    return is_integrated == 1;
  }();
  return cached_result;
}

cudf::size_type max_shared_mem_per_multiprocessor()
{
  int device = 0;
  CUDF_CUDA_TRY(cudaGetDevice(&device));
  int max_shared_mem_per_sm;
  CUDF_CUDA_TRY(cudaDeviceGetAttribute(
    &max_shared_mem_per_sm, cudaDevAttrMaxSharedMemoryPerMultiprocessor, device));
  return max_shared_mem_per_sm;
}

cudf::size_type max_threads_per_multiprocessor()
{
  int device = 0;
  CUDF_CUDA_TRY(cudaGetDevice(&device));
  int max_threads_per_sm;
  CUDF_CUDA_TRY(
    cudaDeviceGetAttribute(&max_threads_per_sm, cudaDevAttrMaxThreadsPerMultiprocessor, device));
  return max_threads_per_sm;
}

}  // namespace cudf::detail
