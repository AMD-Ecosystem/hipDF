// MIT License
//
// Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

/*
 * CPU-side deterministic input generation switch for benchmarks.
 *
 * When the environment variable `CUDF_BENCH_DETERMINISTIC_CPU` is set to a
 * non-empty value other than "0" / "false", `is_cpu_datagen_enabled()` returns
 * true and benchmark random-data generation paths route through host-side RNG
 * with an upload to device, instead of running thrust kernels seeded from
 * `thrust::minstd_rand`.
 *
 * The flag is read once at program start and cached. This is a header-only
 * helper to avoid touching the benchmark CMakeLists library lists.
 */

#pragma once

#include <cctype>
#include <cstdlib>
#include <string>

namespace cudf::datagen {

namespace detail {

inline bool read_datagen_flag_from_env()
{
  char const* v = std::getenv("CUDF_BENCH_DETERMINISTIC_CPU");
  if (v == nullptr) return false;
  std::string s(v);
  if (s.empty()) return false;
  if (s == "0") return false;
  std::string lower;
  lower.reserve(s.size());
  for (char c : s) lower.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
  if (lower == "false") return false;
  return true;
}

}  // namespace detail

/**
 * @brief Returns true if benchmark inputs should be generated on the CPU and
 * uploaded to device. Reads `CUDF_BENCH_DETERMINISTIC_CPU` once.
 */
inline bool is_cpu_datagen_enabled()
{
  static bool const enabled = detail::read_datagen_flag_from_env();
  return enabled;
}

}  // namespace cudf::datagen
