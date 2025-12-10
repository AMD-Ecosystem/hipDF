# Copyright (c) 2023-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

from __future__ import annotations

import numba
from numba import config as numba_config
from packaging import version

# HIP implementation

def _get_ptx_file(path, prefix):
    """HIP implementation.

    The HIP implementation uses a single LLVM bundle
    for all supported architectures.
    Hence the path-prefix combination must yield
    a unique result.
    """
    files = glob.glob(os.path.join(path, f"{prefix}.ll"))
    if len(files) == 0:
        raise RuntimeError(f"LLVM file {prefix}.ll is missing")
    elif len(files) > 1:
        raise RuntimeError(
            f"More than one LLVM file found for path '{path}' and prefix '{prefix}'."
        )
    return files[0]

def _setup_numba():
    """HIP implementation does nothing.

    TODO:
        Put code that delegates `numba.cuda` to
        `numba.hip` here.
    """
    from numba import hip

    hip.pose_as_cuda()

# Avoids using contextlib.contextmanager due to additional overhead
class _CUDFNumbaConfig:
    def __enter__(self) -> None:
        self.CUDA_LOW_OCCUPANCY_WARNINGS = (
            numba_config.CUDA_LOW_OCCUPANCY_WARNINGS
        )
        numba_config.CUDA_LOW_OCCUPANCY_WARNINGS = 0

        self.is_numba_lt_061 = version.parse(
            numba.__version__
        ) < version.parse("0.61")

        if self.is_numba_lt_061:
            self.CAPTURED_ERRORS = numba_config.CAPTURED_ERRORS
            numba_config.CAPTURED_ERRORS = "new_style"

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        numba_config.CUDA_LOW_OCCUPANCY_WARNINGS = (
            self.CUDA_LOW_OCCUPANCY_WARNINGS
        )
        if self.is_numba_lt_061:
            numba_config.CAPTURED_ERRORS = self.CAPTURED_ERRORS
