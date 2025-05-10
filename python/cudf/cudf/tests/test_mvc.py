# Copyright (c) 2023-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

import subprocess
import sys

TEST_SCRIPT = """
import numba.cuda
import cudf
from cudf.utils._numba import _CUDFNumbaConfig, _setup_numba

import cudf

# Skip the entire file if running on the HIP AMD port
if getattr(cudf, "__is_hip_amd_port__", False):
    pytest.skip("This test is CUDA-specific and not supported on HIP/AMD platform.", 
                allow_module_level=True)

_setup_numba()

@numba.cuda.jit
def test_kernel(x):
    id = numba.cuda.grid(1)
    if id < len(x):
        x[id] += 1

s = cudf.Series([1, 2, 3])
with _CUDFNumbaConfig():
    test_kernel.forall(len(s))(s)
"""


def test_numba_mvc():
    cp = subprocess.run(
        [sys.executable, "-c", TEST_SCRIPT],
        capture_output=True,
        cwd="/",
    )

    assert cp.returncode == 0
