#!/bin/bash

# Copyright (c) 2019-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
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

# cuDF build script

# This script is used to build the component(s) in this repo from
# source, and can be called with various options to customize the
# build as needed (see the help output for details)
# Abort script on first error
set -e

NUMARGS=$#
ARGS=$*

# NOTE: ensure all dir changes are relative to the location of this
# script, and that this script resides in the repo dir!
REPODIR=$(cd "$(dirname "$0")"; pwd)

VALIDARGS="clean libcudf pylibcudf cudf cudf_polars cudfjar dask_cudf benchmarks tests libcudf_kafka cudf_kafka custreamz -v -g -n --pydevelop -l --allgpuarch --disable_nvtx --opensource_nvcomp  --show_depr_warn --ptds -h --build_metrics --incl_cache_stats --disable_large_strings"
HELP="$0 [clean] [libcudf] [pylibcudf] [cudf] [cudf_polars] [cudfjar] [dask_cudf] [benchmarks] [tests] [libcudf_kafka] [cudf_kafka] [custreamz] [-v] [-g] [-n] [-h] [--cmake-args=\\\"<args>\\\"]
   clean                         - remove all existing build artifacts and configuration (start
                                   over)
   libcudf                       - build the cudf C++ code only
   pylibcudf                     - build the pylibcudf Python package
   cudf                          - build the cudf Python package
   cudf_polars                   - build the cudf_polars Python package
   cudfjar                       - build cudf JAR with static libcudf using devtoolset toolchain
   dask_cudf                     - build the dask_cudf Python package
   benchmarks                    - build benchmarks
   tests                         - build tests
   libcudf_kafka                 - build the libcudf_kafka C++ code only
   cudf_kafka                    - build the cudf_kafka Python package
   custreamz                     - build the custreamz Python package
   -v                            - verbose build mode
   -g                            - build for debug
   -n                            - no install step (does not affect Python)
   --pydevelop                   - Install Python packages in editable mode
   --allgpuarch                  - build for all supported GPU architectures
   --disable_nvtx                - disable inserting NVTX profiling ranges
   --opensource_nvcomp           - disable use of proprietary nvcomp extensions
   --show_depr_warn              - show cmake deprecation warnings
   --ptds                        - enable per-thread default stream
   --disable_large_strings       - disable large strings support
   --warpsize32                  - enable build for warpsize 32 (e.g. on gfx1100)
   --build_metrics               - generate build metrics report for libcudf
   --incl_cache_stats            - include cache statistics in build metrics report
   --cmake-args=\\\"<args>\\\"   - pass arbitrary list of CMake configuration options (escape all quotes in argument)
   -h | --h[elp]                 - print this text

   default action (no args) is to build and install 'libcudf', 'pylibcudf', 'cudf', 'cudf_polars', and 'dask_cudf' targets
"

# set ROCm-DS GITHUB organization to ROCm-DS if not set in environment
export GITHUB_ROCM_DS_ORG="${GITHUB_ROCM_DS_ORG:-ROCm-DS}"

# set ROCm GITHUB organization to ROCm if not set in environment
export GITHUB_ROCM_ORG="${GITHUB_ROCM_ORG:-ROCm}"

