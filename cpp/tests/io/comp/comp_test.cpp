/*
 * Copyright (c) 2019-2025, NVIDIA CORPORATION.
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

#include "io/comp/compression.hpp"
#include "io/comp/decompression.hpp"
#include "io/comp/gpuinflate.hpp"
#include "io/utilities/hostdevice_vector.hpp"

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/testing_main.hpp>

#include <cudf/io/types.hpp>
#include <cudf/utilities/default_stream.hpp>

#include <rmm/device_buffer.hpp>
#include <rmm/device_uvector.hpp>

#include <src/io/comp/nvcomp_adapter.hpp>

#include <vector>

using cudf::device_span;
using cudf::io::detail::codec_exec_result;
using cudf::io::detail::codec_status;
namespace nvcomp = cudf::io::detail::nvcomp;

enum class hw { CPU, GPU };

/**
 * @brief Base test fixture for decompression
 *
 * Calls into Decompressor fixture to dispatch actual decompression work,
 * whose interface and setup is different for each codec.
 */
template <typename Decompressor>
struct DecompressTest
  : public cudf::test::BaseFixture,
    public testing::WithParamInterface<std::tuple<hw, cudf::io::compression_type>> {
  [[nodiscard]] std::vector<uint8_t> vector_from_string(std::string const str) const
  {
    return {reinterpret_cast<uint8_t const*>(str.c_str()),
            reinterpret_cast<uint8_t const*>(str.c_str()) + strlen(str.c_str())};
  }

  std::vector<uint8_t> Decompress(std::tuple<hw, cudf::io::compression_type> type,
                                  cudf::host_span<uint8_t const> compressed,
                                  size_t uncompressed_size)
  {
    auto hw_type   = std::get<0>(GetParam());
    auto comp_type = std::get<1>(GetParam());
    if (hw_type == hw::GPU) {
      if constexpr (has_gpu_impl<Decompressor>::value) {
        return DeviceDecompress(compressed, uncompressed_size);
      } else {
        CUDF_FAIL("Device decompression has not been implemented");
      }
    } else {
      if constexpr (has_cpu_impl<Decompressor>::value) {
        return HostDecompress(comp_type, compressed, uncompressed_size);
      } else {
        CUDF_FAIL("Host decompression has not been implemented");
      }
    }
  }

  std::vector<uint8_t> DeviceDecompress(cudf::host_span<uint8_t const> compressed,
                                        size_t uncompressed_size)
  {
    auto stream = cudf::get_default_stream();
    std::vector<uint8_t> decompressed(uncompressed_size);
    rmm::device_buffer src{compressed.data(), compressed.size(), stream};
    rmm::device_uvector<uint8_t> dst{decompressed.size(), stream};

    cudf::detail::hostdevice_vector<device_span<uint8_t const>> inf_in(1, stream);
    inf_in[0] = {static_cast<uint8_t const*>(src.data()), src.size()};
    inf_in.host_to_device_async(stream);

    cudf::detail::hostdevice_vector<device_span<uint8_t>> inf_out(1, stream);
    inf_out[0] = dst;
    inf_out.host_to_device_async(stream);

    cudf::detail::hostdevice_vector<codec_exec_result> inf_stat(1, stream);
    inf_stat[0] = {};
    inf_stat.host_to_device_async(stream);

    static_cast<Decompressor*>(this)->device_dispatch(inf_in, inf_out, inf_stat);
    CUDF_CUDA_TRY(cudaMemcpyAsync(
      decompressed.data(), dst.data(), dst.size(), cudaMemcpyDefault, stream.value()));
    inf_stat.device_to_host(stream);
    CUDF_EXPECTS(inf_stat[0].status == codec_status::SUCCESS, "Failure in device decompression");

    return decompressed;
  }

  std::vector<uint8_t> HostDecompress(cudf::io::compression_type comp_type,
                                      cudf::host_span<uint8_t const> compressed,
                                      size_t uncompressed_size)
  {
    return static_cast<Decompressor*>(this)->host_dispatch(
      comp_type, compressed, uncompressed_size);
  }

  template <typename T, typename = void>
  struct has_gpu_impl : std::false_type {};

  template <typename T>
  struct has_gpu_impl<T, std::void_t<decltype(&T::device_dispatch)>> : std::true_type {};

  template <typename T, typename = void>
  struct has_cpu_impl : std::false_type {};

  template <typename T>
  struct has_cpu_impl<T, std::void_t<decltype(&T::host_dispatch)>> : std::true_type {};
};

