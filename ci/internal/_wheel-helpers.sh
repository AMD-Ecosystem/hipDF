# MIT License
#
# Copyright (c) 2026 Advanced Micro Devices, Inc.
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

# RAPIDS wheel build helpers, shared across ROCm-DS projects. Meant to be
# sourced, not executed. Set WHEEL_BUILD_ROOT to a copied checkout, then call
# build_rapids_wheel per python package directory.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR, WHEEL_BUILD_ROOT
#
# Optional environment variables:
#   RAPIDS_PIP_WHEEL_ARGS, AUDITWHEEL_EXCLUDE_ARGS -- defaults below

set -euo pipefail

if ! declare -p RAPIDS_PIP_WHEEL_ARGS &>/dev/null; then
    RAPIDS_PIP_WHEEL_ARGS=(
        -vv
        --no-deps
        --no-build-isolation
        --disable-pip-version-check
        --config-settings=rapidsai.disable-cuda=true
        --config-settings=build.verbose=true
        --config-settings=logging.level=DEBUG
    )
fi

if ! declare -p AUDITWHEEL_EXCLUDE_ARGS &>/dev/null; then
    AUDITWHEEL_EXCLUDE_ARGS=(--exclude "*")
fi

# verify_wheel_absent <wheel-glob> <path-pattern>
#
# Fail if any wheel matching <wheel-glob> under BUILD_ARTIFACTS_DIR lists a
# path matching extended-regex <path-pattern> (grep -E).
verify_wheel_absent() {
    local glob=$1 pattern=$2

    shopt -s nullglob
    local wheels=( "${BUILD_ARTIFACTS_DIR}"/${glob} )
    shopt -u nullglob
    [ ${#wheels[@]} -eq 0 ] && return 0

    local hits
    hits=$(unzip -l "${wheels[@]}" | grep -E "${pattern}" || true)
    if [ -n "${hits}" ]; then
        echo "ERROR: ${glob} must not match /${pattern}/:" >&2
        echo "${hits}" >&2
        exit 1
    fi
}

# dump_rapids_wheel_build_logs <pkg-relpath>
#
# Print CMake and other build logs from a failed scikit-build wheel build.
dump_rapids_wheel_build_logs() {
    local pkg_relpath=$1
    local build_root="${WHEEL_BUILD_ROOT}/${pkg_relpath}/build"

    echo "ERROR: wheel build failed for ${pkg_relpath}" >&2
    if [ -d "${build_root}" ]; then
        echo "==== wheel build tree (${build_root}) ====" >&2
        find "${build_root}" -type f \( -name 'CMake*.log' -o -name '*.log' \) -print >&2
        find "${build_root}" -type f \( -name 'CMake*.log' -o -name '*.log' \) -print0 \
            | xargs -0 -r tail -n 200 >&2 || true
    else
        echo "No build tree at ${build_root}" >&2
    fi
}

# build_rapids_wheel <pkg-relpath> [extra-cmake-args] [extra-pip-args...]
#
# Build one scikit-build wheel under WHEEL_BUILD_ROOT and repair it with
# auditwheel into BUILD_ARTIFACTS_DIR.
build_rapids_wheel() {
    : "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
    : "${WHEEL_BUILD_ROOT:?WHEEL_BUILD_ROOT must be set}"

    local pkg_relpath=$1
    local dist_dir
    dist_dir=$(mktemp -d)
    local log_file="${BUILD_ARTIFACTS_DIR}/$(basename "${pkg_relpath}")-wheel.log"

    cd "${WHEEL_BUILD_ROOT}/${pkg_relpath}"

    if [ -n "${2:-}" ]; then
        local saved_cmake_args="${SKBUILD_CMAKE_ARGS:-}"
        export SKBUILD_CMAKE_ARGS="${SKBUILD_CMAKE_ARGS:+$SKBUILD_CMAKE_ARGS;}${2}"
    fi

    if ! python3 -m pip wheel . -w "${dist_dir}" \
        "${RAPIDS_PIP_WHEEL_ARGS[@]}" "${@:3}" \
        >"${log_file}" 2>&1; then
        echo "==== pip wheel failed for ${pkg_relpath}; log: ${log_file} ====" >&2
        cat "${log_file}" >&2
        dump_rapids_wheel_build_logs "${pkg_relpath}"
        exit 1
    fi

    if [ -n "${2:-}" ]; then
        export SKBUILD_CMAKE_ARGS="${saved_cmake_args}"
    fi

    if grep -E 'CPM: Using local package' -r "${WHEEL_BUILD_ROOT}/${pkg_relpath}/build" -n 2>/dev/null; then
        echo "ERROR: Found 'CPM: Using local package' inside ${pkg_relpath} wheel build logs" >&2
        exit 1
    fi

    python3 -m auditwheel repair \
        "${AUDITWHEEL_EXCLUDE_ARGS[@]}" \
        -w "${BUILD_ARTIFACTS_DIR}" \
        "${dist_dir}"/*

    rm -rf "${dist_dir}"
}
