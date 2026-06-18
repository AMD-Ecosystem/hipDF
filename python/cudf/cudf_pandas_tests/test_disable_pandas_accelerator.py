# SPDX-FileCopyrightText: Copyright (c) 2025, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

import os
import subprocess
import sys

import pytest

import cudf

# TODO(HIP/AMD): the `python -m cudf.pandas` subprocess startup (numba.hip +
# libcudf load/JIT) takes ~50s on the ROCm/HIP build, well above the 20s budget
# the upstream test assumes for CUDA. The thread output is correct; only the
# cold-start time differs, so allow a larger budget on the HIP port.
_SUBPROCESS_TIMEOUT = 120 if getattr(cudf, "__is_hip_amd_port__", False) else 20


@pytest.mark.flaky(reruns=3, reruns_delay=30)
def test_disable_pandas_accelerator_multi_threaded():
    data_directory = os.path.dirname(os.path.abspath(__file__))

    sp_completed = subprocess.run(
        [
            sys.executable,
            "-m",
            "cudf.pandas",
            data_directory + "/data/disable_cudf_pandas_multi_thread.py",
        ],
        capture_output=True,
        text=True,
        timeout=_SUBPROCESS_TIMEOUT,
    )
    assert sp_completed.returncode == 0
    output = sp_completed.stdout

    for string in [
        "Result from thread 1: 0<class 'type'>",
        "Result from thread 2: 1<class 'type'>",
        "Result from thread 3: 2<class 'type'>",
        "Result from thread 4: 3<class 'type'>",
    ]:
        assert string in output
