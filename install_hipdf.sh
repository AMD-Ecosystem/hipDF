#!/usr/bin/env -S bash -i
# MIT License
#
# Copyright (c) 2023-2026 Advanced Micro Devices, Inc.
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

# Requirements: conda, rocthrust-dev, hipcub, hipblas, hipblas-dev, hipfft, hipsparse, hiprand, rocsolver, rocrand-dev

set -e
set -x
set +H # NOTE: Disables '!' style history substitution of 'bash' -i shell.

ROCM_PATH=${ROCM_PATH:-"/opt/rocm"}
AMDGPU_TARGETS=${AMDGPU_TARGETS:-"gfx942"}
BUILD_DIR=${BUILD_DIR:-"/tmp/hipdf"}
PYTHON_VERSION=${PYTHON_VERSION:-"3.12"}

# set the AMD Data Science GitHub organization if not set in the environment
# NOTE: ROCmDS-CMake fetches dependencies from RAPIDS_CMAKE_ROCM_DS_ORG and defaults to the former name of the organization, ROCm-DS.
export RAPIDS_CMAKE_ROCM_DS_ORG="${RAPIDS_CMAKE_ROCM_DS_ORG:-AMD-AIOSS}"
export GITHUB_ROCM_DS_ORG="${RAPIDS_CMAKE_ROCM_DS_ORG}"

# set the GitHub organization for ROCm-derived release repositories
export RAPIDS_CMAKE_ROCM_ORG="${RAPIDS_CMAKE_ROCM_ORG:-AMD-AIOSS}"
export GITHUB_ROCM_ORG="${RAPIDS_CMAKE_ROCM_ORG}"

BUILD_CUPY=${BUILD_CUPY:-"false"}
BUILD_HIPMM=${BUILD_HIPMM:-"false"}

BUILD_CUDF_PYTHON=${BUILD_CUDF_PYTHON:-"true"}
BUILD_DASK_CUDF=${BUILD_DASK_CUDF:-"false"}
BUILD_CUDF_KAFKA=${BUILD_CUDF_KAFKA:-"false"}
CUDF_USE_WARPSIZE_32=${CUDF_USE_WARPSIZE_32:-"false"}
CUDF_DEBUG_BUILD=${CUDF_DEBUG_BUILD:-"false"}
CUDF_USE_PER_THREAD_DEFAULT_STREAM=${CUDF_USE_PER_THREAD_DEFAULT_STREAM:-"false"}

GITHUB_ROCM_DS_BRANCH=${GITHUB_ROCM_DS_BRANCH:-"release/26.10"}

# Numba HIP lives in the 'packages/numba-hip' subdirectory of the HIP Python monorepo.
NUMBA_URL=${NUMBA_URL:-"https://github.com/${GITHUB_ROCM_ORG}/hip-python"}
NUMBA_BRANCH=${NUMBA_BRANCH:-"release/rocm-rel-10.0.0"}
CUPY_URL=${CUPY_URL:-"https://github.com/${GITHUB_ROCM_ORG}/cupy"}
CUPY_BRANCH=${CUPY_BRANCH:-"${GITHUB_ROCM_DS_BRANCH}"}
HIPMM_URL=${HIPMM_URL:-"https://github.com/${GITHUB_ROCM_DS_ORG}/hipMM"}
HIPMM_BRANCH=${HIPMM_BRANCH:-"${GITHUB_ROCM_DS_BRANCH}"}
HIPDF_URL=${HIPDF_URL:-"https://github.com/${GITHUB_ROCM_DS_ORG}/hipDF"}
HIPDF_BRANCH=${HIPDF_BRANCH:-"${GITHUB_ROCM_DS_BRANCH}"}
ROCMDS_CMAKE_URL=${ROCMDS_CMAKE_URL:-"https://github.com/${GITHUB_ROCM_DS_ORG}/ROCmDS-cmake"}
ROCMDS_CMAKE_BRANCH=${ROCMDS_CMAKE_BRANCH:-"${GITHUB_ROCM_DS_BRANCH}"}

