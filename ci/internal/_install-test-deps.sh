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

# Install test dependencies for hipDF. Meant to be sourced, not executed.
#
# Required environment variables:
#   BUILD_ARTIFACTS_DIR -- directory containing pre-built dependency wheels

set -euo pipefail

_TEST_DEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_REPO_ROOT="$(cd "${_TEST_DEPS_DIR}/../.." && pwd)"

pip install --upgrade pip
# pytest 9.1 dropped a positional parameter from _pytest.python.IdMaker, which
# pytest-cases probes at import time. Since it registers as a global pytest11
# plugin, the resulting TypeError aborts collection for every test file.
pip install 'pytest<9.1' pytest-timeout pytest-csv pytest-benchmark

# Runtime deps required by the cudf test/benchmark suite.
pip install pyarrow cachetools "pandas<2.4.0dev0"

# Optional backends that cudf's own tests reach for through importorskip, so a
# missing one costs coverage quietly instead of failing. Neither is in the cudf
# [test] extra nor in the third-party requirements, so nothing installed them
# here and mi355x #38 skipped every test in input_output/test_s3.py and
# test_hdf5.py. With them: 33 pass and 5 skip in the first, 18 pass and 14 skip
# in the second.
#
# moto needs its [server] extra, because test_s3.py drives a ThreadedMotoServer
# and moto.server does not import without flask. moto is already in
# conda/environments/all_rocm_arch-x86_64.yaml, so the dev environment has had
# it all along.
#
# gcsfs is deliberately left out. It would un-skip test_read_csv_gcs and
# test_write_orc_gcs, which reach a real bucket and fail without Google
# application credentials, turning two quiet skips into two standing failures.
pip install "moto[server]>=4.0.8" tables

pip install "pytest-rerunfailures!=16.0.0" "pytest-cases>=3.8.2" pytest-xdist "scipy==1.15.3"

# When using a conda env, dependency packages and hipDF itself are already
# installed there. Only install from BUILD_ARTIFACTS_DIR when running outside a
# conda env (e.g. in a pipeline-managed venv).
if [ -z "${HIPDF_CONDA_ENV:-}" ]; then
    specs=(
        "amd-rocmds-logger${ROCMDS_LOGGER_VERSION:+==${ROCMDS_LOGGER_VERSION}}"
        "amd-cupy${CUPY_VERSION:+==${CUPY_VERSION}}"
        "amd-libhipmm${HIPMM_VERSION:+==${HIPMM_VERSION}}"
        rocm-bindings-core
        rocm-bindings-hip
        rocm-bindings-compiler
        hip-python-interop
        "numba-hip${NUMBA_HIP_VERSION:+==${NUMBA_HIP_VERSION}}"
    )

    # hipDF wheels are installed separately by test-wheels.sh.
    pip install --no-deps \
        --find-links "${BUILD_ARTIFACTS_DIR}" \
        "${specs[@]}"

    # dask_cudf suites. dask-hip and hipucxx are not in the manifest
    # ci_packages set, so this stack is optional: when it cannot be installed,
    # clear the switch _test-helpers.sh reads rather than fail the whole run.
    # --no-deps throughout: amd-dask-hip pins the legacy hip-python
    # distributions, which would displace the rocm-bindings wheels above.
    if [ "${HIPDF_TEST_DASK:-0}" = "1" ]; then
        if pip install --no-deps \
               --find-links "${BUILD_ARTIFACTS_DIR}" \
               "amd-dask_hipdf${HIPDF_VERSION:+==${HIPDF_VERSION}}" \
               amd-dask-hip amd-distributed-hipucxx \
           && pip install "rapids-dask-dependency==26.6.*"; then
            :
        else
            echo "WARNING: dask stack unavailable; skipping dask_cudf suites."
            export HIPDF_TEST_DASK=0
        fi
    fi
fi

# Third-party integration test dependencies for cudf_pandas_tests. Two files,
# two pip invocations: the portable set resolves from PyPI, the torch wheels
# come from an AMD wheelhouse that changes per ROCm release and serves its own
# copy of their dependency closure, which must not be used to resolve the
# portable set.
#
# Both installs are fatal on failure, deliberately. This used to run inside
# run_hipdf_test_suites under `|| echo WARNING`, and because pip resolves a
# requirements file completely before installing any of it, a single
# unsatisfiable pin left the venv with none of these packages. The suite then
# reported twelve third-party modules as import errors that were invisible to
# merge_test_results, so the job passed with them all broken.
third_party_dir="${_REPO_ROOT}/python/cudf/cudf_pandas_tests/third_party_integration_tests"

# Which wheelhouse to pin against. Default to the ROCm the image actually
# carries rather than a hard-coded release: naming one by hand is how the
# suite ended up installing rocm-rel-7.2 torch wheels inside a ROCm 10.0.0
# image. Override with HIPDF_ROCM_WHEELHOUSE to test a different pin set.
if [ -z "${HIPDF_ROCM_WHEELHOUSE:-}" ] && [ -r /opt/rocm/.info/version ]; then
    HIPDF_ROCM_WHEELHOUSE="$(cut -d- -f1 < /opt/rocm/.info/version | tr -d '[:space:]')"
fi
rocm_wheelhouse="${HIPDF_ROCM_WHEELHOUSE:-10.0.0}"
rocm_requirements="${third_party_dir}/requirements-rocm-${rocm_wheelhouse}.txt"

if [ ! -f "${rocm_requirements}" ]; then
    echo "ERROR: no third-party test requirements for ROCm '${rocm_wheelhouse}';" \
         "${rocm_requirements} does not exist. Available:" >&2
    ls -1 "${third_party_dir}"/requirements-rocm-*.txt >&2
    echo "Set HIPDF_ROCM_WHEELHOUSE to one of the releases above, or add a" \
         "requirements file for this one." >&2
    exit 1
fi

pip install -r "${third_party_dir}/requirements.txt"
pip install -r "${rocm_requirements}"

# For jupyter notebooks: test_notebook_slow_repr executes one through
# nbconvert. The `cudf-pandas-tests` extra installs a bare `ipykernel`;
# upgrade it here so an environment that already has the old 7.0.0a0
# prerelease does not keep it.
pip install --upgrade "ipykernel>=7.3"