struct HostCompressTest : public cudf::test::BaseFixture,
                          public ::testing::WithParamInterface<cudf::io::compression_type> {
  HostCompressTest()
  {
    setenv("LIBCUDF_HOST_COMPRESSION", "ON", 1);
    setenv("LIBCUDF_NVCOMP_POLICY", "ALWAYS", 1);
  }
  ~HostCompressTest() override
  {
    unsetenv("LIBCUDF_HOST_COMPRESSION");
    unsetenv("LIBCUDF_NVCOMP_POLICY");
  }
};

struct HostDecompressTest : public cudf::test::BaseFixture,
                            public ::testing::WithParamInterface<cudf::io::compression_type> {
  HostDecompressTest()
  {
    setenv("LIBCUDF_HOST_DECOMPRESSION", "ON", 1);
    setenv("LIBCUDF_NVCOMP_POLICY", "ALWAYS", 1);
  }
  ~HostDecompressTest() override
  {
    unsetenv("LIBCUDF_HOST_DECOMPRESSION");
    unsetenv("LIBCUDF_NVCOMP_POLICY");
  }
};

/**
 * @brief Derived fixture for GZIP decompression
 */
struct GzipDecompressTest : public DecompressTest<GzipDecompressTest> {
  void device_dispatch(device_span<device_span<uint8_t const>> d_inf_in,
                       device_span<device_span<uint8_t>> d_inf_out,
                       device_span<codec_exec_result> d_inf_stat)
  {
    cudf::io::detail::gpuinflate(d_inf_in,
                                 d_inf_out,
                                 d_inf_stat,
                                 cudf::io::detail::gzip_header_included::YES,
                                 cudf::get_default_stream());
  }

  std::vector<uint8_t> host_dispatch(cudf::io::compression_type comp_type,
                                     cudf::host_span<uint8_t const> compressed,
                                     size_t uncompressed_size)
  {
    CUDF_EXPECTS(uncompressed_size <= cudf::io::detail::get_uncompressed_size(
                                        cudf::io::compression_type::AUTO, compressed),
                 "Underestimating uncompressed size!");
    CUDF_EXPECTS(comp_type == cudf::io::compression_type::AUTO ||
                   comp_type == cudf::io::compression_type::GZIP,
                 "Invalid compression type");
    return cudf::io::detail::decompress(comp_type, compressed);
  }
};

/**
 * @brief Derived fixture for GZIP decompression
 */
struct ZstdDecompressTest : public DecompressTest<ZstdDecompressTest> {
  std::vector<uint8_t> host_dispatch(cudf::io::compression_type comp_type,
                                     cudf::host_span<uint8_t const> compressed,
                                     size_t uncompressed_size)
  {
    CUDF_EXPECTS(uncompressed_size <= cudf::io::detail::get_uncompressed_size(
                                        cudf::io::compression_type::AUTO, compressed),
                 "Underestimating uncompressed size!");
    CUDF_EXPECTS(comp_type == cudf::io::compression_type::AUTO ||
                   comp_type == cudf::io::compression_type::ZSTD,
                 "Invalid compression type");
    return cudf::io::detail::decompress(comp_type, compressed);
  }
};

/**
 * @brief Derived fixture for Snappy decompression
 */
struct SnappyDecompressTest : public DecompressTest<SnappyDecompressTest> {
  void device_dispatch(device_span<device_span<uint8_t const>> d_inf_in,
                       device_span<device_span<uint8_t>> d_inf_out,
                       device_span<codec_exec_result> d_inf_stat)
  {
    cudf::io::detail::gpu_unsnap(d_inf_in, d_inf_out, d_inf_stat, cudf::get_default_stream());
  }

