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

# install_built_wheel <dist>
#
# Install a wheel this run produced, naming the distribution rather than the
# file. The matrix fills one BUILD_ARTIFACTS_DIR from several interpreters, so
# a ${dist}*.whl glob also matches the wheels built for the other Python
# versions and pip rejects a file it was handed with a tag it cannot use;
# naming the distribution lets it take the wheel tagged for this interpreter
# out of the pool instead.
#
# --no-index keeps the proxy out, and --no-deps keeps _install-build-deps.sh the
# one place this venv is provisioned from. That leaves the wheels in
# BUILD_ARTIFACTS_DIR as the candidates, along with whatever the rocmds-links
# page sitting there lists -- pip reads any HTML in a --find-links directory --
# but that page carries the upstream ROCm-DS dependencies only, never hipDF's
# own distributions, so these stay local installs.
install_built_wheel() {
    local dist=$1 version

    shopt -s nullglob
    local wheels=( "${BUILD_ARTIFACTS_DIR}/${dist}"-*.whl )
    shopt -u nullglob
    if [ ${#wheels[@]} -eq 0 ]; then
        echo "ERROR: no ${dist} wheel in ${BUILD_ARTIFACTS_DIR}" >&2
        exit 1
    fi

    IFS=- read -r _ version _ <<<"$(basename "${wheels[0]}")"

    pip install --no-deps --no-index \
        --find-links "${BUILD_ARTIFACTS_DIR}" \
        "${dist}==${version}"
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
    verify_build_requires "${pkg_relpath}"

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

# build_setuptools_wheel <pkg-relpath> [extra-pip-args...]
#
# Build a pure-Python wheel and repair it with auditwheel. The scikit-build-core
# settings in RAPIDS_PIP_WHEEL_ARGS do not apply here, but rapidsai.disable-cuda
# does: these packages still go through rapids-build-backend to resolve the
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

    if ! python3 -m pip wheel . -w "${dist_dir}" \
        --no-deps --no-build-isolation --disable-pip-version-check \
        --config-settings=rapidsai.disable-cuda=true \
        "${@:2}" \
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
