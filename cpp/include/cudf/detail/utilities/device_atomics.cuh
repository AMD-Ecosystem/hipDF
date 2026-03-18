/*
 * SPDX-FileCopyrightText: Copyright (c) 2019-2026, NVIDIA CORPORATION.
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

/**
 * @brief overloads for CUDA atomic operations
 * @file device_atomics.cuh
 *
 * Provides the overloads for all of cudf's data types, specifically int8_t,
 * int16_t, int32_t, int64_t, float, double, cudf::timestamp_D,
 * cudf::timestamp_s, cudf::timestamp_ms, cudf::timestamp_us,
 * cudf::timestamp_ns, cudf::duration_D, cudf::duration_s, cudf::duration_ms,
 * cudf::duration_us, cudf::duration_ns and bool for the CUDA atomic operations
 * `atomicAdd`, `atomicMin`, `atomicMax`, `atomicCAS`.
 *
 * Also provides `cudf::detail::genericAtomicOperation` which performs an
 * atomic operation with the given binary operator.
 */

#include <cudf/detail/utilities/device_operators.cuh>
#include <cudf/types.hpp>
#include <cudf/utilities/traits.hpp>
#include <cudf/wrappers/durations.hpp>
#include <cudf/wrappers/timestamps.hpp>

#include <cuda/atomic>
#include <cuda/std/limits>
#include <cuda/std/type_traits>

namespace cudf {
namespace detail {

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// template <typename T_output, typename T_input>
// __forceinline__ __device__ T_output type_reinterpret(T_input value)
// {
//   static_assert(sizeof(T_output) == sizeof(T_input), "type_reinterpret for different size");
//   return *(reinterpret_cast<T_output*>(&value));
// }
//
// // -----------------------------------------------------------------------
// // the implementation of `genericAtomicOperation`
// template <typename T, typename Op, size_t N = sizeof(T)>
// struct genericAtomicOperationImpl;
//
// // single byte atomic operation
// template <typename T, typename Op>
// struct genericAtomicOperationImpl<T, Op, 1> {
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, Op op)
//   {
//     using T_int = unsigned int;
//
//     auto* address_uint32 = reinterpret_cast<T_int*>(addr - (reinterpret_cast<size_t>(addr) & 3));
//     T_int shift          = ((reinterpret_cast<size_t>(addr) & 3) * 8);
//
//     T_int old = *address_uint32;
//     T_int assumed;
//
//     do {
//       assumed                = old;
//       T target_value         = T((old >> shift) & 0xff);
//       uint8_t updating_value = type_reinterpret<uint8_t, T>(op(target_value, update_value));
//       T_int new_value        = (old & ~(0x0000'00ff << shift)) | (T_int(updating_value) << shift);
//       old                    = atomicCAS(address_uint32, assumed, new_value);
//     } while (assumed != old);
//
//     return T((old >> shift) & 0xff);
//   }
// };
//
// // 2 bytes atomic operation
// template <typename T, typename Op>
// struct genericAtomicOperationImpl<T, Op, 2> {
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, Op op)
//   {
//     using T_int = unsigned short int;
//     static_assert(sizeof(T) == sizeof(T_int));
//
//     T old_value = *addr;
//     T_int assumed;
//     T_int ret;
//
//     do {
//       T_int const new_value = type_reinterpret<T_int, T>(op(old_value, update_value));
//
//       assumed   = type_reinterpret<T_int, T>(old_value);
//       ret       = atomicCAS(reinterpret_cast<T_int*>(addr), assumed, new_value);
//       old_value = type_reinterpret<T, T_int>(ret);
//     } while (assumed != ret);
//
//     return old_value;
//   }
// };
//
// // 4 bytes atomic operation
// template <typename T, typename Op>
// struct genericAtomicOperationImpl<T, Op, 4> {
//   __forceinline__ __device__ T operator()(T* addr, T const& update_value, Op op)
//   {
//     using T_int = unsigned int;
//     static_assert(sizeof(T) == sizeof(T_int));
//
//     T old_value = *addr;
//     T_int assumed;
//     T_int ret;
//
//     do {
//       T_int const new_value = type_reinterpret<T_int, T>(op(old_value, update_value));
//
//       assumed   = type_reinterpret<T_int, T>(old_value);
//       ret       = atomicCAS(reinterpret_cast<T_int*>(addr), assumed, new_value);
//       old_value = type_reinterpret<T, T_int>(ret);
//     } while (assumed != ret);
//
//     return old_value;
//   }
// };
// =======
template <typename T, typename Op>
struct genericAtomicOperationImpl;
// >>>>>>> END NEW CODE (86ed92df2f)

