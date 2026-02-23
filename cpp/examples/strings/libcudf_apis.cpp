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

#include "common.hpp"

#include <cudf/copying.hpp>
#include <cudf/scalar/scalar.hpp>
#include <cudf/strings/combine.hpp>
#include <cudf/strings/find.hpp>
#include <cudf/strings/slice.hpp>
#include <cudf/strings/split/split.hpp>
#include <cudf/strings/strings_column_view.hpp>

#include <cudf/cuda_runtime.h>
//#include <nvtx3/nvToolsExt.h> # TODO(HIP/AMD): Re-enable once nvtx equivalent is available

/**
 * @brief Redacts each name per the corresponding visibility entry
 *
 * This implementation uses libcudf APIs to create the output result.
 *
 * @param names Column of names
 * @param visibilities Column of visibilities
 * @return Redacted column of names
 */
std::unique_ptr<cudf::column> redact_strings(cudf::column_view const& names,
                                             cudf::column_view const& visibilities)
{
  auto const visible   = cudf::string_scalar(std::string("public"));
  auto const redaction = cudf::string_scalar(std::string("X X"));

  //nvtxRangePushA("redact_strings"); // TODO(HIP/AMD): Re-enable once nvtx equivalent is available

  auto const allowed      = cudf::strings::contains(visibilities, visible);
  auto const redacted     = cudf::copy_if_else(names, redaction, allowed->view());
  auto const first_last   = cudf::strings::split(redacted->view());
  auto const first        = first_last->view().column(0);
  auto const last         = first_last->view().column(1);
  auto const last_initial = cudf::strings::slice_strings(last, 0, 1);

  auto const last_initial_first = cudf::table_view({last_initial->view(), first});

  auto result = cudf::strings::concatenate(last_initial_first, std::string_view(" "));

  cudaStreamSynchronize(0);

  //nvtxRangePop(); // TODO(HIP/AMD): Re-enable once nvtx equivalent is available
  return result;
}
