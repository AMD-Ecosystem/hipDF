# SPDX-FileCopyrightText: Copyright (c) 2023 NVIDIA CORPORATION & AFFILIATES.
# All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# MIT License
#
# Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

import os
import pathlib
import subprocess
import sys

import pytest


# Proxy check for whether the proxy could be referencing GPU objects without
# trying to import cuDF, which could poison the global environment
def _gpu_available():
    try:
        import rmm

        return rmm._cuda.gpu.getDeviceCount() >= 1
    except ImportError:
        return False


LOCATION = pathlib.Path(__file__).absolute().parent


@pytest.mark.skipif(
    not _gpu_available(), reason="Skipping test if a GPU isn't available."
)
def test_magics_gpu():
    sp_completed = subprocess.run(
        [sys.executable, LOCATION / "_magics_gpu_test.py"], capture_output=True
    )
    # NOTE(HIP/AMD): Allow the known HSA_XNACK warning emitted by cudf.pandas init.
    stderr = sp_completed.stderr.decode()
    if stderr:
        lines = [line.strip() for line in stderr.splitlines() if line.strip()]
        allowed = all(
            (
                "HSA_XNACK check bypassed." in line
                or "warnings.warn" in line
                or "UserWarning" in line
            )
            for line in lines
        )
        assert allowed, stderr


@pytest.mark.skip(
    "This test was viable when cudf.pandas was separate from cudf, but now "
    "that it is a subpackage we always require a GPU to be present and cannot "
    "run this test."
)
def test_magics_cpu():
    env = os.environ.copy()
    env["CUDA_VISIBLE_DEVICES"] = ""
    sp_completed = subprocess.run(
        [sys.executable, LOCATION / "_magics_cpu_test.py"],
        capture_output=True,
        env=env,
    )
    assert sp_completed.stderr.decode() == ""
