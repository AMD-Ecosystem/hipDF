/*
 * SPDX-FileCopyrightText: Copyright (c) 2021-2026, NVIDIA CORPORATION.
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

#include <cudf/detail/utilities/cuda.hpp>
#include <cudf/detail/utilities/getenv_or.hpp>
#include <cudf/io/config_utils.hpp>
#include <cudf/utilities/error.hpp>

#ifdef CUDF_HAS_KVIKIO
#include <kvikio/defaults.hpp>
#endif

#include <string>

namespace cudf::io {

namespace kvikio_integration {

void set_up_kvikio()
{
#ifdef CUDF_HAS_KVIKIO
  static std::once_flag flag{};
  std::call_once(flag, [] {
    // Workaround for https://github.com/rapidsai/cudf/issues/14140, where cuFileDriverOpen errors
    // out if no CUDA calls have been made before it. This is a no-op if the CUDA context is already
    // initialized.
    cudaFree(nullptr);

    auto const compat_mode = kvikio::getenv_or("KVIKIO_COMPAT_MODE", kvikio::CompatMode::ON);
    kvikio::defaults::set_compat_mode(compat_mode);

    auto const nthreads = cudf::detail::getenv_or<unsigned int>("KVIKIO_NTHREADS", 4u);
    kvikio::defaults::set_thread_pool_nthreads(nthreads);
  });
#endif
}

}  // namespace kvikio_integration

namespace nvcomp_integration {

namespace {
/**
 * @brief Defines which nvCOMP usage to enable.
 */
enum class usage_policy : uint8_t { OFF, STABLE, ALWAYS };

/**
 * @brief Get the current usage policy.
 */
[[nodiscard]] usage_policy get_env_policy()
{
// <<<<<<< OLD CODE from de6a7d7986 (bbecf7d9bf) - COMMENTED OUT
//   auto const env_val = getenv_or<std::string>("LIBCUDF_NVCOMP_POLICY", "STABLE");
//   if (env_val == "OFF") {
// #if defined(__HIP_PLATFORM_AMD__) || defined(__HIP_PLATFORM_HCC__)
//     // NOTE(HIP/AMD): hipDF requires nvcomp for compression/decompression support.
//     // LIBCUDF_NVCOMP_POLICY=OFF is not supported on HIP/AMD platforms.
//     CUDF_FAIL("LIBCUDF_NVCOMP_POLICY=OFF is not supported on hipDF. "
//               "nvcomp is required for compression/decompression on HIP/AMD platforms.");
// #endif
//     return usage_policy::OFF;
//   }
// =======
  auto const env_val = cudf::detail::getenv_or<std::string>("LIBCUDF_NVCOMP_POLICY", "STABLE");
  if (env_val == "OFF") return usage_policy::OFF;
// >>>>>>> END NEW CODE (bbecf7d9bf)
  if (env_val == "STABLE") return usage_policy::STABLE;
  if (env_val == "ALWAYS") return usage_policy::ALWAYS;
  CUDF_FAIL("Invalid LIBCUDF_NVCOMP_POLICY value: " + env_val);
}
}  // namespace

[[nodiscard]] bool is_all_enabled() { return get_env_policy() == usage_policy::ALWAYS; }

[[nodiscard]] bool is_stable_enabled()
{
  return is_all_enabled() or get_env_policy() == usage_policy::STABLE;
}

}  // namespace nvcomp_integration

namespace integrated_memory_optimization {

[[nodiscard]] bool is_enabled()
{
  auto const policy = []() {
    auto const* env_val = std::getenv("LIBCUDF_INTEGRATED_MEMORY_OPTIMIZATION");
    if (env_val == nullptr) return std::string("AUTO");
    return std::string(env_val);
  }();

  if (policy == "OFF") return false;
  if (policy == "ON") return true;
  if (policy == "AUTO") return cudf::detail::has_integrated_memory();
  CUDF_FAIL("Invalid LIBCUDF_INTEGRATED_MEMORY_OPTIMIZATION value: " + policy);
}

}  // namespace integrated_memory_optimization
}  // namespace cudf::io