LIB_BUILD_DIR=${LIB_BUILD_DIR:=${REPODIR}/cpp/build}
KAFKA_LIB_BUILD_DIR=${KAFKA_LIB_BUILD_DIR:=${REPODIR}/cpp/libcudf_kafka/build}
CUDF_KAFKA_BUILD_DIR=${REPODIR}/python/cudf_kafka/build
CUDF_BUILD_DIR=${REPODIR}/python/cudf/build
DASK_CUDF_BUILD_DIR=${REPODIR}/python/dask_cudf/build
PYLIBCUDF_BUILD_DIR=${REPODIR}/python/pylibcudf/build
CUSTREAMZ_BUILD_DIR=${REPODIR}/python/custreamz/build
CUDF_JAR_JAVA_BUILD_DIR="$REPODIR/java/target"
#: NOTE(HIP/AMD): We need to use hipcc as CXX and C compiler because of CMake target rocThrust->...->hip::device, which
#:                leads to the addition of flags such as `-x hip`; hipcc can compile host and HIP device code.
#: NOTE(HIP/AMD): We need to use declare -x (or export() to forward the variables to subprocesses such as those related to scikit-build.
#:                scikit-build checks CXX + CC on Linux, it is used to compile Cython files.
#: NOTE(HIP/AMD): CUDF_HIPCC allows to point to specific 'hipcc' implementations that are not part of the $PATH.
#: NOTE(HIP/AMD): ROCM_PATH must be set for compiling cudf_kafka in order to specify include folders for the Cython build.
declare -x CXX=${CUDF_HIPCC:-hipcc}
declare -x CC=${CUDF_HIPCC:-hipcc}
declare -x CFLAGS="${CFLAGS} -D__HIP_PLATFORM_AMD__"
declare -x CXXFLAGS="${CXXFLAGS} -D__HIP_PLATFORM_AMD__"
declare -x ROCM_PATH=${ROCM_PATH:-"/opt/rocm"}
declare -x CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-"/opt/rocm/lib/cmake"}

BUILD_DIRS="${LIB_BUILD_DIR} ${CUDF_BUILD_DIR} ${DASK_CUDF_BUILD_DIR} ${KAFKA_LIB_BUILD_DIR} ${CUDF_KAFKA_BUILD_DIR} ${CUSTREAMZ_BUILD_DIR} ${CUDF_JAR_JAVA_BUILD_DIR} ${PYLIBCUDF_BUILD_DIR}"

# Set defaults for vars modified by flags to this script
VERBOSE_FLAG=""
BUILD_TYPE=Release
#BUILD_TYPE=Debug
INSTALL_TARGET=install
BUILD_BENCHMARKS=OFF
BUILD_ALL_GPU_ARCH=0
BUILD_NVTX=OFF
BUILD_TESTS=OFF
BUILD_DISABLE_DEPRECATION_WARNINGS=ON
BUILD_PER_THREAD_DEFAULT_STREAM=OFF
BUILD_REPORT_METRICS=OFF
BUILD_REPORT_INCL_CACHE_STATS=OFF
BUILD_DISABLE_LARGE_STRINGS=OFF
USE_PROPRIETARY_NVCOMP=OFF
PYTHON_ARGS_FOR_INSTALL=("-m" "pip" "install" "--no-build-isolation" "--no-deps" "--config-settings" "rapidsai.disable-cuda=true")
USE_WARPSIZE_32=OFF

# Set defaults for vars that may not have been defined externally
#  FIXME: if INSTALL_PREFIX is not set, check PREFIX, then check
#         CONDA_PREFIX, but there is no fallback from there!
INSTALL_PREFIX=${INSTALL_PREFIX:=${PREFIX:=${CONDA_PREFIX}}}
PARALLEL_LEVEL=${PARALLEL_LEVEL:=$(nproc)}

function hasArg {
    (( NUMARGS != 0 )) && (echo " ${ARGS} " | grep -q " $1 ")
}

