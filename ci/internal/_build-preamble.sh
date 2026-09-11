# shellcheck shell=bash
# MIT License
#
# Copyright (C) 2026 Advanced Micro Devices, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# makes available locally:
#  - cmake_args - extra cmake args for hipDF build
# exports:
#  - PARALLEL_LEVEL
#  - CXX - Sets it to hipcc
#  - CMAKE_PREFIX_PATH - appends ROCM_PATH cmake path

set -euo pipefail

_PREAMBLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_PREAMBLE_DIR}/_activate-env.sh"

if ! activate_hipdf_conda_env; then
    python3 -m venv --clear ${INSTALL_DIR}/venv/hipdf_dev
    . ${INSTALL_DIR}/venv/hipdf_dev/bin/activate
    pip install --upgrade pip
    pip install cmake==${CMAKE_VERSION}
fi

[[ "${HIPDF_USE_VERSIONS_JSON:-false}" == "false" ]] && no_use_versions_json=1
[[ "${HIPDF_FIND_CUDF_CPP:-false}" == "false" ]] && no_find_cudf_cpp=1
[[ "${CMAKE_INSTALL_PREFIX:-}" == "<conda-prefix>" ]] && install_to_conda_prefix="1"
[[ "${SCCACHE_ENABLE:-false}" == "true" ]] && use_sccache=1
[[ "${HIPDF_ENABLE_UDF_JITIFY:-false}" == "true" ]] && enable_udf_jitify=1
[[ "${HIPDF_USE_WARPSIZE_32:-false}" == "true" ]] && use_warpsize_32=1
[[ "${HIPDF_USE_PER_THREAD_DEFAULT_STREAM:-false}" == "true" ]] && use_ptds=1
[[ "${HIPDF_ASAN_BUILD:-false}" == "true" ]] && asan_build=1
# Inverted on purpose: CUDF_ENABLE_FAILING_OPTIMIZATION_WORKAROUNDS defaults to ON in
# cpp/CMakeLists.txt, so only an explicit "false" here may turn the workarounds off.
[[ "${HIPDF_ENABLE_FAILING_OPTIMIZATION_WORKAROUNDS:-true}" == "false" ]] && no_enable_failing_optimization_workarounds=1

# Wheel builds resolve rmm and rapids_logger from ci_packages wheels
# (amd-libhipmm, amd-rocmds-logger), not from /src checkouts.
case "${HIPDF_BUILD_TYPE:-}" in
  wheels|cpp_wheels|install_cpp_wheels) wheel_deps_from_pip=1 ;;
esac

use_local_rmm_logger=
if [ -n "${no_use_versions_json:-}" ] && [ -z "${wheel_deps_from_pip:-}" ]; then
  use_local_rmm_logger=1
fi

cmake_args=(
  "-DCMAKE_VERBOSE_MAKEFILE=ON"
  "-D CPACK_OUTPUT_FILE_PREFIX=${BUILD_ARTIFACTS_DIR}"
  ${install_to_conda_prefix:+"-D CMAKE_INSTALL_PREFIX=${CONDA_PREFIX}"}
  ${install_to_conda_prefix:-${CMAKE_INSTALL_PREFIX:+" -D CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}"}}
  ${AMDGPU_TARGETS:+"-D CMAKE_HIP_ARCHITECTURES='${AMDGPU_TARGETS}'"}
  ${no_find_cudf_cpp:+"-D FIND_CUDF_CPP=OFF"}
  ${enable_udf_jitify:+"-DCUDF_ENABLE_UDF_WITH_JITIFY=ON"}
  ${use_warpsize_32:+"-DCUDF_USE_WARPSIZE_32=ON"}
  ${use_ptds:+"-DCUDF_USE_PER_THREAD_DEFAULT_STREAM=ON"}
  ${asan_build:+"-DBUILD_ASAN=ON"}
  ${no_enable_failing_optimization_workarounds:+"-DCUDF_ENABLE_FAILING_OPTIMIZATION_WORKAROUNDS=OFF"}
  ${no_use_versions_json:+"-D CPM_libhipcxx_SOURCE=${SRC_DIR}/libhipcxx"}
  ${no_use_versions_json:+"-D CPM_hipcomp_SOURCE=${SRC_DIR}/hipcomp_core"}
  ${no_use_versions_json:+"-D CPM_hipbench_SOURCE=${SRC_DIR}/hipbench"}
  ${no_use_versions_json:+"-D CPM_nvbench_SOURCE=${SRC_DIR}/hipbench"}
  ${no_use_versions_json:+"-D CPM_jitify_SOURCE=${SRC_DIR}/jitify"}
  ${no_use_versions_json:+"-D CPM_hipcollections_SOURCE=${SRC_DIR}/hipcollections"}
  ${no_use_versions_json:+"-D CPM_cuco_SOURCE=${SRC_DIR}/hipcollections"}
  ${use_local_rmm_logger:+"-D CPM_rmm_SOURCE=${SRC_DIR}/hipmm"}
  ${no_use_versions_json:+"-D CPM_cudf_SOURCE=${SRC_DIR}/hipdf"}
  ${use_local_rmm_logger:+"-D CPM_rapids_logger_SOURCE=${SRC_DIR}/rocmds_logger"}
  ${use_sccache:+"-D CMAKE_HIP_COMPILER_LAUNCHER=sccache"}
  ${use_sccache:+"-D CMAKE_CXX_COMPILER_LAUNCHER=sccache"}
  ${use_sccache:+"-D CMAKE_C_COMPILER_LAUNCHER=sccache"}
)

if [ -d "/opt/rh/gcc-toolset-$(g++ -dumpversion)" ]; then
  toolchain="/opt/rh/gcc-toolset-$(g++ -dumpversion)/root/usr"
  export CCC_OVERRIDE_OPTIONS="+--gcc-toolchain=${toolchain}"
  export CC=${toolchain}/bin/cc
  export CXX=${toolchain}/bin/c++
fi

export PARALLEL_LEVEL=${MAX_JOBS:-1}
export CXX=hipcc
export CMAKE_PREFIX_PATH+=":${CMAKE_INSTALL_PREFIX:-${INSTALL_DIR}}:${ROCM_PATH}"
export CPM_USE_LOCAL_PACKAGES=OFF
export CPM_DOWNLOAD_ALL=OFF
