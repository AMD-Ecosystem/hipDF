# shellcheck shell=bash
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

# RAPIDS wheel helpers. Meant to be sourced, not executed directly.
#
# Drop-in for ROCm-DS projects (hipdf, hipmm, hipucxx). Project scripts set
# WHEEL_BUILD_ROOT to a copied checkout, then call build_rapids_wheel for each
# python package directory. install_built_wheel is sourced by the test scripts
# too, which build nothing.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- wheel output, pip logs, auditwheel destination
#   WHEEL_BUILD_ROOT    -- tree root containing package dirs (e.g. copied
#                          checkout); needed by the build functions only
#
# Optional environment variables:
#   RAPIDS_PIP_WHEEL_ARGS           -- pip wheel flags (defaults below)
#   RAPIDS_BUILD_BACKEND_WHEEL_ARGS -- pip wheel flags added for the packages
#                                      built through rapids-build-backend
#                                      (defaults below)
#   AUDITWHEEL_EXCLUDE_ARGS         -- auditwheel --exclude flags
#                                      (default: --exclude "*")

set -euo pipefail

if ! declare -p RAPIDS_PIP_WHEEL_ARGS &>/dev/null; then
    RAPIDS_PIP_WHEEL_ARGS=(
        -vv
        --no-deps
        --no-build-isolation
        --disable-pip-version-check
        --config-settings=build.verbose=true
        --config-settings=logging.level=DEBUG
    )
fi

