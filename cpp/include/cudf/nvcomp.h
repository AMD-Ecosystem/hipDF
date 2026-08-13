// MIT License
//
// Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
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

#include "hipcomp.h"
#include "hipcomp/lz4.h"

#include "cudf/nvcomp/snappy.h"

#ifndef NVCOMP_MAJOR_VERSION
#  define NVCOMP_MAJOR_VERSION HIPCOMP_MAJOR_VERSION
#endif
#ifndef NVCOMP_MINOR_VERSION
#  define NVCOMP_MINOR_VERSION HIPCOMP_MINOR_VERSION
#endif
#ifndef NVCOMP_PATCH_VERSION
#  define NVCOMP_PATCH_VERSION HIPCOMP_PATCH_VERSION
#endif

#ifndef nvcompBatchedDeflateCompressAsync
#  define nvcompBatchedDeflateCompressAsync hipcompBatchedDeflateCompressAsync
#endif
#ifndef nvcompBatchedDeflateCompressGetMaxOutputChunkSize
#  define nvcompBatchedDeflateCompressGetMaxOutputChunkSize hipcompBatchedDeflateCompressGetMaxOutputChunkSize
#endif
#ifndef nvcompBatchedDeflateCompressGetTempSize
#  define nvcompBatchedDeflateCompressGetTempSize hipcompBatchedDeflateCompressGetTempSize
#endif
#ifndef nvcompBatchedDeflateCompressGetTempSizeEx
#  define nvcompBatchedDeflateCompressGetTempSizeEx hipcompBatchedDeflateCompressGetTempSizeEx
#endif
#ifndef nvcompBatchedDeflateDecompressAsync
#  define nvcompBatchedDeflateDecompressAsync hipcompBatchedDeflateDecompressAsync
#endif
#ifndef nvcompBatchedDeflateDecompressGetTempSize
#  define nvcompBatchedDeflateDecompressGetTempSize hipcompBatchedDeflateDecompressGetTempSize
#endif
#ifndef nvcompBatchedDeflateDefaultOpts
#  define nvcompBatchedDeflateDefaultOpts hipcompBatchedDeflateDefaultOpts
#endif
#ifndef nvcompBatchedLZ4CompressAsync
#  define nvcompBatchedLZ4CompressAsync hipcompBatchedLZ4CompressAsync
#endif
#ifndef nvcompBatchedLZ4CompressGetTempSize
#  define nvcompBatchedLZ4CompressGetTempSize hipcompBatchedLZ4CompressGetTempSize
#endif
#ifndef nvcompBatchedLZ4CompressGetMaxOutputChunkSize
# define nvcompBatchedLZ4CompressGetMaxOutputChunkSize hipcompBatchedLZ4CompressGetMaxOutputChunkSize
#endif
#ifndef nvcompBatchedLZ4DecompressAsync
#  define nvcompBatchedLZ4DecompressAsync hipcompBatchedLZ4DecompressAsync
#endif
#ifndef nvcompBatchedLZ4GetDecompressSizeAsync
#  define nvcompBatchedLZ4GetDecompressSizeAsync hipcompBatchedLZ4GetDecompressSizeAsync
#endif
#ifndef nvcompBatchedLZ4DecompressGetTempSize
#  define nvcompBatchedLZ4DecompressGetTempSize hipcompBatchedLZ4DecompressGetTempSize
#endif
#ifndef nvcompBatchedLZ4DefaultOpts
#  define nvcompBatchedLZ4DefaultOpts hipcompBatchedLZ4DefaultOpts
#endif
#ifndef nvcompBatchedZstdCompressAsync
#  define nvcompBatchedZstdCompressAsync hipcompBatchedZstdCompressAsync
#endif
#ifndef nvcompBatchedZstdCompressGetMaxOutputChunkSize
#  define nvcompBatchedZstdCompressGetMaxOutputChunkSize hipcompBatchedZstdCompressGetMaxOutputChunkSize
#endif
#ifndef nvcompBatchedZstdCompressGetTempSize
#  define nvcompBatchedZstdCompressGetTempSize hipcompBatchedZstdCompressGetTempSize
#endif
#ifndef nvcompBatchedZstdCompressGetTempSizeEx
#  define nvcompBatchedZstdCompressGetTempSizeEx hipcompBatchedZstdCompressGetTempSizeEx
#endif
#ifndef nvcompBatchedZstdDecompressAsync
#  define nvcompBatchedZstdDecompressAsync hipcompBatchedZstdDecompressAsync
#endif
#ifndef nvcompBatchedZstdDecompressGetTempSize
#  define nvcompBatchedZstdDecompressGetTempSize hipcompBatchedZstdDecompressGetTempSize
#endif
#ifndef nvcompBatchedZstdDecompressGetTempSizeEx
#  define nvcompBatchedZstdDecompressGetTempSizeEx hipcompBatchedZstdDecompressGetTempSizeEx
#endif
#ifndef nvcompBatchedZstdDefaultOpts
#  define nvcompBatchedZstdDefaultOpts hipcompBatchedZstdDefaultOpts
#endif
#ifndef nvcompBatchedGzipDecompressAsync
#  define nvcompBatchedGzipDecompressAsync hipcompBatchedGzipDecompressAsync
#endif
#ifndef nvcompBatchedGzipDecompressGetTempSize
#  define nvcompBatchedGzipDecompressGetTempSize hipcompBatchedGzipDecompressGetTempSize
#endif
#ifndef nvcompConfigTest
#  define nvcompConfigTest hipcompConfigTest
#endif
#ifndef nvcompErrorInternal
#  define nvcompErrorInternal hipcompErrorInternal
#endif
#ifndef nvcompLZ4RequiredAlignment
#  define nvcompLZ4RequiredAlignment hipcompLZ4RequiredAlignment
#endif
#ifndef nvcompSnappyRequiredAlignment
#  define nvcompSnappyRequiredAlignment hipcompSnappyRequiredAlignment
#endif
#ifndef nvcompStatus_t
#  define nvcompStatus_t hipcompStatus_t
#endif
#ifndef nvcompSuccess
#  define nvcompSuccess hipcompSuccess
#endif
#ifndef nvcompZstdCompressionMaxAllowedChunkSize
#  define nvcompZstdCompressionMaxAllowedChunkSize hipcompZstdCompressionMaxAllowedChunkSize
#endif