function cmakeArgs {
    # Check for multiple cmake args options
    if [[ $(echo "$ARGS" | { grep -Eo "\-\-cmake\-args" || true; } | wc -l ) -gt 1 ]]; then
        echo "Multiple --cmake-args options were provided, please provide only one: ${ARGS}"
        exit 1
    fi

    # Check for cmake args option
    if [[ -n $(echo "$ARGS" | { grep -E "\-\-cmake\-args" || true; } ) ]]; then
        # There are possible weird edge cases that may cause this regex filter to output nothing and fail silently
        # the true pipe will catch any weird edge cases that may happen and will cause the program to fall back
        # on the invalid option error
        EXTRA_CMAKE_ARGS=$(echo "$ARGS" | { grep -Eo "\-\-cmake\-args=\".+\"" || true; })
        if [[ -n ${EXTRA_CMAKE_ARGS} ]]; then
            # Remove the full  EXTRA_CMAKE_ARGS argument from list of args so that it passes validArgs function
            ARGS=${ARGS//$EXTRA_CMAKE_ARGS/}
            # Filter the full argument down to just the extra string that will be added to cmake call
            EXTRA_CMAKE_ARGS=$(echo "$EXTRA_CMAKE_ARGS" | grep -Eo "\".+\"" | sed -e 's/^"//' -e 's/"$//')
        fi
    fi
    read -ra EXTRA_CMAKE_ARGS <<< "$EXTRA_CMAKE_ARGS"
}

function buildAll {
    (( NUMARGS == 0 )) || ! (echo " ${ARGS} " | grep -q " [^-]\+ ")
}

# Usage: ROCM_VERSION=$(get_rocm_version_short)
function get_rocm_version_short() {
    local rocm_version_h
    rocm_version_h=$(find "$(hipconfig --path)" -name "rocm_version.h")
    local major
    major=$(grep "ROCM_VERSION_MAJOR\s\+[0-9]\+" "${rocm_version_h}" | grep -o "[0-9]\+")
    local minor
    minor=$(grep "ROCM_VERSION_MINOR\s\+[0-9]\+" "${rocm_version_h}" | grep -o "[0-9]\+")
    local patch
    patch=$(grep "ROCM_VERSION_PATCH\s\+[0-9]\+" "${rocm_version_h}" | grep -o "[0-9]\+")

    if [[ "${patch}" == "0" ]];
    then
        printf "${major}.${minor}"
    else
    printf "${major}.${minor}.${patch}"
    fi
}

# NOTE(HIP/AMD): We need to set DCUDF_JNI_ENABLE_PROFILING=NO because of NVTX missing.
# TODO(HIP/AMD): We need to set USE_GDS to OFF because we do not support GPU Direct Storage currently.
# TODO(HIP/AMD): Unlike CUDA, we need to set LD_LIBRARY_PATH explicitly otherwise we run into "NoClassDefFound" error for java tests. Internal issue #177.
function buildLibCudfJniInDocker {
    local LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-"$CUDF_JAR_JAVA_BUILD_DIR/cmake-build:$CUDF_JAR_JAVA_BUILD_DIR/cmake-build/lib:$CUDF_JAR_JAVA_BUILD_DIR/libcudf-install/lib"}
    local DOCKER_GPU_OPTS=${DOCKER_GPU_OPTS:-"--device=/dev/kfd --device=/dev/dri  --group-add=render --ipc=host --cap-add=SYS_PTRACE --security-opt seccomp=unconfined"}
    local ROCM_VERSION=${ROCM_VERSION:-"6.2"}
    local imageName="cudf-build:${ROCM_VERSION}-devel-ubuntu"
    local CMAKE_GENERATOR="${CMAKE_GENERATOR:-Ninja}"
    local workspaceDir="/rapids"
    local localMavenRepo=${LOCAL_MAVEN_REPO:-"$HOME/.m2/repository"}
    local workspaceRepoDir="$workspaceDir/cudf"
    local workspaceMavenRepoDir="$workspaceDir/.m2/repository"
    local workspaceCcacheDir="$workspaceDir/.ccache"
    mkdir -p "$CUDF_JAR_JAVA_BUILD_DIR/libcudf-cmake-build"
    mkdir -p "$HOME/.ccache" "$HOME/.m2"
    docker build \
        -f java/ci/Dockerfile.ubuntu \
        --build-arg ROCM_VERSION=${ROCM_VERSION} \
        -t $imageName .
    docker run $DOCKER_GPU_OPTS -it -u "$(id -u):$(id -g)" --rm \
        -e PARALLEL_LEVEL \
        -e CCACHE_DISABLE \
        -e CCACHE_DIR="$workspaceCcacheDir" \
        -e CMAKE_PREFIX_PATH="/opt/rocm/lib/cmake" \
        -e LD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
        -v "/etc/group:/etc/group:ro" \
        -v "/etc/passwd:/etc/passwd:ro" \
        -v "/etc/shadow:/etc/shadow:ro" \
        -v "/etc/sudoers.d:/etc/sudoers.d:ro" \
        -v "$HOME/.ccache:$workspaceCcacheDir:rw" \
        -v "$REPODIR:$workspaceRepoDir:rw" \
        -v "$localMavenRepo:$workspaceMavenRepoDir:rw" \
        -v "$HOME:$HOME" \
        --workdir "$workspaceRepoDir/java/target/libcudf-cmake-build" \
        ${imageName} \
        /bin/bash -c \
            "cmake $workspaceRepoDir/cpp \
                -G${CMAKE_GENERATOR} \
                -DCMAKE_C_COMPILER_LAUNCHER=ccache \
                -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
                -DCMAKE_CUDA_COMPILER_LAUNCHER=ccache \
                -DCMAKE_CXX_LINKER_LAUNCHER=ccache \
                -DCMAKE_C_COMPILER=hipcc \
                -DCMAKE_CXX_COMPILER=hipcc \
                -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
                -DCUDA_STATIC_RUNTIME=ON \
                -DCMAKE_HIP_ARCHITECTURES=${CUDF_CMAKE_HIP_ARCHITECTURES} \
                -DCMAKE_INSTALL_PREFIX=/usr/local/rapids \
                -DUSE_NVTX=OFF \
                -DCUDF_USE_PROPRIETARY_NVCOMP=OFF \
                -DCUDF_USE_ARROW_STATIC=ON \
                -DCUDF_ENABLE_ARROW_S3=OFF \
                -DBUILD_TESTS=OFF \
                -DCUDF_USE_PER_THREAD_DEFAULT_STREAM=ON \
                -DCUDF_LARGE_STRINGS_DISABLED=ON \
                -DRMM_LOGGING_LEVEL=OFF \
                -DBUILD_SHARED_LIBS=OFF \
                -DCUDF_EXPORT_NVCOMP=ON && \
             cmake --build . --parallel ${PARALLEL_LEVEL} && \
             cd $workspaceRepoDir/java && \
             CUDF_CPP_BUILD_DIR=$workspaceRepoDir/java/target/libcudf-cmake-build \
             mvn ${MVN_PHASES:-"package"} \
                -DLD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
                -Dmaven.repo.local=$workspaceMavenRepoDir \
                -DskipTests=${SKIP_TESTS:-false} \
                -Dparallel.level=${PARALLEL_LEVEL} \
                -Dcmake.ccache.opts='-DCMAKE_C_COMPILER_LAUNCHER=ccache \
                                     -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
                                     -DCMAKE_CUDA_COMPILER_LAUNCHER=ccache \
                                     -DCMAKE_CXX_LINKER_LAUNCHER=ccache' \
                                     -DCMAKE_C_COMPILER=hipcc \
                                     -DCMAKE_CXX_COMPILER=hipcc' \
                -DCUDF_CPP_BUILD_DIR=$workspaceRepoDir/java/target/libcudf-cmake-build \
                -DCUDF_JNI_ENABLE_PROFILING=NO \
                -Dio.netty.tryReflectionSetAccessible=true \
                -DCUDA_STATIC_RUNTIME=ON \
                -DCUDF_USE_PER_THREAD_DEFAULT_STREAM=ON \
                -DUSE_GDS=OFF \
                -DCMAKE_CUDA_ARCHITECTURES=${CUDF_CMAKE_CUDA_ARCHITECTURES} \
                -DCMAKE_HIP_ARCHITECTURES=${CUDF_CMAKE_HIP_ARCHITECTURES} \
                -DCUDF_JNI_LIBCUDF_STATIC=ON \
                -Dtest=*,!CuFileTest,!CudaFatalTest,!ColumnViewNonEmptyNullsTest"
}