AMD_PYPI_URL=${AMD_PYPI_URL:-"https://pypi.amd.com/rocm-10.0.0/simple"}

# We assume that you have already installed ROCm into /opt/rocm

# Helpers
function __get_rocm_version_header() {
  local rocm_version_h
  rocm_version_h=$(find "$(hipconfig --path)" -name "rocm_version.h")
  if [[ -z ${rocm_version_h} ]]; then
    echo "Error: ROCm version could not be identified."
    exit 1
  fi
  printf ${rocm_version_h}
}

function __get_rocm_version_linearized() {
  local major=$1
  local minor=$2
  local patch=$3
  local result
  result=$((major * 10000 + minor * 100 + patch))
  echo "${result}"
}

function get_rocm_version_linearized() {
  local rocm_version_h
  local major
  local minor
  local patch
  rocm_version_h=$(__get_rocm_version_header)
  major=$(grep "ROCM_VERSION_MAJOR\s\+[0-9]\+" ${rocm_version_h} | grep -o "[0-9]\+")
  minor=$(grep "ROCM_VERSION_MINOR\s\+[0-9]\+" ${rocm_version_h} | grep -o "[0-9]\+")
  patch=$(grep "ROCM_VERSION_PATCH\s\+[0-9]\+" ${rocm_version_h} | grep -o "[0-9]\+")
  __get_rocm_version_linearized ${major} ${minor} ${patch}
}

# Prints the ROCm version 'X.Y.Z'
function get_rocm_version() {
  local rocm_version_h
  local major
  local minor
  local patch
  rocm_version_h=$(__get_rocm_version_header)
  major=$(grep "ROCM_VERSION_MAJOR\s\+[0-9]\+" ${rocm_version_h} | grep -o "[0-9]\+")
  minor=$(grep "ROCM_VERSION_MINOR\s\+[0-9]\+" ${rocm_version_h} | grep -o "[0-9]\+")
  patch=$(grep "ROCM_VERSION_PATCH\s\+[0-9]\+" ${rocm_version_h} | grep -o "[0-9]\+")
  printf "${major}.${minor}.${patch}"
}

# Matches empty vars, and vars that contain spaces. Does not match undefined variables.
# Usage: `err_if_blank <VARNAME>`
# NOTE: A variable name must be passed.
function err_if_blank() {
  if [ ! -z "${!1+x}" ] && [ -z "${!1// }" ]; then
    echo "${libutil_error_prefix:-"ERROR"}: Variable '$1' is empty or contains only spaces."
    if [ -z ${WARN_ON_ERROR+x} ]; then
      exit 1
    fi
  fi
}

# Checks if a value equals 'true', '1', 'y', 'yes', or 'on' (case-insensitive), or
# 'false', '0', 'n', 'no', or 'off' (case-insensitive).
# Usage: `err_if_no_boolean $<VALUE>`
# NOTE: A value must be passed.
function err_if_no_boolean() {
  local lowered
  lowered=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  if [[ "${lowered}" == "true" || "${lowered}" == "1" || "${lowered}" == "y"  || "${lowered}" == "yes" || "${lowered}" == "on"  ]]; then
    : # nop
  elif [[ "${lowered}" == "false" || "${lowered}" == "0" || "${lowered}" == "n"  || "${lowered}" == "no" || "${lowered}" == "off"  ]]; then
    : # nop
  else
    echo "${libutil_error_prefix:-"ERROR"}: Argument '$1' is no boolean value; allowed expressions: 'true' / 'false', '1' / '0', 'y' / 'n', 'yes' / 'no', 'on' / 'off' (case-insensitive)."
    if [ -z ${WARN_ON_ERROR+x} ]; then
      exit 1
    fi
  fi
}

# Checks if a value equals 'false', '0', 'n', 'no', or 'off' (case-insensitive).
# Usage: `[ $(is_false $<VALUE>) ]`
# NOTE: A value must be passed.
function is_false() {
  local lowered
  lowered=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  [[ "${lowered}" == "false" || "${lowered}" == "0" || "${lowered}" == "n"  || "${lowered}" == "no" || "${lowered}" == "off"  ]] && printf "1"
}

