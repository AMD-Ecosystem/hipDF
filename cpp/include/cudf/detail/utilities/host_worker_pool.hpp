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

#pragma once

#include <cudf/utilities/error.hpp>
#include <cudf/utilities/export.hpp>

// NOTE(HIP/AMD): use the cudf cuda_runtime shim instead of the raw <cuda_runtime.h>,
// which does not exist on the AMD/HIP toolchain (reverse-hipify convention).
#include <cudf/cuda_runtime.h>

#include <BS_thread_pool.hpp>

#include <cstddef>
#include <memory>

namespace cudf::detail {

/**
 * @brief Sentinel value indicating a thread not assigned to any pool level.
 *
 * This is the initial value of `thread_pool_level` for all threads. Once a thread
 * executes its first task from a pool, `thread_pool_level` is set to that pool's level
 * and never changes back to this value.
 */
constexpr int THREAD_POOL_LEVEL_NONE = -1;
static_assert(THREAD_POOL_LEVEL_NONE == -1, "THREAD_POOL_LEVEL_NONE must be -1");

/**
 * @brief Thread-local variable indicating which pool level this thread belongs to.
 *
 * Used by `host_worker_pool()` to route tasks to the correct nesting level.
 */
CUDF_EXPORT extern thread_local int thread_pool_level;

/**
 * @brief Thread pool wrapper that marks its threads with ownership.
 *
 * This wrapper ensures that threads know which pool they belong to, enabling
 * automatic routing to the correct nesting level.
 */
class CUDF_EXPORT hierarchical_thread_pool {
  BS::thread_pool pool_;
  int level_;

 public:
  /**
   * @brief Construct a new tiered thread pool.
   *
   * @param num_threads Number of threads in the pool
   * @param level Pool level
   */
  hierarchical_thread_pool(std::size_t num_threads, int level);

  /**
   * @brief Submit task and mark the executing thread with ownership.
   *
   * When a thread first executes a task, it's marked with the pool level.
   * This ownership persists for the lifetime of the thread.
   *
   * @tparam F Callable type
   * @param task Task to execute
   * @return Future for the task result
   */
  template <typename F>
  auto submit_task(F&& task)
  {
    // Wrap task in shared_ptr so lambda can call it without being mutable.
    // This is required because BS::thread_pool stores the lambda and calls
    // it from a const context.
    auto task_ptr = std::make_shared<std::decay_t<F>>(std::forward<F>(task));

    // Capture the submitting thread's CUDA device so worker threads operate on
    // the correct device. Without this, worker threads default to device 0
    int device_id = 0;
    CUDF_CUDA_TRY(cudaGetDevice(&device_id));

    return pool_.submit_task([task_ptr, level = level_, device_id]() {
      // Mark this thread as owned by this pool's level (happens once per thread)
      if (thread_pool_level == THREAD_POOL_LEVEL_NONE) { thread_pool_level = level; }

      CUDF_CUDA_TRY(cudaSetDevice(device_id));

      return (*task_ptr)();
    });
  }

  /**
   * @brief Get the number of threads in this pool.
   */
  [[nodiscard]] std::size_t get_thread_count() const { return pool_.get_thread_count(); }
};

/**
 * @brief Retrieves the appropriate thread pool based on the calling thread's context.
 *
 * The returned pool is always different from the calling thread's pool.
 *
 * @return Reference to the thread pool
 */
hierarchical_thread_pool& host_worker_pool();
}  // namespace cudf::detail