  std::vector<uint8_t> host_dispatch(cudf::io::compression_type comp_type,
                                     cudf::host_span<uint8_t const> compressed,
                                     size_t uncompressed_size)
  {
    CUDF_EXPECTS(uncompressed_size <= cudf::io::detail::get_uncompressed_size(
                                        cudf::io::compression_type::AUTO, compressed),
                 "Underestimating uncompressed size!");
    CUDF_EXPECTS(comp_type == cudf::io::compression_type::AUTO ||
                   comp_type == cudf::io::compression_type::SNAPPY,
                 "Invalid compression type");
    return cudf::io::detail::decompress(comp_type, compressed);
  }
};

/**
 * @brief Derived fixture for Brotli decompression
 */
struct BrotliDecompressTest : public DecompressTest<BrotliDecompressTest> {
  void device_dispatch(device_span<device_span<uint8_t const>> d_inf_in,
                       device_span<device_span<uint8_t>> d_inf_out,
                       device_span<codec_exec_result> d_inf_stat)
  {
    rmm::device_buffer d_scratch{cudf::io::detail::get_gpu_debrotli_scratch_size(1),
                                 cudf::get_default_stream()};

    cudf::io::detail::gpu_debrotli(d_inf_in, d_inf_out, d_inf_stat, cudf::get_default_stream());
  }
};

INSTANTIATE_TEST_CASE_P(GzipDecompressTest,
                        GzipDecompressTest,
                        ::testing::Combine(::testing::Values(hw::CPU, hw::GPU),
                                           ::testing::Values(cudf::io::compression_type::AUTO,
                                                             cudf::io::compression_type::GZIP)));

TEST_P(GzipDecompressTest, HelloWorld)
{
  std::string const uncompressed{"hello world"};
  // NOLINTBEGIN
  constexpr std::array<uint8_t, 31> compressed{
    0x1f, 0x8b, 0x8,  0x0,  0x9,  0x63, 0x99, 0x5c, 0x2,  0xff, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57,
    0x28, 0xcf, 0x2f, 0xca, 0x49, 0x1,  0x0,  0x85, 0x11, 0x4a, 0xd,  0xb,  0x0,  0x0,  0x0};
  // NOLINTEND

  std::vector<uint8_t> input = vector_from_string(uncompressed);
  auto output                = Decompress(
    GetParam(), cudf::host_span<uint8_t const>(compressed.data(), compressed.size()), input.size());
  EXPECT_EQ(output, input);
}

INSTANTIATE_TEST_CASE_P(SnappyDecompressTest,
                        SnappyDecompressTest,
                        ::testing::Combine(::testing::Values(hw::CPU, hw::GPU),
                                           ::testing::Values(cudf::io::compression_type::AUTO,
                                                             cudf::io::compression_type::SNAPPY)));

TEST_P(SnappyDecompressTest, HelloWorld)
{
  std::string const uncompressed{"hello world"};
  // NOLINTBEGIN
  constexpr std::array<uint8_t, 13> compressed = {
    0xb, 0x28, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64};
  // NOLINTEND

  std::vector<uint8_t> input = vector_from_string(uncompressed);
  auto output                = Decompress(
    GetParam(), cudf::host_span<uint8_t const>(compressed.data(), compressed.size()), input.size());
  EXPECT_EQ(output, input);
}

TEST_P(SnappyDecompressTest, ShortLiteralAfterLongCopyAtStartup)
{
  std::string const uncompressed{"Aaaaaaaaaaaah!"};
  // NOLINTBEGIN
  constexpr std::array<uint8_t, 10> compressed = {
    14, 0x0, 'A', 0x0, 'a', (10 - 4) * 4 + 1, 1, 0x4, 'h', '!'};
  // NOLINTEND

  std::vector<uint8_t> input = vector_from_string(uncompressed);
  auto output                = Decompress(
    GetParam(), cudf::host_span<uint8_t const>(compressed.data(), compressed.size()), input.size());
  EXPECT_EQ(output, input);
}