template <typename T, typename Op>
// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// struct genericAtomicOperationImpl<T, Op, 8> {
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, Op op)
// =======
struct genericAtomicOperationImpl {
  __forceinline__ __device__ T operator()(T* addr, T const& update_value, Op op)
// >>>>>>> END NEW CODE (86ed92df2f)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    T old_value = atomic_addr.load(cuda::memory_order_relaxed);
    T new_value;

    do {
      new_value = op(old_value, update_value);
    } while (!atomic_addr.compare_exchange_weak(old_value, new_value, cuda::memory_order_relaxed));

    return old_value;
  }
};

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// // Specialized functions for operators.
//
// // `atomicAdd` supports int32_t, uint32_t, uint64_t, float, double.
// // `atomicAdd` does not support int64_t.
//
// template <>
// struct genericAtomicOperationImpl<float, DeviceSum, 4> {
//   using T = float;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
//   {
//     return atomicAdd(addr, update_value);
//   }
// };
//
// template <>
// struct genericAtomicOperationImpl<double, DeviceSum, 8> {
//   using T = double;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
// =======
// Optimized specializations using native atomic operations
template <typename T>
struct genericAtomicOperationImpl<T, DeviceSum> {
  __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
    requires(cuda::std::is_arithmetic_v<T> && !cuda::std::is_same_v<T, bool>)
// >>>>>>> END NEW CODE (86ed92df2f)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    return atomic_addr.fetch_add(update_value, cuda::memory_order_relaxed);
  }

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// template <>
// struct genericAtomicOperationImpl<int32_t, DeviceSum, 4> {
//   using T = int32_t;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
// =======
  __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
    requires(!cuda::std::is_arithmetic_v<T> || cuda::std::is_same_v<T, bool>)
// >>>>>>> END NEW CODE (86ed92df2f)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    T old_value = atomic_addr.load(cuda::memory_order_relaxed);
    T new_value;

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// // CUDA natively supports `unsigned long long int` for `atomicAdd`,
// // but doesn't support `signed long long int`.
// // However, since the signed integer is represented as two's complement,
// // the fundamental arithmetic operations of addition are identical to
// // those for unsigned binary numbers.
// // Then, this computes as `unsigned long long int` with `atomicAdd`
// // @sa https://en.wikipedia.org/wiki/Two%27s_complement
// template <>
// struct genericAtomicOperationImpl<int64_t, DeviceSum, 8> {
//   using T = int64_t;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
//   {
//     using T_int = unsigned long long int;
//     static_assert(sizeof(T) == sizeof(T_int));
//     T ret = atomicAdd(reinterpret_cast<T_int*>(addr), type_reinterpret<T_int, T>(update_value));
//     return ret;
//   }
// };
//
// template <>
// struct genericAtomicOperationImpl<uint32_t, DeviceSum, 4> {
//   using T = uint32_t;
//   __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceSum op)
//   {
//     return atomicAdd(addr, update_value);
//   }
// };
// =======
    do {
      new_value = op(old_value, update_value);
    } while (!atomic_addr.compare_exchange_weak(old_value, new_value, cuda::memory_order_relaxed));
// >>>>>>> END NEW CODE (86ed92df2f)

    return old_value;
  }
};

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// // NOTE(HIP/AMD): Use atomicCAS instead of atomicMin and atomicMax on MI2XX. Issue #318.
// #ifndef __gfx90a__
// // `atomicMin`, `atomicMax` support int32_t, int64_t, uint32_t, uint64_t.
//
// template <>
// struct genericAtomicOperationImpl<int32_t, DeviceMin, 4> {
//   using T = int32_t;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceMin op)
// =======
template <typename T>
struct genericAtomicOperationImpl<T, DeviceMin> {
  __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceMin op)
    requires(cuda::std::is_integral_v<T> && !cuda::std::is_same_v<T, bool>)