# Check variables
err_if_no_boolean "${BUILD_CUPY}"
err_if_no_boolean "${BUILD_HIPMM}"

err_if_no_boolean "${BUILD_CUDF_PYTHON}"
err_if_no_boolean "${BUILD_DASK_CUDF}"
err_if_no_boolean "${BUILD_CUDF_KAFKA}"
err_if_no_boolean "${CUDF_USE_WARPSIZE_32}"
err_if_no_boolean "${CUDF_DEBUG_BUILD}"
err_if_no_boolean "${CUDF_USE_PER_THREAD_DEFAULT_STREAM}"

err_if_blank AMDGPU_TARGETS
err_if_blank BUILD_DIR
err_if_blank ROCM_PATH
err_if_blank PYTHON_VERSION

err_if_blank NUMBA_URL
err_if_blank NUMBA_BRANCH
err_if_blank CUPY_URL
err_if_blank CUPY_BRANCH
err_if_blank HIPMM_URL
err_if_blank HIPMM_BRANCH
err_if_blank HIPDF_URL
err_if_blank HIPDF_BRANCH
err_if_blank ROCMDS_CMAKE_URL
err_if_blank ROCMDS_CMAKE_BRANCH

# Allow to find ROCm-related CMake package config files
export CMAKE_PREFIX_PATH="${ROCM_PATH}/lib/cmake"

if ((  $(get_rocm_version_linearized) < 100000 )); then
  echo "Error: The ROCm version you are using is not compatible, please install at least ROCm 10.0.0"
  exit 1
fi

# Step 1: Install Conda
# We assume that you have already installed conda
if [[ -z ${CONDA_EXE} ]]; then
  echo "Error: No conda installation found, please install and activate conda."
  exit 1
fi

# Make sure that conda is initialized correctly.
eval "$(conda shell.bash hook)"

# Step 2: Create build folder
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

if [ ! -d "hipDF" ]; then
git clone ${HIPDF_URL} -b ${HIPDF_BRANCH} hipDF
fi

# NOTE: Without a local ROCmDS-CMake, hipMM and hipDF download the 'RAPIDS.cmake' of an older ROCm-DS release,
#       which pins incompatible dependency versions, e.g. ROCm-DS Logger 1.0.
if [ ! -d "ROCmDS-cmake" ]; then
  git clone ${ROCMDS_CMAKE_URL} -b ${ROCMDS_CMAKE_BRANCH} ROCmDS-cmake
fi
export RAPIDS_CMAKE_MODULE_PATH=${BUILD_DIR}/ROCmDS-cmake/rapids-cmake

# Step 3: Create and activate hipDF Conda environment `hipdf_dev`
cd ${BUILD_DIR}/hipDF
# NOTE: The environment file only requires 'python>=3.11', but the AMD PyPI wheels are not built for every newer Python.
sed "s/^- python>=.*$/- python=${PYTHON_VERSION}/" conda/environments/all_rocm_arch-x86_64.yaml > ${BUILD_DIR}/hipdf_dev.yaml
conda env create --name hipdf_dev --file ${BUILD_DIR}/hipdf_dev.yaml
# NOTE: The ROCm 10 packages do not add '${ROCM_PATH}/lib' to the dynamic linker's search path, but CuPy and hipDF load the ROCm libraries from there.
conda env config vars set --name hipdf_dev LD_LIBRARY_PATH="${ROCM_PATH}/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
conda activate hipdf_dev

# Step 4: Install CuPy into hipdf_dev
if [ "$(is_false "${BUILD_CUPY}")" ]; then
  pip install amd-cupy~=14.1.1 --extra-index-url=${AMD_PYPI_URL}