INSTANTIATE_TEST_CASE_P(
  BrotliDecompressTest,
  BrotliDecompressTest,
  ::testing::Values(std::make_tuple(hw::GPU, cudf::io::compression_type::AUTO),
                    std::make_tuple(hw::GPU, cudf::io::compression_type::BROTLI)));

TEST_P(BrotliDecompressTest, HelloWorld)
{
  std::string const uncompressed{"hello world"};
  // NOLINTBEGIN
  constexpr std::array<uint8_t, 15> compressed = {
    0xb, 0x5, 0x80, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x3};
  // NOLINTEND

  std::vector<uint8_t> input = vector_from_string(uncompressed);
  auto output                = Decompress(
    GetParam(), cudf::host_span<uint8_t const>(compressed.data(), compressed.size()), input.size());
  EXPECT_EQ(output, input);
}

// NOTE(HIP/AMD): Enable ZSTD decompression tests (compression is not yet supported in hipcomp)
INSTANTIATE_TEST_CASE_P(
  ZstdDecompressTest,
  ZstdDecompressTest,
  ::testing::Values(std::make_tuple(hw::CPU, cudf::io::compression_type::AUTO),
                    std::make_tuple(hw::CPU, cudf::io::compression_type::ZSTD)));

TEST_P(ZstdDecompressTest, HelloWorld)
{
  std::string const uncompressed{"hello world"};
  std::vector<uint8_t> input = vector_from_string(uncompressed);
  auto compressed            = cudf::io::detail::compress(cudf::io::compression_type::ZSTD, input);
  auto output                = Decompress(
    GetParam(), cudf::host_span<uint8_t const>(compressed.data(), compressed.size()), input.size());
  EXPECT_EQ(output, input);
}

