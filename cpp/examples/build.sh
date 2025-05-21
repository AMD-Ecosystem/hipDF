#!/bin/bash

# Copyright (c) 2021-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

# libcudf examples build script

set -euo pipefail

# set ROCm-DS GITHUB organization to ROCm-DS if not set in environment
export GITHUB_ROCM_DS_ORG="${GITHUB_ROCM_DS_ORG:-ROCm-DS}"

# set ROCm GITHUB organization to ROCm if not set in environment
export GITHUB_ROCM_ORG="${GITHUB_ROCM_ORG:-ROCm}"

# Parallelism control
PARALLEL_LEVEL=${PARALLEL_LEVEL:-4}
# Installation disabled by default
INSTALL_EXAMPLES=false

# Check for -i or --install flags to enable installation
ARGS=$(getopt -o i --long install -- "$@")
eval set -- "$ARGS"
while [ : ]; do
  case "$1" in
    -i | --install)
        INSTALL_EXAMPLES=true
        shift
        ;;
    --) shift;
        break
        ;;
  esac
done

# Root of examples
EXAMPLES_DIR=$(dirname "$(realpath "$0")")

# Set up default libcudf build directory and install prefix if conda build
if [ "${CONDA_BUILD:-"0"}" == "1" ]; then
  LIB_BUILD_DIR="${LIB_BUILD_DIR:-${SRC_DIR/cpp/build}}"
  INSTALL_PREFIX="${INSTALL_PREFIX:-${PREFIX}}"
fi

# libcudf build directory
LIB_BUILD_DIR=${LIB_BUILD_DIR:-$(readlink -f "${EXAMPLES_DIR}/../build")}

################################################################################
# Add individual libcudf examples build scripts down below

build_example() {
  example_dir=${1}
  example_dir="${EXAMPLES_DIR}/${example_dir}"
  build_dir="${example_dir}/build"
  # TODO(HIP/AMD): adjus this so that this can be set via environment variable.
  # Configure
  cmake -S ${example_dir} -B ${build_dir} -Dcudf_ROOT="${LIB_BUILD_DIR}" -DCMAKE_C_COMPILER=hipcc -DCMAKE_CXX_COMPILER=hipcc
  # Build
  cmake --build ${build_dir} -j${PARALLEL_LEVEL}
  # Install if needed
  if [ "$INSTALL_EXAMPLES" = true ]; then
    cmake --install ${build_dir} --prefix ${INSTALL_PREFIX:-${example_dir}/install}
  fi
}

build_example basic
build_example strings
build_example string_transforms
build_example nested_types
build_example parquet_io
build_example billion_rows
build_example interop
