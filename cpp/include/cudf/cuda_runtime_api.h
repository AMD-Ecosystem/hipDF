// MIT License
//
// Copyright (c) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

// NOTE(HIP/AMD): inclusion of this header into jitified programs
// causes duplicate symbol definition errors for HIP headers/hiprtc_runtime.h.
#ifndef __HIPCC_RTC__
#include <hip/hip_runtime_api.h>
#endif

// NOTE(HIP/AMD): For the time being, we do not use reverse hipification header files
//                for hipcub/cub and hip/curand as their usage is limited across
//                the project.

// PTDS
#if defined(CUDA_API_PER_THREAD_DEFAULT_STREAM) && !defined(HIP_API_PER_THREAD_DEFAULT_STREAM)
  #define HIP_API_PER_THREAD_DEFAULT_STREAM
#endif

#if defined(hipStreamDefault) && !defined(cudaStreamDefault)
#  define cudaStreamDefault hipStreamDefault
#endif

#if defined(hipStreamLegacy) && !defined(cudaStreamLegacy)
#  define cudaStreamLegacy hipStreamLegacy
#endif

#if defined(hipStreamPerThread) && !defined(cudaStreamPerThread)
#  define cudaStreamPerThread hipStreamPerThread
#endif

// Simple hipification mappings
#ifndef cudaArray_const_t
#  define cudaArray_const_t hipArray_const_t
#endif
#ifndef CUarray
#  define CUarray hipArray_t
#endif
#ifndef cudaArray_t
#  define cudaArray_t hipArray_t
#endif
#ifndef CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR
#  define CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR hipDeviceAttributeComputeCapabilityMajor
#endif
#ifndef cudaDevAttrComputeCapabilityMajor
#  define cudaDevAttrComputeCapabilityMajor hipDeviceAttributeComputeCapabilityMajor
#endif
#ifndef CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR
#  define CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR hipDeviceAttributeComputeCapabilityMinor
#endif
#ifndef cudaDevAttrComputeCapabilityMinor
#  define cudaDevAttrComputeCapabilityMinor hipDeviceAttributeComputeCapabilityMinor
#endif
#ifndef CU_DEVICE_ATTRIBUTE_L2_CACHE_SIZE
#  define CU_DEVICE_ATTRIBUTE_L2_CACHE_SIZE hipDeviceAttributeL2CacheSize
#endif
#ifndef cudaDevAttrL2CacheSize
#  define cudaDevAttrL2CacheSize hipDeviceAttributeL2CacheSize
#endif
#ifndef CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK
#  define CU_DEVICE_ATTRIBUTE_MAX_SHARED_MEMORY_PER_BLOCK hipDeviceAttributeMaxSharedMemoryPerBlock
#endif
#ifndef CU_DEVICE_ATTRIBUTE_SHARED_MEMORY_PER_BLOCK
#  define CU_DEVICE_ATTRIBUTE_SHARED_MEMORY_PER_BLOCK hipDeviceAttributeMaxSharedMemoryPerBlock
#endif
#ifndef cudaDevAttrMaxSharedMemoryPerBlock
#  define cudaDevAttrMaxSharedMemoryPerBlock hipDeviceAttributeMaxSharedMemoryPerBlock
#endif
#ifndef cudaDevAttrMaxSharedMemoryPerMultiprocessor
#  define cudaDevAttrMaxSharedMemoryPerMultiprocessor hipDeviceAttributeMaxSharedMemoryPerMultiprocessor
#endif
#ifndef cudaDevAttrMaxThreadsPerMultiprocessor
#  define cudaDevAttrMaxThreadsPerMultiprocessor hipDeviceAttributeMaxThreadsPerMultiProcessor
#endif
#ifndef CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT
#  define CU_DEVICE_ATTRIBUTE_MULTIPROCESSOR_COUNT hipDeviceAttributeMultiprocessorCount
#endif
#ifndef cudaDevAttrMultiProcessorCount
#  define cudaDevAttrMultiProcessorCount hipDeviceAttributeMultiprocessorCount
#endif
#ifndef cuDeviceGetAttribute
#  define cuDeviceGetAttribute hipDeviceGetAttribute
#endif
#ifndef cudaDeviceAttributeComputeCapabilityMajor
#  define cudaDeviceAttributeComputeCapabilityMajor hipDeviceAttributeComputeCapabilityMajor
#endif
#ifndef cudaDeviceAttributeComputeCapabilityMinor
#  define cudaDeviceAttributeComputeCapabilityMinor hipDeviceAttributeComputeCapabilityMinor
#endif
#ifndef cudaDeviceGetAttribute
#  define cudaDeviceGetAttribute hipDeviceGetAttribute
#endif
#ifndef cudaDeviceProp
#  define cudaDeviceProp hipDeviceProp_t
#endif
#ifndef cudaDeviceSynchronize
#  define cudaDeviceSynchronize hipDeviceSynchronize
#endif
#ifndef cudaThreadSynchronize
#  define cudaThreadSynchronize hipDeviceSynchronize
#endif
#ifndef CUdevice
#  define CUdevice hipDevice_t
#endif
#ifndef CUdevice_v1
#  define CUdevice_v1 hipDevice_t
#endif
#ifndef CUDA_ERROR_ASSERT
#  define CUDA_ERROR_ASSERT hipErrorAssert
#endif
#ifndef cudaErrorAssert
#  define cudaErrorAssert hipErrorAssert
#endif
#ifndef cudaErrorInvalidConfiguration
#  define cudaErrorInvalidConfiguration hipErrorInvalidConfiguration
#endif
#ifndef CUDA_ERROR_INVALID_DEVICE
#  define CUDA_ERROR_INVALID_DEVICE hipErrorInvalidDevice
#endif
#ifndef cudaErrorInvalidDevice
#  define cudaErrorInvalidDevice hipErrorInvalidDevice
#endif
#ifndef CUDA_ERROR_INVALID_VALUE
#  define CUDA_ERROR_INVALID_VALUE hipErrorInvalidValue
#endif
#ifndef cudaErrorInvalidValue
#  define cudaErrorInvalidValue hipErrorInvalidValue
#endif
#ifndef CUDA_ERROR_LAUNCH_FAILED
#  define CUDA_ERROR_LAUNCH_FAILED hipErrorLaunchFailure
#endif
#ifndef cudaErrorLaunchFailure
#  define cudaErrorLaunchFailure hipErrorLaunchFailure
#endif
#ifndef cudaErrorNotReady
#  define cudaErrorNotReady hipErrorNotReady
#endif
#ifndef CUresult
#  define CUresult hipError_t
#endif
#ifndef cudaError
#  define cudaError hipError_t
#endif
#ifndef cudaError_enum
#  define cudaError_enum hipError_t
#endif
#ifndef cudaError_t
#  define cudaError_t hipError_t
#endif
#ifndef CUDA_ERROR_UNKNOWN
#  define CUDA_ERROR_UNKNOWN hipErrorUnknown
#endif
#ifndef cudaErrorUnknown
#  define cudaErrorUnknown hipErrorUnknown
#endif
#ifndef cudaEventBlockingSync
#  define cudaEventBlockingSync hipEventBlockingSync
#endif
#ifndef cudaEventCreate
#  define cudaEventCreate hipEventCreate
#endif
#ifndef cuEventDestroy
#  define cuEventDestroy hipEventDestroy
#endif
#ifndef cuEventDestroy_v2
#  define cuEventDestroy_v2 hipEventDestroy
#endif
#ifndef cudaEventDestroy
#  define cudaEventDestroy hipEventDestroy
#endif
#ifndef cuEventElapsedTime
#  define cuEventElapsedTime hipEventElapsedTime
#endif
#ifndef cudaEventElapsedTime
#  define cudaEventElapsedTime hipEventElapsedTime
#endif
#ifndef cuEventRecord
#  define cuEventRecord hipEventRecord
#endif
#ifndef cudaEventRecord
#  define cudaEventRecord hipEventRecord
#endif
#ifndef cuEventSynchronize
#  define cuEventSynchronize hipEventSynchronize
#endif
#ifndef cudaEventSynchronize
#  define cudaEventSynchronize hipEventSynchronize
#endif
#ifndef cudaEventQuery
#  define cudaEventQuery hipEventQuery
#endif
#ifndef CUevent
#  define CUevent hipEvent_t
#endif
#ifndef cudaEvent_t
#  define cudaEvent_t hipEvent_t
#endif
#ifndef cudaExtent
#  define cudaExtent hipExtent
#endif
#ifndef cuMemFree
#  define cuMemFree hipFree
#endif
#ifndef cuMemFree_v2
#  define cuMemFree_v2 hipFree
#endif
#ifndef cudaFree
#  define cudaFree hipFree
#endif
#ifndef cudaFreeAsync
#  define cudaFreeAsync hipFreeAsync
#endif
#ifndef cuMemFreeAsync
#  define cuMemFreeAsync hipFreeAsync
#endif
#ifndef cudaFuncAttributes
#  define cudaFuncAttributes hipFuncAttributes
#endif
#ifndef cudaFuncGetAttributes
#  define cudaFuncGetAttributes hipFuncGetAttributes
#endif
#ifndef cudaGetDevice
#  define cudaGetDevice hipGetDevice
#endif
#ifndef cuDeviceGetCount
#  define cuDeviceGetCount hipGetDeviceCount
#endif
#ifndef cudaGetDeviceCount
#  define cudaGetDeviceCount hipGetDeviceCount
#endif
#ifndef cudaGetDeviceProperties
#  define cudaGetDeviceProperties hipGetDeviceProperties
#endif
#ifndef cudaGetErrorName
#  define cudaGetErrorName hipGetErrorName
#endif
#ifndef cudaGetErrorString
#  define cudaGetErrorString hipGetErrorString
#endif
#ifndef cudaGetLastError
#  define cudaGetLastError hipGetLastError
#endif
#ifndef cudaGetSymbolAddress
#  define cudaGetSymbolAddress hipGetSymbolAddress
#endif
#ifndef CUhostFn
#  define CUhostFn hipHostFn_t
#endif
#ifndef cudaHostFn_t
#  define cudaHostFn_t hipHostFn_t
#endif
#ifndef cuMemFreeHost
#  define cuMemFreeHost hipHostFree
#endif
#ifndef cudaFreeHost
#  define cudaFreeHost hipHostFree
#endif
#ifndef cudaMallocHost
#  define cudaMallocHost hipHostMalloc
#endif
#ifndef cuMemHostRegister
#  define cuMemHostRegister hipHostRegister
#endif
#ifndef cuMemHostRegister_v2
#  define cuMemHostRegister_v2 hipHostRegister
#endif
#ifndef cudaHostRegister
#  define cudaHostRegister hipHostRegister
#endif
#ifndef cudaHostRegisterDefault
#  define cudaHostRegisterDefault hipHostRegisterDefault
#endif
#ifndef cuMemHostUnregister
#  define cuMemHostUnregister hipHostUnregister
#endif
#ifndef cudaHostUnregister
#  define cudaHostUnregister hipHostUnregister
#endif
#ifndef cudaInvalidDeviceId
#  define cudaInvalidDeviceId hipInvalidDeviceId
#endif
#ifndef cudaLaunchCooperativeKernel
#  define cudaLaunchCooperativeKernel hipLaunchCooperativeKernel
#endif
#ifndef cuLaunchHostFunc
#  define cuLaunchHostFunc hipLaunchHostFunc
#endif
#ifndef cudaLaunchHostFunc
#  define cudaLaunchHostFunc hipLaunchHostFunc
#endif
#ifndef cudaLaunchKernel
#  define cudaLaunchKernel hipLaunchKernel
#endif
#ifndef cudaMallocAsync
#  define cudaMallocAsync hipMallocAsync
#endif
#ifndef cuMemAllocAsync
#  define cuMemAllocAsync hipMallocAsync
#endif
#ifndef cudaMallocFromPoolAsync
#  define cudaMallocFromPoolAsync hipMallocFromPoolAsync
#endif
#ifndef cuMemAllocFromPoolAsync
#  define cuMemAllocFromPoolAsync hipMallocFromPoolAsync
#endif
#ifndef cuMemAllocManaged
#  define cuMemAllocManaged hipMallocManaged
#endif
#ifndef cudaMallocManaged
#  define cudaMallocManaged hipMallocManaged
#endif
#ifndef cudaMemcpy
#  define cudaMemcpy hipMemcpy
#endif
#ifndef cudaMemcpy2DAsync
#  define cudaMemcpy2DAsync hipMemcpy2DAsync
#endif
#ifndef cudaMemcpy2DFromArrayAsync
#  define cudaMemcpy2DFromArrayAsync hipMemcpy2DFromArrayAsync
#endif
#ifndef cudaMemcpy2DToArrayAsync
#  define cudaMemcpy2DToArrayAsync hipMemcpy2DToArrayAsync
#endif
#ifndef cudaMemcpy3DAsync
#  define cudaMemcpy3DAsync hipMemcpy3DAsync
#endif
#ifndef cudaMemcpy3DParms
#  define cudaMemcpy3DParms hipMemcpy3DParms
#endif
#ifndef cudaMemcpyAsync
#  define cudaMemcpyAsync hipMemcpyAsync
#endif
#ifndef cudaMemcpyDefault
#  define cudaMemcpyDefault hipMemcpyDefault
#endif
#ifndef cudaMemcpyDeviceToHost
#  define cudaMemcpyDeviceToHost hipMemcpyDeviceToHost
#endif
#ifndef cudaMemcpyFromSymbolAsync
#  define cudaMemcpyFromSymbolAsync hipMemcpyFromSymbolAsync
#endif
#ifndef cudaMemcpyKind
#  define cudaMemcpyKind hipMemcpyKind
#endif
#ifndef cudaMemcpyToSymbol
#  define cudaMemcpyToSymbol hipMemcpyToSymbol
#endif
#ifndef cudaMemcpyToSymbolAsync
#  define cudaMemcpyToSymbolAsync hipMemcpyToSymbolAsync
#endif
#ifndef cudaMemoryTypeManaged
#  define cudaMemoryTypeManaged hipMemoryTypeManaged
#endif
#ifndef CUmemoryPool
#  define CUmemoryPool hipMemPool_t
#endif
#ifndef cudaMemPool_t
#  define cudaMemPool_t hipMemPool_t
#endif
#ifndef cudaMemPrefetchAsync
#  define cudaMemPrefetchAsync hipMemPrefetchAsync
#endif
#ifndef cuMemPrefetchAsync
#  define cuMemPrefetchAsync hipMemPrefetchAsync
#endif
#ifndef cudaMemset
#  define cudaMemset hipMemset
#endif
#ifndef cudaMemset2DAsync
#  define cudaMemset2DAsync hipMemset2DAsync
#endif
#ifndef cudaMemset3DAsync
#  define cudaMemset3DAsync hipMemset3DAsync
#endif
#ifndef cudaMemsetAsync
#  define cudaMemsetAsync hipMemsetAsync
#endif
#ifndef cudaOccupancyMaxActiveBlocksPerMultiprocessor
#  define cudaOccupancyMaxActiveBlocksPerMultiprocessor hipOccupancyMaxActiveBlocksPerMultiprocessor
#endif
#ifndef cudaOccupancyMaxPotentialBlockSize
#  define cudaOccupancyMaxPotentialBlockSize hipOccupancyMaxPotentialBlockSize
#endif
#ifndef cudaPeekAtLastError
#  define cudaPeekAtLastError hipPeekAtLastError
#endif
#ifndef cudaPitchedPtr
#  define cudaPitchedPtr hipPitchedPtr
#endif
#ifndef cudaPointerAttributes
#  define cudaPointerAttributes hipPointerAttribute_t
#endif
#ifndef cudaPointerGetAttributes
#  define cudaPointerGetAttributes hipPointerGetAttributes
#endif
#ifndef curandState
#  define curandState hiprandState
#endif
#ifndef cudaRuntimeGetVersion
#  define cudaRuntimeGetVersion hipRuntimeGetVersion
#endif
#ifndef cudaSetDevice
#  define cudaSetDevice hipSetDevice
#endif
#ifndef cudaStreamCreate
#  define cudaStreamCreate hipStreamCreate
#endif
#ifndef cudaStreamCreateWithFlags
#  define cudaStreamCreateWithFlags hipStreamCreateWithFlags
#endif
#ifndef CU_STREAM_DEFAULT
#  define CU_STREAM_DEFAULT hipStreamDefault
#endif
#ifndef cudaStreamDefault
#  define cudaStreamDefault hipStreamDefault
#endif
#ifndef cudaStreamNonBlocking
#  define cudaStreamNonBlocking hipStreamNonBlocking
#endif
#ifndef CU_STREAM_PER_THREAD
#  define CU_STREAM_PER_THREAD hipStreamPerThread
#endif
#ifndef cudaStreamPerThread
#  define cudaStreamPerThread hipStreamPerThread
#endif
#ifndef cuStreamSynchronize
#  define cuStreamSynchronize hipStreamSynchronize
#endif
#ifndef cudaStreamSynchronize
#  define cudaStreamSynchronize hipStreamSynchronize
#endif
#ifndef CUstream
#  define CUstream hipStream_t
#endif
#ifndef cudaStream_t
#  define cudaStream_t hipStream_t
#endif
#ifndef cuStreamWaitEvent
#  define cuStreamWaitEvent hipStreamWaitEvent
#endif
#ifndef cudaStreamWaitEvent
#  define cudaStreamWaitEvent hipStreamWaitEvent
#endif
#ifndef CUDA_SUCCESS
#  define CUDA_SUCCESS hipSuccess
#endif
#ifndef cudaMemcpyDeviceToDevice
#  define cudaMemcpyDeviceToDevice hipMemcpyDeviceToDevice
#endif
#ifndef cudaMemcpyHostToDevice
#  define cudaMemcpyHostToDevice hipMemcpyHostToDevice
#endif
#ifndef cudaSuccess
#  define cudaSuccess hipSuccess
#endif
#ifndef cudaLimitMallocHeapSize
#  define cudaLimitMallocHeapSize hipLimitMallocHeapSize
#endif
#ifndef cudaDeviceSetLimit
#  define cudaDeviceSetLimit hipDeviceSetLimit
#endif
#ifndef cudaDeviceGetLimit
#  define cudaDeviceGetLimit hipDeviceGetLimit
#endif