// NOTE(HIP/AMD): More tests to stress test hipcomp
// Test CPU compression followed by GPU decompression for ZSTD
// This validates that hipcomp GPU decompression works with CPU-compressed ZSTD data
TEST_F(ZstdDecompressTest, CpuCompressGpuDecompress)
{
  // Skip if device ZSTD decompression is not supported
  if (!cudf::io::detail::is_device_decompression_supported(cudf::io::compression_type::ZSTD)) {
    GTEST_SKIP() << "Device ZSTD decompression is not supported in this configuration";
  }

  // Set environment variables to enforce GPU decompression
  // LIBCUDF_HOST_DECOMPRESSION=OFF ensures we don't fall back to host path
  // LIBCUDF_NVCOMP_POLICY=ALWAYS ensures device path is always attempted
  setenv("LIBCUDF_HOST_DECOMPRESSION", "OFF", 1);
  setenv("LIBCUDF_NVCOMP_POLICY", "ALWAYS", 1);

  // Forward-looking: Enforce CPU compression for when hipcomp supports GPU compression
  // This ensures we're testing the specific path: CPU compress -> GPU decompress
  setenv("LIBCUDF_HOST_COMPRESSION", "ON", 1);

  auto const stream = cudf::get_default_stream();
  auto const mr     = rmm::mr::get_current_device_resource();

  // Create test data - use multiple chunks to stress GPU path
  // Each chunk is 256 KB, total 10 chunks = 2.5 MB
  constexpr size_t num_chunks      = 10;
  constexpr size_t chunk_size      = 256 * 1024;  // 256 KB per chunk
  constexpr size_t total_data_size = num_chunks * chunk_size;

  std::vector<std::vector<uint8_t>> expected_chunks(num_chunks);
  std::vector<std::vector<uint8_t>> compressed_chunks(num_chunks);

  // Create and compress each chunk on CPU
  for (size_t chunk_id = 0; chunk_id < num_chunks; ++chunk_id) {
    expected_chunks[chunk_id].reserve(chunk_size);
    for (size_t i = 0; i < chunk_size; ++i) {
      // Create somewhat compressible data with patterns unique to each chunk
      expected_chunks[chunk_id].push_back(
        static_cast<uint8_t>((i % 256) + (i / 256) % 128 + chunk_id));
    }

    // Compress this chunk on CPU (host compression is enforced via env var)
    compressed_chunks[chunk_id] =
      cudf::io::detail::compress(cudf::io::compression_type::ZSTD, expected_chunks[chunk_id]);
    ASSERT_GT(compressed_chunks[chunk_id].size(), 0) << "CPU compression failed for chunk "
                                                      << chunk_id;
    ASSERT_LT(compressed_chunks[chunk_id].size(), expected_chunks[chunk_id].size())
      << "Data should be compressed for chunk " << chunk_id;
  }

  // Prepare device buffers for all compressed chunks
  std::vector<rmm::device_uvector<uint8_t>> d_compressed;
  std::vector<rmm::device_uvector<uint8_t>> d_decompressed;
  d_compressed.reserve(num_chunks);
  d_decompressed.reserve(num_chunks);

  for (size_t i = 0; i < num_chunks; ++i) {
    d_compressed.emplace_back(cudf::detail::make_device_uvector_async(compressed_chunks[i], stream, mr));
    d_decompressed.emplace_back(rmm::device_uvector<uint8_t>(chunk_size, stream, mr));
  }

  // Setup input/output spans
  auto hd_srcs = cudf::detail::hostdevice_vector<device_span<uint8_t const>>(num_chunks, stream);
  auto hd_dsts = cudf::detail::hostdevice_vector<device_span<uint8_t>>(num_chunks, stream);
  for (size_t i = 0; i < num_chunks; ++i) {
    hd_srcs[i] = d_compressed[i];
    hd_dsts[i] = d_decompressed[i];
  }
  hd_srcs.host_to_device_async(stream);
  hd_dsts.host_to_device_async(stream);

  auto hd_stats = cudf::detail::hostdevice_vector<codec_exec_result>(num_chunks, stream);
  for (size_t i = 0; i < num_chunks; ++i) {
    hd_stats[i] = codec_exec_result{0, codec_status::FAILURE};
  }
  hd_stats.host_to_device_async(stream);

  // Perform GPU decompression with explicit environment check
  std::cout << "LIBCUDF_HOST_DECOMPRESSION = "
            << (getenv("LIBCUDF_HOST_DECOMPRESSION") ? getenv("LIBCUDF_HOST_DECOMPRESSION")
                                                      : "not set (defaults to OFF)")
            << std::endl;
  std::cout << "Decompressing " << num_chunks << " chunks (" << total_data_size
            << " bytes total) on GPU..." << std::endl;

  cudf::io::detail::decompress(cudf::io::compression_type::ZSTD,
                                hd_srcs,
                                hd_dsts,
                                hd_stats,
                                chunk_size,
                                total_data_size,
                                stream);
  stream.synchronize();  // Ensure kernel completion

  hd_stats.device_to_host(stream);

  // Verify all chunks decompressed successfully
  for (size_t i = 0; i < num_chunks; ++i) {
    ASSERT_EQ(hd_stats[i].status, codec_status::SUCCESS)
      << "GPU decompression failed for chunk " << i;
    ASSERT_EQ(hd_stats[i].bytes_written, chunk_size)
      << "Decompressed size mismatch for chunk " << i << ": expected " << chunk_size << " but got "
      << hd_stats[i].bytes_written;

    // Verify the decompressed data matches the original
    auto const got = cudf::detail::make_std_vector(d_decompressed[i], stream);
    EXPECT_EQ(got, expected_chunks[i]) << "Decompressed data does not match original for chunk "
                                        << i;
  }

  std::cout << "Successfully decompressed all " << num_chunks << " chunks on GPU" << std::endl;

  // Clean up environment variables
  unsetenv("LIBCUDF_HOST_DECOMPRESSION");
  unsetenv("LIBCUDF_NVCOMP_POLICY");
  unsetenv("LIBCUDF_HOST_COMPRESSION");
}

struct NvcompConfigTest : public cudf::test::BaseFixture {};