// >>>>>>> END NEW CODE (86ed92df2f)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    return atomic_addr.fetch_min(update_value, cuda::memory_order_relaxed);
  }

  __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceMin op)
    requires(!cuda::std::is_integral_v<T> || cuda::std::is_same_v<T, bool>)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    T old_value = atomic_addr.load(cuda::memory_order_relaxed);
    T new_value;

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// template <>
// struct genericAtomicOperationImpl<int64_t, DeviceMin, 8> {
//   using T = int64_t;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceMin op)
//   {
//     using T_int = long long int;
//     static_assert(sizeof(T) == sizeof(T_int));
//     T ret = atomicMin(reinterpret_cast<T_int*>(addr), type_reinterpret<T_int, T>(update_value));
//     return ret;
//   }
// };
// =======
    do {
      new_value = op(old_value, update_value);
    } while (!atomic_addr.compare_exchange_weak(old_value, new_value, cuda::memory_order_relaxed));
// >>>>>>> END NEW CODE (86ed92df2f)

    return old_value;
  }
};

template <typename T>
struct genericAtomicOperationImpl<T, DeviceMax> {
  __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceMax op)
    requires(cuda::std::is_integral_v<T> && !cuda::std::is_same_v<T, bool>)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    return atomic_addr.fetch_max(update_value, cuda::memory_order_relaxed);
  }

  __forceinline__ __device__ T operator()(T* addr, T const& update_value, DeviceMax op)
    requires(!cuda::std::is_integral_v<T> || cuda::std::is_same_v<T, bool>)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    T old_value = atomic_addr.load(cuda::memory_order_relaxed);
    T new_value;

// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// template <>
// struct genericAtomicOperationImpl<int64_t, DeviceMax, 8> {
//   using T = int64_t;
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& update_value, DeviceMax op)
//   {
//     using T_int = long long int;
//     static_assert(sizeof(T) == sizeof(T_int));
//     T ret = atomicMax(reinterpret_cast<T_int*>(addr), type_reinterpret<T_int, T>(update_value));
//     return ret;
//   }
// };
// =======
    do {
      new_value = op(old_value, update_value);
    } while (!atomic_addr.compare_exchange_weak(old_value, new_value, cuda::memory_order_relaxed));