else
  cd ${BUILD_DIR}

  if [ ! -d "cupy" ]; then
    git clone ${CUPY_URL} -b ${CUPY_BRANCH} cupy
  fi

  # Step 4: Create CuPy wheel
  cd ${BUILD_DIR}/cupy
  git submodule update --init

  pip install --upgrade pip
  python3 -m pip install build scipy
  export CUPY_INSTALL_USE_HIP=1
  export ROCM_HOME=/opt/rocm
  export HCC_AMDGPU_TARGET=${AMDGPU_TARGETS//;/,}
  SETUPTOOLS_BUILD_PARALLEL=${MAX_JOBS:-1} python3 -m build --wheel
  CUPY_WHEEL=$(find ~+ -type f -name "*cupy*.whl")
  pip install ${CUPY_WHEEL}
fi

# Step 5: Install Numba HIP and the HIP Python bindings into `hipdf_dev`
# NOTE: The versions of the binding packages lead with the ROCm version, e.g. 10.0.0.0.1.2.
ROCM_VERSION=$(get_rocm_version)
pip install --extra-index-url=${AMD_PYPI_URL} \
  "numba-hip @ git+${NUMBA_URL}@${NUMBA_BRANCH}#subdirectory=packages/numba-hip" \
  "rocm-bindings-core==${ROCM_VERSION}.*" \
  "rocm-bindings-hip==${ROCM_VERSION}.*" \
  "rocm-bindings-compiler==${ROCM_VERSION}.*" \
  "hip-python-interop==${ROCM_VERSION}.*"

# Step 6: Install hipMM into `hipdf_dev`.
if [ "$(is_false "${BUILD_HIPMM}")" ]; then
  pip install amd-hipmm==5.0.0 --extra-index-url=${AMD_PYPI_URL}
else
  cd ${BUILD_DIR}

  if [ ! -d "hipMM" ]; then
  git clone ${HIPMM_URL} -b ${HIPMM_BRANCH} hipMM
  fi

  cd ${BUILD_DIR}/hipMM
  export CXX=hipcc
  export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake
  export RAPIDS_CMAKE_HIP_ARCHITECTURES="${AMDGPU_TARGETS}"
  bash build.sh librmm rmm
fi

# Step 7: Install hipDF into `hipdf_dev`
cd ${BUILD_DIR}/hipDF
export LDFLAGS="-Wl,-O2 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,--disable-new-dtags -Wl,--gc-sections -Wl,--allow-shlib-undefined -Wl,-rpath,/lib/x86_64-linux-gnu/ -Wl,-rpath,${CONDA_PREFIX}/lib -Wl,-rpath-link,${CONDA_PREFIX}/lib -L${CONDA_PREFIX}/lib"
export PARALLEL_LEVEL=16
export CUDF_CMAKE_HIP_ARCHITECTURES="${AMDGPU_TARGETS}"

# determine installation components
components=" libcudf " # these components are always built, optionally add "tests benchmarks"
if [[ ${BUILD_CUDF_PYTHON} == "true" ]]; then
  components+=" pylibcudf cudf"
fi
if [[ ${BUILD_DASK_CUDF} == "true" ]]; then
  components+=" cudf dask_cudf"
fi
if [[ ${BUILD_CUDF_KAFKA} == "true" ]]; then
  components+=" cudf libcudf_kafka cudf_kafka custreamz"
fi

if [[ ${CUDF_DEBUG_BUILD} == "true" ]]; then
  components+=" -g"
fi

cmake_extra_args=""
if [[ ${FIND_CUDF_CPP} == "false" ]]; then
  cmake_extra_args+=" -DFIND_CUDF_CPP=OFF" # note: ...=ON is the default set by 'build.sh' script
fi

if [[ ${CUDF_USE_WARPSIZE_32} == "true" ]]; then
  cmake_extra_args+=" -DCUDF_USE_WARPSIZE_32=ON"
fi

if [[ ${CUDF_USE_PER_THREAD_DEFAULT_STREAM} == "true" ]]; then
  cmake_extra_args+=" -DCUDF_USE_PER_THREAD_DEFAULT_STREAM=ON"
fi

# NOTE: 'build.sh' only accepts the CMake arguments as a single argument in the form '--cmake-args="<args>"'.
CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake bash build.sh ${components} \
  ${cmake_extra_args:+"--cmake-args=\"${cmake_extra_args# }\""}