if hasArg -h || hasArg --h || hasArg --help; then
    echo "${HELP}"
    exit 0
fi

# Check for valid usage
if (( NUMARGS != 0 )); then
    # Check for cmake args
    cmakeArgs
    for a in ${ARGS}; do
    if ! (echo " ${VALIDARGS} " | grep -q " ${a} "); then
        echo "Invalid option or formatting, check --help: ${a}"
        exit 1
    fi
    done
fi

# Process flags
if hasArg -v; then
    VERBOSE_FLAG="-v"
fi
if hasArg -g; then
    BUILD_TYPE=Debug
fi
if hasArg -n; then
    INSTALL_TARGET=""
    LIBCUDF_BUILD_DIR=${LIB_BUILD_DIR}
fi
if hasArg --allgpuarch; then
    BUILD_ALL_GPU_ARCH=1
fi
if hasArg benchmarks; then
    BUILD_BENCHMARKS=ON
fi
if hasArg tests; then
    BUILD_TESTS=ON
fi
if hasArg --disable_nvtx; then
    BUILD_NVTX="OFF"
fi
if hasArg --show_depr_warn; then
    BUILD_DISABLE_DEPRECATION_WARNINGS=OFF
fi
if hasArg --ptds; then
    BUILD_PER_THREAD_DEFAULT_STREAM=ON