// >>>>>>> END NEW CODE (86ed92df2f)

    return old_value;
  }
};
#endif
// -----------------------------------------------------------------------
// the implementation of `typesAtomicCASImpl`
template <typename T>
// <<<<<<< OLD CODE from 08af90d410 (86ed92df2f) - COMMENTED OUT
// struct typesAtomicCASImpl<T, 1> {
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& compare, T const& update_value)
//   {
//     using T_int = unsigned int;
//
//     T_int shift          = ((reinterpret_cast<size_t>(addr) & 3) * 8);
//     auto* address_uint32 = reinterpret_cast<T_int*>(addr - (reinterpret_cast<size_t>(addr) & 3));
//
//     // the 'target_value' in `old` can be different from `compare`
//     // because other thread may update the value
//     // before fetching a value from `address_uint32` in this function
//     T_int old = *address_uint32;
//     T_int assumed;
//     T target_value;
//     uint8_t u_val = type_reinterpret<uint8_t, T>(update_value);
//
//     do {
//       assumed      = old;
//       target_value = T((old >> shift) & 0xff);
//       // have to compare `target_value` and `compare` before calling atomicCAS
//       // the `target_value` in `old` can be different with `compare`
//       if (target_value != compare) break;
//
//       T_int new_value = (old & ~(0x0000'00ff << shift)) | (T_int(u_val) << shift);
//       old             = atomicCAS(address_uint32, assumed, new_value);
//     } while (assumed != old);
//
//     return target_value;
//   }
// };
//
// template <typename T>
// struct typesAtomicCASImpl<T, 2> {
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& compare, T const& update_value)
//   {
//     using T_int = unsigned short int;
//     static_assert(sizeof(T) == sizeof(T_int));
//
//     T_int ret = atomicCAS(reinterpret_cast<T_int*>(addr),
//                           type_reinterpret<T_int, T>(compare),
//                           type_reinterpret<T_int, T>(update_value));
//
//     return type_reinterpret<T, T_int>(ret);
//   }
// };
//
// template <typename T>
// struct typesAtomicCASImpl<T, 4> {
//   __forceinline__ __device__ T operator()(T* addr, T const& compare, T const& update_value)
//   {
//     using T_int = unsigned int;
//     static_assert(sizeof(T) == sizeof(T_int));
//
//     T_int ret = atomicCAS(reinterpret_cast<T_int*>(addr),
//                           type_reinterpret<T_int, T>(compare),
//                           type_reinterpret<T_int, T>(update_value));
//
//     return type_reinterpret<T, T_int>(ret);
//   }
// };
//
// template <typename T>
// struct typesAtomicCASImpl<T, 8> {
//   __forceinline__ __host__ __device__ T operator()(T* addr, T const& compare, T const& update_value)
//   {
//     using T_int = unsigned long long int;
//     static_assert(sizeof(T) == sizeof(T_int));
//
//     T_int ret = atomicCAS(reinterpret_cast<T_int*>(addr),
//                           type_reinterpret<T_int, T>(compare),
//                           type_reinterpret<T_int, T>(update_value));
//
//     return type_reinterpret<T, T_int>(ret);
// =======
struct typesAtomicCASImpl {
  __forceinline__ __device__ T operator()(T* addr, T const& compare, T const& update_value)
  {
    cuda::atomic_ref<T> atomic_addr(*addr);
    T expected = compare;
    atomic_addr.compare_exchange_strong(expected, update_value, cuda::memory_order_relaxed);
    return expected;
// >>>>>>> END NEW CODE (86ed92df2f)
  }
};

/**
 * @brief Compute atomic binary operation
 *
 * Reads the `old` located at the `address` in global or shared memory,
 * computes 'BinaryOp'('old', 'update_value'),
 * and stores the result back to memory at the same address.
 * These three operations are performed in one atomic transaction.
 *
 * The supported cudf types for `genericAtomicOperation` are:
 * int8_t, int16_t, int32_t, int64_t, float, double
 *
 * @param address The address of old value in global or shared memory
 * @param update_value The value to be computed
 * @param op  The binary operator used for compute
 *
 * @returns The old value at `address`
 */
template <typename T, typename BinaryOp>
T __forceinline__ __device__ genericAtomicOperation(T* address, T const& update_value, BinaryOp op)
  requires(cudf::is_numeric<T>())
{
  auto fun = cudf::detail::genericAtomicOperationImpl<T, BinaryOp>{};
  return T(fun(address, update_value, op));
}

// specialization for cudf::detail::timestamp types
template <typename T, typename BinaryOp>
T __forceinline__ __device__ genericAtomicOperation(T* address, T const& update_value, BinaryOp op)
  requires(cudf::is_timestamp<T>())
{
  using R = typename T::rep;
  // Unwrap the input timestamp to its underlying duration value representation.
  // Use the underlying representation's type to apply operation for the cudf::detail::timestamp
  auto update_value_rep = update_value.time_since_epoch().count();
  auto fun              = cudf::detail::genericAtomicOperationImpl<R, BinaryOp>{};
  return T{typename T::duration(fun(reinterpret_cast<R*>(address), update_value_rep, op))};
}

// specialization for cudf::detail::duration types
template <typename T, typename BinaryOp>
T __forceinline__ __device__ genericAtomicOperation(T* address, T const& update_value, BinaryOp op)
  requires(cudf::is_duration<T>())
{
  using R = typename T::rep;
  // Unwrap the input duration to its underlying duration value representation.
  // Use the underlying representation's type to apply operation for the cudf::detail::duration
  auto update_value_rep = update_value.count();
  auto fun              = cudf::detail::genericAtomicOperationImpl<R, BinaryOp>{};
  return T(fun(reinterpret_cast<R*>(address), update_value_rep, op));
}