if ! declare -p RAPIDS_BUILD_BACKEND_WHEEL_ARGS &>/dev/null; then
    # Only rapids-build-backend consumes rapidsai.* config settings. A package
    # naming scikit-build-core directly rejects the unknown rapidsai key,
    # because scikit-build-core's strict-config defaults to true.
    RAPIDS_BUILD_BACKEND_WHEEL_ARGS=(
        --config-settings=rapidsai.disable-cuda=true
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
    # ${glob} is unquoted on purpose: it is a wheel-name pattern to expand.
    # shellcheck disable=SC2206
    local wheels=( "${BUILD_ARTIFACTS_DIR}"/${glob} )
    shopt -u nullglob
    [ ${#wheels[@]} -eq 0 ] && return 0

    # One archive per unzip call: a second path argument is read as a member
    # filter, not as another archive, which would pass every wheel but the first.
    local wheel hits
    for wheel in "${wheels[@]}"; do
        hits=$(unzip -l "${wheel}" | grep -E "${pattern}" || true)
        if [ -n "${hits}" ]; then
            echo "ERROR: $(basename "${wheel}") must not match /${pattern}/:" >&2
            echo "${hits}" >&2
            exit 1
        fi
    done
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
        # CMake >= 3.26 records its configure-time checks in CMakeConfigureLog.yaml
        # instead of the CMakeError.log/CMakeOutput.log pair a *.log glob catches.
        find "${build_root}" -type f \
            \( -name '*.log' -o -name 'CMakeConfigureLog.yaml' \) -print >&2
        find "${build_root}" -type f \
            \( -name '*.log' -o -name 'CMakeConfigureLog.yaml' \) -print0 \
            | xargs -0 -r tail -n 200 >&2 || true
    else
        echo "No build tree at ${build_root}" >&2
    fi
}

# verify_build_requires <pkg-relpath>
#
# Fail if any requirement the package in the current directory declares is
# unsatisfied in the venv. --no-build-isolation means pip installs nothing from
# either requires table, so an unsatisfied entry is a gap in
# _install-build-deps.sh rather than something pip fixes.
verify_build_requires() {
    python3 - "$1" <<'PY' || exit 1
import sys, tomllib
from importlib.metadata import distributions
from packaging.requirements import Requirement
from packaging.utils import canonicalize_name

pkg = sys.argv[1]
with open("pyproject.toml", "rb") as fh:
    data = tomllib.load(fh)

# Both tables are build requirements: pip reads [build-system] requires, and
# rapids-build-backend adds its own on top via get_requires_for_build_wheel.
declared = data.get("build-system", {}).get("requires", []) + \
    data.get("tool", {}).get("rapids-build-backend", {}).get("requires", [])

# Canonicalized, because the tables say cython where the venv has Cython.
have = {canonicalize_name(d.metadata["Name"]): d.version for d in distributions()}

# Extras are not checked: scikit-build-core[pyproject] names an extra that
# scikit-build-core no longer provides, so requiring it would be a false alarm.
missing = []
for spec in declared:
    req = Requirement(spec)
    if req.marker and not req.marker.evaluate():
        continue
    version = have.get(canonicalize_name(req.name))
    if version is None:
        missing.append(f"  {spec} -- not installed")
    elif not req.specifier.contains(version, prereleases=True):
        missing.append(f"  {spec} -- installed {version}")

if missing:
    print(f"ERROR: {pkg} declares build requirements the venv does not satisfy:",
          file=sys.stderr)
    print("\n".join(missing), file=sys.stderr)
    print("Provision them in ci/internal/_install-build-deps.sh, which resolves "
          "against the wheel links page via --find-links.", file=sys.stderr)
    sys.exit(1)

print(f"{pkg}: {len(declared)} declared build requirements satisfied")
PY
}

# uses_rapids_build_backend
#
# True if the package in the current directory builds through
# rapids-build-backend, which is what makes RAPIDS_BUILD_BACKEND_WHEEL_ARGS
# legal to pass. The backend that compiles is the one named in
# [tool.rapids-build-backend], so [build-system] is what names the wrapper.
uses_rapids_build_backend() {
    python3 - <<'PY'
import sys, tomllib

with open("pyproject.toml", "rb") as fh:
    data = tomllib.load(fh)

backend = data.get("build-system", {}).get("build-backend", "")
sys.exit(0 if backend.startswith("rapids_build_backend") else 1)
PY
}

# install_built_wheel [pip-arg...] -- <spec>...
#
# Install wheels this pipeline produced, naming distributions rather than
# files. One BUILD_ARTIFACTS_DIR is filled by several interpreters, so a
# ${dist}*.whl glob also matches the wheels built for the other Python
# versions and pip rejects a file it was handed with a tag it cannot use;
# naming the distribution lets it take the wheel tagged for this interpreter.
#
# Specs carry their own version pin, so this stays usable from any project.
# The build passes --no-deps --no-index; the test passes nothing and resolves
# for real. Every spec goes in one pip call, so the resolver sees them together.
install_built_wheel() {
    local pip_args=() spec dist

    while [ $# -gt 0 ] && [ "$1" != "--" ]; do
        pip_args+=("$1")
        shift
    done
    if [ "${1:-}" != "--" ]; then
        echo "ERROR: install_built_wheel needs -- before the specs" >&2
        exit 1
    fi
    shift

    for spec in "$@"; do
        dist=${spec%%"["*}          # drop extras
        dist=${dist%%[=<>!~]*}      # drop the version specifier
        shopt -s nullglob
        # Deliberately unquoted, so the ? substituted for the separator globs:
        # pip canonicalizes the name and the file on disk may use the other one.
        # shellcheck disable=SC2206
        local found=( "${BUILD_ARTIFACTS_DIR}/"${dist//[-_]/?}-*.whl )
        shopt -u nullglob
        if [ ${#found[@]} -eq 0 ]; then
            echo "ERROR: no ${dist} wheel in ${BUILD_ARTIFACTS_DIR}" >&2
            exit 1
        fi
    done

    pip install "${pip_args[@]}" --find-links "${BUILD_ARTIFACTS_DIR}" "$@"
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
    local log_file
    log_file="${BUILD_ARTIFACTS_DIR}/$(basename "${pkg_relpath}")-wheel.log"

    cd "${WHEEL_BUILD_ROOT}/${pkg_relpath}"

    verify_build_requires "${pkg_relpath}"

    local backend_args=()
    if uses_rapids_build_backend; then
        backend_args=("${RAPIDS_BUILD_BACKEND_WHEEL_ARGS[@]}")
    fi

    if [ -n "${2:-}" ]; then
        local saved_cmake_args="${SKBUILD_CMAKE_ARGS:-}"
        export SKBUILD_CMAKE_ARGS="${SKBUILD_CMAKE_ARGS:+$SKBUILD_CMAKE_ARGS;}${2}"
    fi

    if ! python3 -m pip wheel . -w "${dist_dir}" \
        "${RAPIDS_PIP_WHEEL_ARGS[@]}" "${backend_args[@]}" "${@:3}" \
        >"${log_file}" 2>&1; then
        echo "==== pip wheel failed for ${pkg_relpath}; log: ${log_file} ====" >&2
        cat "${log_file}" >&2
        dump_rapids_wheel_build_logs "${pkg_relpath}"
        exit 1
    fi

    if [ -n "${2:-}" ]; then
        export SKBUILD_CMAKE_ARGS="${saved_cmake_args}"
    fi

    python3 -m auditwheel repair \
        "${AUDITWHEEL_EXCLUDE_ARGS[@]}" \
        -w "${BUILD_ARTIFACTS_DIR}" \
        "${dist_dir}"/*

    rm -rf "${dist_dir}"
}

# build_setuptools_wheel <pkg-relpath> [extra-pip-args...]
#
# Build a pure-Python wheel and repair it with auditwheel. The scikit-build-core
# settings in RAPIDS_PIP_WHEEL_ARGS do not apply here, but the backend args do:
# such a package can still go through rapids-build-backend to resolve the
# suffixed dependency names.
#
# --allow-pure-python-wheel (auditwheel >= 6.6.0) is what makes the repair step
# a copy rather than an error: a py3-none-any wheel has no ELF file to analyse,
# so auditwheel otherwise exits 1 on it.
build_setuptools_wheel() {
    : "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"
    : "${WHEEL_BUILD_ROOT:?WHEEL_BUILD_ROOT must be set}"

    local pkg_relpath=$1
    local dist_dir
    dist_dir=$(mktemp -d)
    local log_file
    log_file="${BUILD_ARTIFACTS_DIR}/$(basename "${pkg_relpath}")-wheel.log"

    cd "${WHEEL_BUILD_ROOT}/${pkg_relpath}"

    verify_build_requires "${pkg_relpath}"

    local backend_args=()
    if uses_rapids_build_backend; then
        backend_args=("${RAPIDS_BUILD_BACKEND_WHEEL_ARGS[@]}")
    fi

    if ! python3 -m pip wheel . -w "${dist_dir}" \
        --no-deps --no-build-isolation --disable-pip-version-check \
        "${backend_args[@]}" "${@:2}" \
        >"${log_file}" 2>&1; then
        echo "==== pip wheel failed for ${pkg_relpath}; log: ${log_file} ====" >&2
        cat "${log_file}" >&2
        exit 1
    fi

    python3 -m auditwheel repair \
        --allow-pure-python-wheel \
        "${AUDITWHEEL_EXCLUDE_ARGS[@]}" \
        -w "${BUILD_ARTIFACTS_DIR}" \
        "${dist_dir}"/*

    rm -rf "${dist_dir}"
}
