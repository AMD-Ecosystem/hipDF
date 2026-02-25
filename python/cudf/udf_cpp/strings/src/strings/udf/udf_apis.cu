/*
 * Copyright (c) 2022-2025, NVIDIA CORPORATION.
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

#include <cudf/column/column_factories.hpp>
#include <cudf/strings/string_view.cuh>
#include <cudf/strings/udf/managed_udf_string.cuh>
#include <cudf/strings/udf/udf_apis.hpp>
#include <cudf/strings/udf/udf_string.cuh>
#include <cudf/strings/utilities.hpp>
#include <cudf/utilities/default_stream.hpp>
#include <cudf/utilities/memory_resource.hpp>

#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>

#include <thrust/iterator/counting_iterator.h>
#include <thrust/transform.h>

#include <rocm-core/rocm_version.h>

// NOTE(HIP/AMD): Encode the ROCm version so that it can be decoded into major and minor part by
//                function '_get_cuda_build_version' in `python/cudf/cudf/utils/_numba.py`.
#define CUDA_VERSION (ROCM_VERSION_MAJOR*1000 + ROCM_VERSION_MINOR*10)

namespace cudf {
namespace strings {
namespace udf {

namespace detail {

namespace {

/**
 * @brief Functor wraps string_view objects around udf_string objects
 *
 * No string data is copied.
 */
struct managed_udf_string_to_string_view_transform_fn {
  __device__ cudf::string_view operator()(
    cudf::strings::udf::managed_udf_string const& managed_dstr)
  {
    return managed_dstr.udf_str.data() == nullptr
             ? cudf::string_view{}
             : cudf::string_view{managed_dstr.udf_str.data(), managed_dstr.udf_str.size_bytes()};
  }
};

}  // namespace

/**
 * @copydoc to_string_view_array
 *
 * @param stream CUDA stream used for allocating/copying device memory and launching kernels
 */
std::unique_ptr<rmm::device_buffer> to_string_view_array(cudf::column_view const input,
                                                         rmm::cuda_stream_view stream)
{
  return std::make_unique<rmm::device_buffer>(
    std::move(cudf::strings::create_string_vector_from_column(
                cudf::strings_column_view(input), stream, cudf::get_current_device_resource_ref())
                .release()));
}

/**
 * @copydoc column_from_managed_udf_string_array
 *
 * @param stream CUDA stream used for allocating/copying device memory and launching kernels
 */
std::unique_ptr<cudf::column> column_from_managed_udf_string_array(
  managed_udf_string* managed_strings, cudf::size_type size, rmm::cuda_stream_view stream)
{
  // create string_views of the udf_strings
  auto indices = rmm::device_uvector<cudf::string_view>(size, stream);
  thrust::transform(rmm::exec_policy(stream),
                    managed_strings,
                    managed_strings + size,
                    indices.data(),
                    managed_udf_string_to_string_view_transform_fn{});

  auto result = cudf::make_strings_column(indices, cudf::string_view(nullptr, 0), stream);
  stream.synchronize();
  return result;
}

/**
 * @copydoc free_managed_udf_string_array
 *
 * @param stream CUDA stream used for launching kernels
 */
void free_managed_udf_string_array(managed_udf_string* managed_strings,
                                   cudf::size_type size,
                                   rmm::cuda_stream_view stream)
{
  thrust::for_each_n(rmm::exec_policy(stream),
                     thrust::make_counting_iterator(0),
                     size,
                     [managed_strings] __device__(auto idx) {
                       managed_strings[idx].udf_str.clear();
                     });
  stream.synchronize();
}

}  // namespace detail

// external APIs

int get_cuda_build_version() { return CUDA_VERSION; }

std::unique_ptr<rmm::device_buffer> to_string_view_array(cudf::column_view const input)
{
  return detail::to_string_view_array(input, cudf::get_default_stream());
}

std::unique_ptr<cudf::column> column_from_managed_udf_string_array(
  managed_udf_string* managed_strings, cudf::size_type size)
{
  return detail::column_from_managed_udf_string_array(
    managed_strings, size, cudf::get_default_stream());
}

void free_managed_udf_string_array(managed_udf_string* managed_strings, cudf::size_type size)
{
  detail::free_managed_udf_string_array(managed_strings, size, cudf::get_default_stream());
}

}  // namespace udf
}  // namespace strings
}  // namespace cudf