TEST_F(NvcompConfigTest, Compression)
{
  using nvcomp::compression_type;
  auto const& comp_disabled = nvcomp::is_compression_disabled;

  EXPECT_FALSE(comp_disabled(compression_type::DEFLATE, {2, 5, 0, true, true}));
  // version 2.5 required
  EXPECT_TRUE(comp_disabled(compression_type::DEFLATE, {2, 4, 0, true, true}));
  // all integrations enabled required
  EXPECT_TRUE(comp_disabled(compression_type::DEFLATE, {2, 5, 0, false, true}));

  EXPECT_FALSE(comp_disabled(compression_type::ZSTD, {2, 4, 0, true, true}));
  EXPECT_FALSE(comp_disabled(compression_type::ZSTD, {2, 4, 0, false, true}));
  // 2.4 version required
  EXPECT_TRUE(comp_disabled(compression_type::ZSTD, {2, 3, 1, false, true}));
  // stable integrations enabled required
  EXPECT_TRUE(comp_disabled(compression_type::ZSTD, {2, 4, 0, false, false}));

  EXPECT_FALSE(comp_disabled(compression_type::SNAPPY, {2, 5, 0, true, true}));
  EXPECT_FALSE(comp_disabled(compression_type::SNAPPY, {2, 4, 0, false, true}));
  // stable integrations enabled required
  EXPECT_TRUE(comp_disabled(compression_type::SNAPPY, {2, 3, 0, false, false}));
}

TEST_F(NvcompConfigTest, Decompression)
{
  using nvcomp::compression_type;
  auto const& decomp_disabled = nvcomp::is_decompression_disabled;

  EXPECT_FALSE(decomp_disabled(compression_type::DEFLATE, {2, 5, 0, true, true}));
  // version 2.5 required
  EXPECT_TRUE(decomp_disabled(compression_type::DEFLATE, {2, 4, 0, true, true}));
  // all integrations enabled required
  EXPECT_TRUE(decomp_disabled(compression_type::DEFLATE, {2, 5, 0, false, true}));

  EXPECT_FALSE(decomp_disabled(compression_type::ZSTD, {2, 4, 0, true, true}));
  EXPECT_FALSE(decomp_disabled(compression_type::ZSTD, {2, 3, 2, false, true}));
  EXPECT_FALSE(decomp_disabled(compression_type::ZSTD, {2, 3, 0, true, true}));
#ifdef __HIP_PLATFORM_AMD__
  // NOTE(HIP/AMD): 2.3.1 is stable, stable_integrations=true is enough
  EXPECT_FALSE(decomp_disabled(compression_type::ZSTD, {2, 3, 1, false, true}));
  #else
  // 2.3.1 and earlier requires all integrations to be enabled
  EXPECT_TRUE(decomp_disabled(compression_type::ZSTD, {2, 3, 1, false, true}));
#endif
  // 2.3 version required
  EXPECT_TRUE(decomp_disabled(compression_type::ZSTD, {2, 2, 0, true, true}));
  // stable integrations enabled required
  EXPECT_TRUE(decomp_disabled(compression_type::ZSTD, {2, 4, 0, false, false}));

  EXPECT_FALSE(decomp_disabled(compression_type::SNAPPY, {2, 4, 0, true, true}));
  EXPECT_FALSE(decomp_disabled(compression_type::SNAPPY, {2, 3, 0, false, true}));
  EXPECT_FALSE(decomp_disabled(compression_type::SNAPPY, {2, 2, 0, false, true}));
  // stable integrations enabled required
  EXPECT_TRUE(decomp_disabled(compression_type::SNAPPY, {2, 2, 0, false, false}));
}

