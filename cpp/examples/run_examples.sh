#!/bin/bash

# MIT License
#
# Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Run basic example
cd basic/ || exit
./build/basic_example
cd ..
# Run nested_types example
cd nested_types/ || exit
./build/deduplication
cd ..
# Run parquet example
cd parquet_io/ || exit
./build/parquet_io example.parquet
./build/parquet_io_multithreaded example.parquet
cd ..
# Run string_transforms examples
cd string_transforms/ || exit
./build/localize_phone_jit info.csv localize_phone_jit.csv 100000
./build/localize_phone_precompiled info.csv localize_phone_precompiled.csv 100000
./build/compute_checksum_jit info.csv compute_checksum_jit.csv 100000
./build/extract_email_jit info.csv extract_email_jit.csv 100000
./build/extract_email_precompiled info.csv extract_email_precompiled.csv 100000
./build/format_phone_jit info.csv format_phone_jit.csv 100000
./build/format_phone_precompiled info.csv format_phone_precompiled.csv 100000
cd ..
# Run strings example
./strings/build/custom_optimized strings/names.csv
./strings/build/custom_with_malloc strings/names.csv
./strings/build/custom_prealloc strings/names.csv
./strings/build/libcudf_apis strings/names.csv