fi
if hasArg --warpsize32; then
    USE_WARPSIZE_32=ON
fi
if hasArg --build_metrics; then
    BUILD_REPORT_METRICS=ON
fi

if hasArg --incl_cache_stats; then
    BUILD_REPORT_INCL_CACHE_STATS=ON
fi
if hasArg --pydevelop; then
    PYTHON_ARGS_FOR_INSTALL+=("-e")
fi

if hasArg --disable_large_strings; then
    BUILD_DISABLE_LARGE_STRINGS="ON"
fi

# If clean given, run it prior to any other steps
if hasArg clean; then
    # If the dirs to clean are mounted dirs in a container, the
    # contents should be removed but the mounted dirs will remain.
    # The find removes all contents but leaves the dirs, the rmdir
    # attempts to remove the dirs but can fail safely.
    for bd in ${BUILD_DIRS}; do
    if [ -d "${bd}" ]; then
        find "${bd}" -mindepth 1 -delete
        rmdir "${bd}" || true
    fi
    done

    # Cleaning up python artifacts
    find "${REPODIR}"/python/ | grep -E "(__pycache__|\.pyc|\.pyo|\.so|\_skbuild$)"  | xargs rm -rf

fi


################################################################################
# Configure, build, and install libcudf

if buildAll || hasArg libcudf || hasArg pylibcudf || hasArg cudf || hasArg cudfjar; then
    if (( ${BUILD_ALL_GPU_ARCH} == 0 )); then
        CUDF_CMAKE_HIP_ARCHITECTURES="${CUDF_CMAKE_HIP_ARCHITECTURES:-NATIVE}"
        if [[ "$CUDF_CMAKE_HIP_ARCHITECTURES" == "NATIVE" ]]; then
            echo "Building for the architecture of the GPU in the system..."
        else
            echo "Building for the GPU architecture(s) $CUDF_CMAKE_HIP_ARCHITECTURES ..."
        fi
    else
        CUDF_CMAKE_HIP_ARCHITECTURES="RAPIDS"
        echo "Building for *ALL* supported GPU architectures..."
    fi
fi

