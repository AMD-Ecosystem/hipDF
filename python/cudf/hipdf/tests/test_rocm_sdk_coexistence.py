# MIT License
#
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

"""hipDF, CuPy and torch must share one ROCm in a process.

torch ships ROCm as rocm-sdk wheels and loads them on import. With a system
ROCm next to them, every package has to pick the rocm-sdk copy, or two ROCm
runtimes end up in the process and LLVM aborts on its duplicate options.
"""

import importlib.util
import itertools
import os
import subprocess
import sys

import pytest

pytestmark = pytest.mark.skipif(
    importlib.util.find_spec("rocm_sdk") is None
    or importlib.util.find_spec("torch") is None,
    reason="needs torch with its rocm-sdk wheels",
)

WORK = {
    "cupy": "cupy.arange(5).sum()",
    "cudf": "cudf.Series([1, 2, 3]).sum()",
    "pylibcudf": "pylibcudf.Column.from_iterable_of_py([1, 2, 3])",
    "rmm": "rmm.DeviceBuffer(size=16)",
    "torch": 'torch.zeros(3, device="cuda").sum()',
}

REPORT = """
with open("/proc/self/maps") as maps:
    paths = {
        line.split()[-1]
        for line in maps
        if "libamdhip64.so" in line or "libamd_comgr.so" in line
    }
print("\\n".join(sorted(paths)))
"""

# Each package loads ROCm on its own, so each one is tried first: cupy and
# cudf in every order, rmm and pylibcudf without cupy, which cudf imports.
ORDERS = [
    *itertools.permutations(("cupy", "cudf", "torch")),
    ("rmm", "torch"),
    ("pylibcudf", "torch"),
]


@pytest.mark.parametrize("modules", ORDERS, ids=", ".join)
def test_one_rocm_per_process(modules):
    child = "\n".join(
        [f"import {', '.join(modules)}"]
        + [WORK[module] for module in modules]
        + [REPORT]
    )
    result = subprocess.run(
        [sys.executable, "-c", child],
        capture_output=True,
        text=True,
        cwd="/",
        timeout=600,
    )
    assert result.returncode == 0, result.stderr
    rocm_dirs = {os.path.dirname(path) for path in result.stdout.split()}
    assert len(rocm_dirs) == 1, f"ROCm loaded from {sorted(rocm_dirs)}"