void roundtrip_test(cudf::io::compression_type compression)
{
  // TODO(HIP/AMD): Skip GZIP/ZLIB if using hipComp (they use DEFLATE compression)
  if ((compression == cudf::io::compression_type::GZIP ||
       compression == cudf::io::compression_type::ZLIB) &&
      nvcomp::is_compression_disabled(nvcomp::compression_type::DEFLATE)) {
    GTEST_SKIP() << "GZIP/ZLIB compression is not supported with hipComp.";
  }

  auto const stream = cudf::get_default_stream();
  auto const mr     = rmm::mr::get_current_device_resource();
  std::vector<uint8_t> expected;
  expected.reserve(8 * (8 << 20));
  for (size_t size = 1; size < 8 << 20; size *= 2) {
    // Using number strings to generate data that is compressible, but not trivially so
    for (size_t i = size / 2; i < size; ++i) {
      auto const num_string = std::to_string(i);
      // Keep adding to the test data
      expected.insert(expected.end(), num_string.begin(), num_string.end());
    }
    if (cudf::io::detail::compress_max_allowed_chunk_size(compression)
          .value_or(std::numeric_limits<size_t>::max()) < expected.size()) {
      // Skip if the data is too large for the compressor
      return;
    }

    auto d_comp = rmm::device_uvector<uint8_t>(
      cudf::io::detail::max_compressed_size(compression, expected.size()), stream, mr);
    {
      auto const d_orig = cudf::detail::make_device_uvector_async(expected, stream, mr);
      auto hd_srcs      = cudf::detail::hostdevice_vector<device_span<uint8_t const>>(1, stream);
      hd_srcs[0]        = d_orig;
      hd_srcs.host_to_device_async(stream);

      auto hd_dsts = cudf::detail::hostdevice_vector<device_span<uint8_t>>(1, stream);
      hd_dsts[0]   = d_comp;
      hd_dsts.host_to_device_async(stream);

      auto hd_stats = cudf::detail::hostdevice_vector<codec_exec_result>(1, stream);
      hd_stats[0]   = codec_exec_result{0, codec_status::FAILURE};
      hd_stats.host_to_device_async(stream);

      cudf::io::detail::compress(compression, hd_srcs, hd_dsts, hd_stats, stream);
      hd_stats.device_to_host(stream);
      ASSERT_EQ(hd_stats[0].status, codec_status::SUCCESS);
      d_comp.resize(hd_stats[0].bytes_written, stream);
    }

    auto d_got = cudf::detail::hostdevice_vector<uint8_t>(expected.size(), stream);
    {
      auto hd_srcs = cudf::detail::hostdevice_vector<device_span<uint8_t const>>(1, stream);
      hd_srcs[0]   = d_comp;
      hd_srcs.host_to_device_async(stream);

      auto hd_dsts = cudf::detail::hostdevice_vector<device_span<uint8_t>>(1, stream);
      hd_dsts[0]   = d_got;
      hd_dsts.host_to_device_async(stream);

      auto hd_stats = cudf::detail::hostdevice_vector<codec_exec_result>(1, stream);
      hd_stats[0]   = codec_exec_result{0, codec_status::FAILURE};
      hd_stats.host_to_device_async(stream);

      cudf::io::detail::decompress(
        compression, hd_srcs, hd_dsts, hd_stats, expected.size(), expected.size(), stream);
      hd_stats.device_to_host(stream);
      ASSERT_EQ(hd_stats[0].status, codec_status::SUCCESS);
    }

    auto const got = cudf::detail::make_std_vector(d_got, stream);

    EXPECT_EQ(expected, got);
  }
}

TEST_P(HostCompressTest, HostCompression) { roundtrip_test(GetParam()); }

/* TODO(HIP/AMD): We do not support ZSTD currently. Removed ZSTD from test parameters. */
INSTANTIATE_TEST_CASE_P(HostCompression,
                        HostCompressTest,
                        ::testing::Values(cudf::io::compression_type::GZIP,
                                          cudf::io::compression_type::SNAPPY));

TEST_P(HostDecompressTest, HostDecompression) { roundtrip_test(GetParam()); }

/* TODO(HIP/AMD): We do not support ZSTD currently. Removed ZSTD from test parameters. */
INSTANTIATE_TEST_CASE_P(HostDecompression,
                        HostDecompressTest,
                        ::testing::Values(cudf::io::compression_type::GZIP,
                                          cudf::io::compression_type::SNAPPY,
                                          cudf::io::compression_type::ZLIB));

CUDF_TEST_PROGRAM_MAIN()
