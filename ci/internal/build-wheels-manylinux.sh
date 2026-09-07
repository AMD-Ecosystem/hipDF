#!/usr/bin/env bash
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

# Build the hipDF wheel matrix inside a manylinux container.
#
#   amd_libhipdf    ... py3-none ... once (python/libcudf)
#   amd_pylibhipdf  ... cp311-cp311 and cp312-abi3
#   amd_hipdf       ... cp311-cp311 and cp312-abi3
#   amd_dask_hipdf  ... cp311-cp311 and cp312-abi3
#
# Run this after build-dev.sh, never before.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${PROJECT_ID:?PROJECT_ID must be set}"
: "${SRC_DIR:?SRC_DIR must be set}"
: "${BUILD_DIR:?BUILD_DIR must be set}"
: "${INSTALL_DIR:?INSTALL_DIR must be set}"
: "${BUILD_ARTIFACTS_DIR:?BUILD_ARTIFACTS_DIR must be set}"

export PROJECT_ID SRC_DIR INSTALL_DIR BUILD_ARTIFACTS_DIR

mkdir -p "${BUILD_ARTIFACTS_DIR}"

python_versions=(3.11 3.12)
sabi_floors=(no 3.12)
expected_pylib_tags=(cp311-cp311 cp312-abi3)
expected_hipdf_tags=(cp311-cp311 cp312-abi3)
expected_dask_tags=(cp311-cp311 cp312-abi3)

python_bins=(
  /opt/python/cp311-cp311/bin
  /opt/python/cp312-cp312/bin
)

for python_bin in "${python_bins[@]}"; do
  if [ ! -x "${python_bin}/python" ]; then
    echo "ERROR: ${python_bin}/python is missing." >&2
    exit 1
  fi
done

base_path=${PATH}
HIPDF_BUILD_TYPE=wheels

echo "=============================================================="
echo "amd_libhipdf, built once with CPython ${python_versions[0]}"
echo "=============================================================="

PATH="${python_bins[0]}:${base_path}" \
BUILD_DIR="${BUILD_DIR}/libhipdf" \
HIPDF_BUILD_TYPE="${HIPDF_BUILD_TYPE}" \
HIPDF_BUILD_PYLIBCUDF= \
HIPDF_BUILD_HIPDF= \
HIPDF_BUILD_DASK_HIPDF= \
  "${SCRIPT_DIR}/build-wheels.sh"

for i in "${!python_versions[@]}"; do
  python_version=${python_versions[${i}]}
  sabi=${sabi_floors[${i}]}
  python_bin=${python_bins[${i}]}

  echo "=============================================================="
  echo "amd_pylibhipdf + amd_hipdf for CPython ${python_version} (USE_SABI=${sabi})"
  echo "=============================================================="

  PATH="${python_bin}:${base_path}" \
  BUILD_DIR="${BUILD_DIR}/cp${python_version//./}" \
  HIPDF_BUILD_TYPE="${HIPDF_BUILD_TYPE}" \
  HIPDF_BUILD_LIBHIPDF= \
  HIPDF_BUILD_DASK_HIPDF= \
  USE_SABI="${sabi}" \
    "${SCRIPT_DIR}/build-wheels.sh"

  echo "=============================================================="
  echo "amd_dask_hipdf for CPython ${python_version} (USE_SABI=${sabi})"
  echo "=============================================================="

  PATH="${python_bin}:${base_path}" \
  BUILD_DIR="${BUILD_DIR}/dask_cp${python_version//./}" \
  HIPDF_BUILD_TYPE="${HIPDF_BUILD_TYPE}" \
  HIPDF_BUILD_LIBHIPDF= \
  HIPDF_BUILD_PYLIBCUDF= \
  HIPDF_BUILD_HIPDF= \
  USE_SABI="${sabi}" \
    "${SCRIPT_DIR}/build-wheels.sh"
done

shopt -s nullglob
missing=()

echo "=============================================================="
echo "Wheels in ${BUILD_ARTIFACTS_DIR}"
echo "=============================================================="

found=( "${BUILD_ARTIFACTS_DIR}"/amd_libhipdf-*-py3-none-*.whl )
printf '  %-14s %d wheel(s)\n' "py3-none" "${#found[@]}"
if [ ${#found[@]} -eq 0 ]; then
  missing+=("amd_libhipdf (py3-none)")
fi

for i in "${!expected_pylib_tags[@]}"; do
  expected_tag=${expected_pylib_tags[${i}]}

  found=( "${BUILD_ARTIFACTS_DIR}"/amd_pylibhipdf-*-"${expected_tag}"-*.whl )
  printf '  %-14s %d pylibhipdf wheel(s)\n' "${expected_tag}" "${#found[@]}"
  if [ ${#found[@]} -eq 0 ]; then
    missing+=("amd_pylibhipdf from CPython ${python_versions[${i}]} (${expected_tag})")
  fi

  found=( "${BUILD_ARTIFACTS_DIR}"/amd_hipdf-*-"${expected_tag}"-*.whl )
  printf '  %-14s %d hipdf wheel(s)\n' "${expected_tag}" "${#found[@]}"
  if [ ${#found[@]} -eq 0 ]; then
    missing+=("amd_hipdf from CPython ${python_versions[${i}]} (${expected_tag})")
  fi

  expected_dask_tag=${expected_dask_tags[${i}]}
  found=( "${BUILD_ARTIFACTS_DIR}"/amd_dask_hipdf-*-"${expected_dask_tag}"-*.whl )
  printf '  %-14s %d dask_hipdf wheel(s)\n' "${expected_dask_tag}" "${#found[@]}"
  if [ ${#found[@]} -eq 0 ]; then
    missing+=("amd_dask_hipdf from CPython ${python_versions[${i}]} (${expected_dask_tag})")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "ERROR: the wheel matrix is incomplete. Nothing produced:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  echo "Wheels that are present:" >&2
  ls -1 "${BUILD_ARTIFACTS_DIR}" >&2 || true
  exit 1
fi

unexpected=()
for bad_tag in cp312-cp312 cp313-cp313; do
  found=( "${BUILD_ARTIFACTS_DIR}"/amd_pylibhipdf-*-"${bad_tag}"-*.whl )
  if [ ${#found[@]} -gt 0 ]; then
    unexpected+=("amd_pylibhipdf ${bad_tag} (${#found[@]} wheel(s))")
  fi
  found=( "${BUILD_ARTIFACTS_DIR}"/amd_hipdf-*-"${bad_tag}"-*.whl )
  if [ ${#found[@]} -gt 0 ]; then
    unexpected+=("amd_hipdf ${bad_tag} (${#found[@]} wheel(s))")
  fi
  found=( "${BUILD_ARTIFACTS_DIR}"/amd_dask_hipdf-*-"${bad_tag}"-*.whl )
  if [ ${#found[@]} -gt 0 ]; then
    unexpected+=("amd_dask_hipdf ${bad_tag} (${#found[@]} wheel(s))")
  fi
done
if [ ${#unexpected[@]} -gt 0 ]; then
  echo "ERROR: version-specific wheels outside the matrix:" >&2
  printf '  - %s\n' "${unexpected[@]}" >&2
  exit 1
fi

echo "Wheel matrix complete."
