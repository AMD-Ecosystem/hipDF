// MIT License
//
// Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

namespace cudf {

  /**
  * @brief Returns the name of the current AMD gfx GPU architecture as a string (e.g. gfx90a for MI200).
  *
  * @note This function should only be used on AMD HIP backend.
  *
  * @return The name of the current AMD gfx GPU architecture as a string (e.g. gfx90a for MI200).
  */
  std::string get_arch_name_of_current_device();

  /**
   * @brief Gets the LLVM IR target features for a given AMD gfx architecture.
   *
   * @param arch_name The name of the AMD gfx architecture (e.g., gfx90a).
   *
   * @return Comma-delimited string containing all target features for the input architecture.
  */
  std::string get_llvm_ir_target_features_for_arch(const std::string& arch_name);

  /**
   * @brief Gets the LLVM IR target features for the AMD gfx architecture of the current device.
   *
   * @return Comma-delimited string containing all target features for the architecture of the current device.
  */
  std::string get_llvm_ir_target_features_for_current_arch();

  /**
   * @brief Adapts all attributes "target-cpu" and "target-features" in input LLVM IR code
   * for the AMD gfx architecture of the current device.
   *
   * @param llvm_ir String containing AMD LLVM IR source code (e.g., of a UDF function).
   *
   * @return Adapted LLVM IR, which is ready to be compiled for the AMD gfx arch of the current device.
  */
  std::string adapt_llvm_ir_attributes_for_current_arch(const std::string& llvm_ir);

}  // namespace cudf
