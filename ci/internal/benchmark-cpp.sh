#!/usr/bin/env bash

# MIT License
#
# Copyright (c) 2024-2026 Advanced Micro Devices, Inc.
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

set -xeu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export SHELLOPTS # NOTE: applies `set -xe` to called bash scripts

export CUDF_BENCH_DETERMINISTIC_CPU=1

printenv

# Set PROJECT_ID explicitly (following test-cpp.sh pattern)
export PROJECT_ID="${PROJECT_ID:-hipdf}"

# Set default ARTIFACTS_DIR if not set
if [ -z "${ARTIFACTS_DIR:-}" ]; then
  ARTIFACTS_DIR="/tmp/${PROJECT_ID}-artifacts"
  echo "ARTIFACTS_DIR not set, using default: ${ARTIFACTS_DIR}"
fi

echo "=== Running C++ Benchmarks ==="

# Setup output directories
CPP_BENCHMARK_LOG="${ARTIFACTS_DIR}/${PROJECT_ID}-cpp-benchmarks.log"
CPP_BENCHMARK_DIR="${ARTIFACTS_DIR}/${PROJECT_ID}-cpp-benchmarks"
mkdir -p "${CPP_BENCHMARK_DIR}"

echo "C++ Benchmark execution started: $(date)" > "${CPP_BENCHMARK_LOG}"
echo "Results directory: ${CPP_BENCHMARK_DIR}" >> "${CPP_BENCHMARK_LOG}"
echo "" >> "${CPP_BENCHMARK_LOG}"

# Find and run all C++ benchmarks
benchmarks=$(find ${BUILD_DIR}/${PROJECT_ID}/cpp/build/benchmarks/ -type f -executable | sort)

set +e # Disable exit on error for benchmark execution
for benchmark in $benchmarks; do
  benchmark_name=$(basename "$benchmark")
  csv_file="${CPP_BENCHMARK_DIR}/${benchmark_name}.csv"

  echo "=== Running: ${benchmark_name} ===" | tee -a "${CPP_BENCHMARK_LOG}"

  # Check benchmark type by name pattern and use appropriate flags
  if [[ "$benchmark_name" == *_NVBENCH ]]; then
    # NVBench: uses --csv flag
    "${benchmark}" --csv "${csv_file}" 2>&1 | tee -a "${CPP_BENCHMARK_LOG}"
  else
    # Google Benchmark: uses --benchmark_out_format and --benchmark_out flags
    "${benchmark}" --benchmark_out_format=csv --benchmark_out="${csv_file}" 2>&1 | tee -a "${CPP_BENCHMARK_LOG}"
  fi

  exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Benchmark failed with exit code: ${exit_code}" | tee -a "${CPP_BENCHMARK_LOG}"
  fi
  echo "" >> "${CPP_BENCHMARK_LOG}"
done
set -e # Re-enable exit on error

echo "C++ Benchmark execution completed: $(date)" >> "${CPP_BENCHMARK_LOG}"
echo "C++ Results saved to:"
echo "  Log: ${CPP_BENCHMARK_LOG}"
echo "  CSV files: ${CPP_BENCHMARK_DIR}/*.csv"
