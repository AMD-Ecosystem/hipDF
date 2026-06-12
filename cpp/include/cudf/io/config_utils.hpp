/*
 * SPDX-FileCopyrightText: Copyright (c) 2024-2025, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
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

#pragma once

#include <cudf/utilities/export.hpp>

namespace CUDF_EXPORT cudf {
namespace io {
//! `KvikIO`
namespace kvikio_integration {

/**
 * @addtogroup io_configuration
 * @{
 * @file
 */

/**
 * @brief Set KvikIO parameters
 *
 * Parameters include:
 * - Compatibility mode, according to the environment variable KVIKIO_COMPAT_MODE. If
 *   KVIKIO_COMPAT_MODE is not set, enable it by default, which enforces the use of POSIX I/O.
 * - Thread pool size, according to the environment variable KVIKIO_NTHREADS. If KVIKIO_NTHREADS is
 *   not set, use 4 threads by default.
 */
void set_up_kvikio();

}  // namespace kvikio_integration

//! `nvCOMP`
namespace nvcomp_integration {

/**
 * @brief Returns true if all nvCOMP uses are enabled
 *
 * @return true if all nvCOMP uses are enabled
 */
[[nodiscard]] bool is_all_enabled();

/**
 * @brief Returns true if stable nvCOMP use is enabled
 *
 * @return true true if stable nvCOMP use is enabled
 */
[[nodiscard]] bool is_stable_enabled();

}  // namespace nvcomp_integration

//! IO Integrated Memory Optimization
namespace integrated_memory_optimization {

/**
 * @brief Returns true if integrated memory optimizations are enabled
 *
 * Controlled by the LIBCUDF_INTEGRATED_MEMORY_OPTIMIZATION environment variable.
 * Valid values: "AUTO" (default), "ON", "OFF"
 * - AUTO: Use hardware detection (cudaDevAttrIntegrated)
 * - ON: Always enable optimization
 * - OFF: Always disable optimization
 *
 * @return true if integrated memory optimizations are enabled
 */
[[nodiscard]] bool is_enabled();

/** @} */  // end of group
}  // namespace integrated_memory_optimization
}  // namespace io
}  // namespace CUDF_EXPORT cudf