// TODO(HIP/AMD, <HIPCOMP-API>): the 26.06 nvcomp API splits the per-algorithm options into separate
// Compress/Decompress *DefaultOpts VALUE constants. hipcomp 2.3.0 instead exposes opts
// TYPES (combined hipcompBatched{Snappy,LZ4}Opts_t for Snappy/LZ4; split
// hipcompBatched{Deflate,Zstd,Gzip}{Compress,Decompress}Opts_t) and provides NO matching
// DefaultOpts value constants. Map each split DefaultOpts the adapter uses to a
// value-initialized instance of the hipcomp opts type that that algo's async/get-temp-size
// signature expects.
#include "hipcomp/deflate.h"
#include "hipcomp/gzip.h"
#include "hipcomp/snappy.h"
#include "hipcomp/zstd.h"

// Snappy / LZ4 use a single combined opts type for both directions.
#ifndef nvcompBatchedSnappyCompressDefaultOpts
#  define nvcompBatchedSnappyCompressDefaultOpts (hipcompBatchedSnappyOpts_t{})
#endif
#ifndef nvcompBatchedSnappyDecompressDefaultOpts
#  define nvcompBatchedSnappyDecompressDefaultOpts (hipcompBatchedSnappyOpts_t{})
#endif
#ifndef nvcompBatchedLZ4CompressDefaultOpts
#  define nvcompBatchedLZ4CompressDefaultOpts (hipcompBatchedLZ4Opts_t{})
#endif
#ifndef nvcompBatchedLZ4DecompressDefaultOpts
#  define nvcompBatchedLZ4DecompressDefaultOpts (hipcompBatchedLZ4Opts_t{})
#endif

// Deflate / Zstd / Gzip use split per-direction opts types in hipcomp.
#ifndef nvcompBatchedDeflateCompressDefaultOpts
#  define nvcompBatchedDeflateCompressDefaultOpts (hipcompBatchedDeflateCompressOpts_t{})
#endif
#ifndef nvcompBatchedDeflateDecompressDefaultOpts
#  define nvcompBatchedDeflateDecompressDefaultOpts (hipcompBatchedDeflateDecompressOpts_t{})
#endif
#ifndef nvcompBatchedZstdCompressDefaultOpts
#  define nvcompBatchedZstdCompressDefaultOpts (hipcompBatchedZstdCompressOpts_t{})
#endif
#ifndef nvcompBatchedZstdDecompressDefaultOpts
#  define nvcompBatchedZstdDecompressDefaultOpts (hipcompBatchedZstdDecompressOpts_t{})
#endif
#ifndef nvcompBatchedGzipCompressDefaultOpts
#  define nvcompBatchedGzipCompressDefaultOpts (hipcompBatchedGzipCompressOpts_t{})
#endif
#ifndef nvcompBatchedGzipDecompressDefaultOpts
#  define nvcompBatchedGzipDecompressDefaultOpts (hipcompBatchedGzipDecompressOpts_t{})
#endif