// specialization for bool types
template <typename BinaryOp>
__forceinline__ __device__ bool genericAtomicOperation(bool* address,
                                                       bool const& update_value,
                                                       BinaryOp op)
{
  using T = bool;
  // don't use underlying type to apply operation for bool
  auto fun = cudf::detail::genericAtomicOperationImpl<T, BinaryOp>{};
  return T(fun(address, update_value, op));
}

/**
 * @brief Overloads for `atomic_add`
 *
 * Reads the `old` located at the `address` in global or shared memory,
 * computes (old + val), and stores the result back to memory at the same
 * address. These three operations are performed in one atomic transaction.
 *
 * The supported cudf types for `atomic_add` are:
 * int8_t, int16_t, int32_t, int64_t, float, double,
 * cudf::timestamp_D, cudf::timestamp_s, cudf::timestamp_ms cudf::timestamp_us,
 * cudf::timestamp_ns, cudf::duration_D, cudf::duration_s, cudf::duration_ms,
 * cudf::duration_us, cudf::duration_ns and bool
 *
 * CUDA natively supports `int32_t`, `uint32_t`, `uint64_t`, `float`, `double.
 * (`double` is supported after Pascal).
 * Other types are implemented by `atomicCAS`.
 *
 * @param address The address of old value in global or shared memory
 * @param val The value to be added
 *
 * @returns The old value at `address`
 */
template <typename T>
__forceinline__ __device__ T atomic_add(T* address, T val)
{
  return cudf::detail::genericAtomicOperation(address, val, cudf::DeviceSum{});
}

/**
 * @brief Overloads for `atomic_mul`
 *
 * Reads the `old` located at the `address` in global or shared memory,
 * computes (old * val), and stores the result back to memory at the same
 * address. These three operations are performed in one atomic transaction.
 *
 * The supported cudf types for `atomicMul` are:
 * int8_t, int16_t, int32_t, int64_t, float, double, and bool
 *
 * All types are implemented by `atomicCAS`.
 *
 * @param address The address of old value in global or shared memory
 * @param val The value to be multiplied
 *
 * @returns The old value at `address`
 */
template <typename T>
__forceinline__ __device__ T atomic_mul(T* address, T val)
{
  return cudf::detail::genericAtomicOperation(address, val, cudf::DeviceProduct{});
}

/**
 * @brief Overloads for `atomic_min`
 *
 * Reads the `old` located at the `address` in global or shared memory,
 * computes the minimum of old and val, and stores the result back to memory
 * at the same address.
 * These three operations are performed in one atomic transaction.
 *
 * The supported cudf types for `atomic_min` are:
 * int8_t, int16_t, int32_t, int64_t, float, double,
 * cudf::timestamp_D, cudf::timestamp_s, cudf::timestamp_ms, cudf::timestamp_us,
 * cudf::timestamp_ns, cudf::duration_D, cudf::duration_s, cudf::duration_ms,
 * cudf::duration_us, cudf::duration_ns and bool
 *
 * CUDA natively supports `int32_t`, `uint32_t`, `int64_t`, `uint64_t`.
 * Other types are implemented by `atomicCAS`.
 *
 * @param address The address of old value in global or shared memory
 * @param val The value to be computed
 *
 * @returns The old value at `address`
 */
template <typename T>
__forceinline__ __device__ T atomic_min(T* address, T val)
{
  return cudf::detail::genericAtomicOperation(address, val, cudf::DeviceMin{});
}

/**
 * @brief Overloads for `atomic_max`
 *
 * Reads the `old` located at the `address` in global or shared memory,
 * computes the maximum of old and val, and stores the result back to memory
 * at the same address.
 * These three operations are performed in one atomic transaction.
 *
 * The supported cudf types for `atomic_max` are:
 * int8_t, int16_t, int32_t, int64_t, float, double,
 * cudf::timestamp_D, cudf::timestamp_s, cudf::timestamp_ms, cudf::timestamp_us,
 * cudf::timestamp_ns, cudf::duration_D, cudf::duration_s, cudf::duration_ms,
 * cudf::duration_us, cudf::duration_ns and bool
 *
 * CUDA natively supports `int32_t`, `uint32_t`, `int64_t`, `uint64_t`.
 * Other types are implemented by `atomicCAS`.
 *
 * @param address The address of old value in global or shared memory
 * @param val The value to be computed
 *
 * @returns The old value at `address`
 */