if buildAll || hasArg libcudf; then
    # get the current count before the compile starts
    if [[ "$BUILD_REPORT_INCL_CACHE_STATS" == "ON" && -x "$(command -v sccache)" ]]; then
        # zero the sccache statistics
        sccache --zero-stats
    fi

    #TODO(HIP/AMD): CXX/CC compiler needs to presently be hardcoded to hipcc for rmm
    cmake -S "$REPODIR/cpp" -B "${LIB_BUILD_DIR}" \
          -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
          -DCMAKE_CXX_COMPILER="${CXX}" \
          -DCMAKE_C_COMPILER="${CC}" \
          -DCMAKE_HIP_ARCHITECTURES="${CUDF_CMAKE_HIP_ARCHITECTURES}" \
          -DUSE_NVTX=${BUILD_NVTX} \
          -DBUILD_TESTS=${BUILD_TESTS} \
          -DBUILD_BENCHMARKS=${BUILD_BENCHMARKS} \
          -DDISABLE_DEPRECATION_WARNINGS=${BUILD_DISABLE_DEPRECATION_WARNINGS} \
          -DCUDF_USE_PER_THREAD_DEFAULT_STREAM=${BUILD_PER_THREAD_DEFAULT_STREAM} \
          -DCUDF_LARGE_STRINGS_DISABLED=${BUILD_DISABLE_LARGE_STRINGS} \
	      -DCUDF_USE_WARPSIZE_32=${USE_WARPSIZE_32} \
          -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
          "${EXTRA_CMAKE_ARGS[@]}"

    cd "${LIB_BUILD_DIR}"

    compile_start=$(date +%s)
    cmake --build . -j"${PARALLEL_LEVEL}" ${VERBOSE_FLAG}
    compile_end=$(date +%s)
    compile_total=$(( compile_end - compile_start ))

    # Record build times
    if [[ "$BUILD_REPORT_METRICS" == "ON" && -f "${LIB_BUILD_DIR}/.ninja_log" ]]; then
        echo "Formatting build metrics"
        MSG=""
        # get some sccache stats after the compile
        if [[ "$BUILD_REPORT_INCL_CACHE_STATS" == "ON" && -x "$(command -v sccache)" ]]; then
           COMPILE_REQUESTS=$(sccache -s | grep "Compile requests \+ [0-9]\+$" | awk '{ print $NF }')
           CACHE_HITS=$(sccache -s | grep "Cache hits \+ [0-9]\+$" | awk '{ print $NF }')
           HIT_RATE=$(echo - | awk "{printf \"%.2f\n\", $CACHE_HITS / $COMPILE_REQUESTS * 100}")
           MSG="${MSG}<br/>cache hit rate ${HIT_RATE} %"
        fi
        MSG="${MSG}<br/>parallel setting: $PARALLEL_LEVEL"
        MSG="${MSG}<br/>parallel build time: $compile_total seconds"
        if [[ -f "${LIB_BUILD_DIR}/libcudf.so" ]]; then
           LIBCUDF_FS=$(find "${LIB_BUILD_DIR}" -name libcudf.so -printf '%s')
           MSG="${MSG}<br/>libcudf.so size: $LIBCUDF_FS"
        fi
        BMR_DIR=${RAPIDS_ARTIFACTS_DIR:-"${LIB_BUILD_DIR}"}
        echo "Metrics output dir: [$BMR_DIR]"
        mkdir -p "${BMR_DIR}"
        MSG_OUTFILE="$(mktemp)"
        echo "$MSG" > "${MSG_OUTFILE}"
        python "${REPODIR}/cpp/scripts/sort_ninja_log.py" "${LIB_BUILD_DIR}/.ninja_log" --fmt html --msg "${MSG_OUTFILE}" > "${BMR_DIR}/ninja_log.html"
        cp "${LIB_BUILD_DIR}/.ninja_log" "${BMR_DIR}/ninja.log"
    fi

    if [[ ${INSTALL_TARGET} != "" ]]; then
        cmake --build . -j"${PARALLEL_LEVEL}" --target install ${VERBOSE_FLAG}
    fi
fi

export RAPIDS_CMAKE_HIP_ARCHITECTURES=${CUDF_CMAKE_HIP_ARCHITECTURES}

