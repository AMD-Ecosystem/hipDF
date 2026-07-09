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

printenv
set

# Helper function to run Python benchmarks with pytest-benchmark (captures timing data as JSON)
function run_benchmarks() {
    set +e # continue on error
    local benchmark_dir=$1
    local json_output_dir=$2

    find "$benchmark_dir" -name "bench_*.py" \
      -printf "run_benchmarks: found benchmark file: %p\n" \
      -exec bash -c '
        benchmark_file="{}"
        benchmark_name=$(basename "$benchmark_file")
        json_file="$2/${benchmark_name}.json"
        pytest -v "$benchmark_file" \
          --benchmark-only \
          --benchmark-json="$json_file"
        ' _ "$benchmark_dir" "$json_output_dir" \;
    set -e
}

# Helper function to convert benchmark JSON to CSV (extracts timing statistics)
function convert_benchmarks_to_csv() {
    local json_dir=$1
    local output_csv=$2

    # CSV header
    echo "file,benchmark_name,min,max,mean,stddev,median,iqr,ops,rounds,iterations" > "$output_csv"

    # Process each JSON file
    for json_file in $(find "$json_dir" -name "*.json" | sort); do
        if [ -f "$json_file" ]; then
            # Use python to parse JSON and extract benchmark data
            python3 -c "
import json
import sys
import os

try:
    with open('$json_file', 'r') as f:
        data = json.load(f)

    benchmarks = data.get('benchmarks', [])
    for bench in benchmarks:
        stats = bench.get('stats', {})
        name = bench.get('name', 'unknown')
        fullname = bench.get('fullname', name)

        # Extract file name from fullname (format: path/to/file.py::test_name)
        file_part = fullname.split('::')[0] if '::' in fullname else ''
        file_name = os.path.basename(file_part) if file_part else 'unknown'

        # Get timing statistics
        min_time = stats.get('min', 0)
        max_time = stats.get('max', 0)
        mean_time = stats.get('mean', 0)
        stddev = stats.get('stddev', 0)
        median = stats.get('median', 0)
        iqr = stats.get('iqr', 0)
        ops = stats.get('ops', 0)
        rounds = stats.get('rounds', 0)
        iterations = stats.get('iterations', 0)

        print(f'{file_name},{name},{min_time},{max_time},{mean_time},{stddev},{median},{iqr},{ops},{rounds},{iterations}')
except Exception as e:
    print(f'Error processing $json_file: {e}', file=sys.stderr)
" >> "$output_csv" 2>/dev/null || echo "# Error processing $json_file" >> "$output_csv"
        fi
    done
}

# Set PROJECT_ID if not set
export PROJECT_ID="${PROJECT_ID:-hipdf}"

# Set default ARTIFACTS_DIR if not set
if [ -z "${ARTIFACTS_DIR:-}" ]; then
  ARTIFACTS_DIR="/tmp/${PROJECT_ID}-artifacts"
  echo "ARTIFACTS_DIR not set, using default: ${ARTIFACTS_DIR}"
fi

echo "=== Running Python Benchmarks ==="

# Verify pytest is available (assumed by caller who activates conda)
if ! command -v pytest &> /dev/null; then
  echo "ERROR: pytest command not found. This script must be run in a conda environment with pytest-benchmark installed."
  exit 1
fi

# Run Python benchmarks
PY_BENCHMARK_DIR="${BUILD_DIR}/${PROJECT_ID}/python/cudf/benchmarks"
PY_JSON_OUTPUT_DIR=$(mktemp -d)

run_benchmarks "$PY_BENCHMARK_DIR" "$PY_JSON_OUTPUT_DIR"

# Convert JSON results to CSV and save
PY_BENCHMARK_CSV="${ARTIFACTS_DIR}/${PROJECT_ID}-benchmark-results-py.csv"
convert_benchmarks_to_csv "$PY_JSON_OUTPUT_DIR" "$PY_BENCHMARK_CSV"

# Also keep the JSON files for detailed analysis
PY_BENCHMARK_JSON_DIR="${ARTIFACTS_DIR}/${PROJECT_ID}-benchmarks-py"
mkdir -p "$PY_BENCHMARK_JSON_DIR"
cp -r "$PY_JSON_OUTPUT_DIR"/*.json "$PY_BENCHMARK_JSON_DIR/" 2>/dev/null || true

rm -rf "$PY_JSON_OUTPUT_DIR"

echo "Python Results saved to:"
echo "  CSV: ${PY_BENCHMARK_CSV}"
echo "  JSON files: ${PY_BENCHMARK_JSON_DIR}/*.json"