template <typename T>
__forceinline__ __device__ T atomic_max(T* address, T val)
{
  return cudf::detail::genericAtomicOperation(address, val, cudf::DeviceMax{});
}

/**
 * @brief Overloads for `atomic_cas`
 *
 * Reads the `old` located at the `address` in global or shared memory,
 * computes (`old` == `compare` ? `val` : `old`),
 * and stores the result back to memory at the same address.
 * These three operations are performed in one atomic transaction.
 *
 * The supported cudf types for `atomic_cas` are:
 * int8_t, int16_t, int32_t, int64_t, float, double,
 * cudf::timestamp_D, cudf::timestamp_s, cudf::timestamp_ms, cudf::timestamp_us,
 * cudf::timestamp_ns, cudf::duration_D, cudf::duration_s, cudf::duration_ms,
 * cudf::duration_us, cudf::duration_ns and bool
 * CUDA natively supports `int32_t`, `uint32_t`, `uint64_t`.
 * Other types are implemented by `atomicCAS`.
 *
 * @param address The address of old value in global or shared memory
 * @param compare The value to be compared
 * @param val The value to be computed
 *
 * @returns The old value at `address`
 */
template <typename T>
__forceinline__ __device__ T atomic_cas(T* address, T compare, T val)
{
  return cudf::detail::typesAtomicCASImpl<T>()(address, compare, val);
}

/**
 * @brief Helper function to calculate carry for 64-bit addition
 *
 * @param old_val The original 64-bit value
 * @param add_val The value being added
 * @param carry_in Carry from previous addition
 * @return 1 if carry is generated, 0 otherwise
 */
__device__ __forceinline__ uint64_t calculate_carry_64(uint64_t old_val,
                                                       uint64_t add_val,
                                                       uint64_t carry_in)
{
  // Use __uint128_t to detect overflow beyond 64-bit range
  __uint128_t sum = static_cast<__uint128_t>(old_val) + add_val + carry_in;
  return sum > cuda::std::numeric_limits<uint64_t>::max();
}

/**
 * @brief Atomic addition for __int128_t with architecture-specific optimization
 *
 * Uses native 128-bit CAS on Hopper+ GPUs (compute capability 9.0+) for optimal
 * performance. Falls back to two 64-bit atomic CAS operations with carry propagation
 * on older GPU architectures.
 *
 * @param address Pointer to the __int128_t value
 * @param val Value to add
 * @return The old value before addition
 */
__forceinline__ __device__ __int128_t atomic_add(__int128_t* address, __int128_t val)
{
#if __CUDA_ARCH__ >= 900
  __int128_t expected, desired;

  do {
    expected = *address;
    desired  = expected + val;
  } while (atomicCAS(address, expected, desired) != expected);

  return expected;
#else
  uint64_t* const target_ptr         = reinterpret_cast<uint64_t*>(address);
  __uint128_t const add_val_unsigned = static_cast<__uint128_t>(val);

  // Split the 128-bit add value into two 64-bit parts
  uint64_t const add_low  = static_cast<uint64_t>(add_val_unsigned);
  uint64_t const add_high = static_cast<uint64_t>(add_val_unsigned >> 64);

  uint64_t carry = 0;
  uint64_t old_parts[2];
  auto atomic_add_word = [&](int i, uint64_t current_add) {
    uint64_t expected_part, new_part;
    cuda::atomic_ref<uint64_t, cuda::thread_scope_device> atomic_part{target_ptr[i]};

    do {
      expected_part = atomic_part.load();
      new_part      = expected_part + current_add + carry;
    } while (
      !atomic_part.compare_exchange_weak(expected_part, new_part, cuda::memory_order_relaxed));

    old_parts[i] = expected_part;
    carry        = calculate_carry_64(expected_part, current_add, carry);
  };

  atomic_add_word(0, add_low);
  atomic_add_word(1, add_high);

  __uint128_t const old_val_unsigned =
    (static_cast<__uint128_t>(old_parts[1]) << 64) | old_parts[0];
  return static_cast<__int128_t>(old_val_unsigned);
#endif
}

}  // namespace detail
}  // namespace cudf