# Build and install the pylibcudf Python package
if buildAll || hasArg pylibcudf; then

    cd "${REPODIR}/python/pylibcudf"
    SKBUILD_CMAKE_ARGS="-DCMAKE_PREFIX_PATH=${INSTALL_PREFIX};-DCMAKE_LIBRARY_PATH=${LIBCUDF_BUILD_DIR};${EXTRA_CMAKE_ARGS[*]}" \
        python "${PYTHON_ARGS_FOR_INSTALL[@]}" .
fi

# Build and install the cudf Python package
if buildAll || hasArg cudf; then

    cd "${REPODIR}/python/cudf"
    SKBUILD_CMAKE_ARGS="-DCMAKE_PREFIX_PATH=${INSTALL_PREFIX};-DCMAKE_LIBRARY_PATH=${LIBCUDF_BUILD_DIR};${EXTRA_CMAKE_ARGS[*]}" \
        python "${PYTHON_ARGS_FOR_INSTALL[@]}" .
fi

# Build and install the cudf_polars Python package
if buildAll || hasArg cudf_polars; then

    cd "${REPODIR}/python/cudf_polars"
    python "${PYTHON_ARGS_FOR_INSTALL[@]}" .
fi

# Build and install the dask_cudf Python package
if buildAll || hasArg dask_cudf; then

    cd "${REPODIR}/python/dask_cudf"
    python "${PYTHON_ARGS_FOR_INSTALL[@]}" .
fi

if hasArg cudfjar; then
    buildLibCudfJniInDocker
fi

# Build libcudf_kafka library
if hasArg libcudf_kafka; then
    #: NOTE(HIP/AMD) We need to use hipcc as CXX compiler because of CMake target rocthrust->...->hip::device
    cmake -S "$REPODIR/cpp/libcudf_kafka" -B "${KAFKA_LIB_BUILD_DIR}" \
          -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
          -DCMAKE_CXX_COMPILER="${CXX}" \
          -DCMAKE_C_COMPILER="${CC}" \
          -DCMAKE_HIP_ARCHITECTURES="${CUDF_CMAKE_HIP_ARCHITECTURES}" \
          -DUSE_NVTX="${BUILD_NVTX}" \
          -DCUDF_USE_PROPRIETARY_NVCOMP="${USE_PROPRIETARY_NVCOMP}" \
          -DBUILD_TESTS="${BUILD_TESTS}" \
          -DDISABLE_DEPRECATION_WARNINGS="${BUILD_DISABLE_DEPRECATION_WARNINGS}" \
          -DCUDF_USE_PER_THREAD_DEFAULT_STREAM="${BUILD_PER_THREAD_DEFAULT_STREAM}" \
	      -DCUDF_USE_WARPSIZE_32="${USE_WARPSIZE_32}" \
          -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
          "${EXTRA_CMAKE_ARGS[@]}"


    cd "${KAFKA_LIB_BUILD_DIR}"
    cmake --build . -j"${PARALLEL_LEVEL}" ${VERBOSE_FLAG}

    if [[ ${INSTALL_TARGET} != "" ]]; then
        cmake --build . -j"${PARALLEL_LEVEL}" --target install ${VERBOSE_FLAG}
    fi
fi

# build cudf_kafka Python package
if hasArg cudf_kafka; then
    cd "${REPODIR}/python/cudf_kafka"
    # shellcheck disable=2034
    SKBUILD_CMAKE_ARGS="-DCMAKE_PREFIX_PATH=${INSTALL_PREFIX};-DCMAKE_LIBRARY_PATH=${LIBCUDF_BUILD_DIR};${EXTRA_CMAKE_ARGS[*]}"
        python "${PYTHON_ARGS_FOR_INSTALL[@]}" .
fi

# build custreamz Python package
if hasArg custreamz; then
    cd "${REPODIR}/python/custreamz"
    python "${PYTHON_ARGS_FOR_INSTALL[@]}" .
fi
