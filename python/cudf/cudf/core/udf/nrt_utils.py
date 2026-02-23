# Copyright (c) 2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
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

import contextvars
from contextlib import contextmanager

from numba import config as numba_config

# NOTE(HIP/AMD): Detect if we're running on HIP/AMD - numba-hip lacks NRT support
try:
    from numba.hip.amdgcn import DATA_LAYOUT  # noqa: F401

    _USE_NRT = False  # NRT not available in numba-hip
except ImportError:
    _USE_NRT = True  # CUDA build - NRT is available

_current_nrt_context: contextvars.ContextVar = contextvars.ContextVar(
    "current_nrt_context"
)


class CaptureNRTUsage:
    """
    Context manager for determining if NRT is needed.
    Managed types may set use_nrt to be true during
    instantiation to signal that NRT must be enabled
    during code generation.

    NOTE(HIP/AMD): On HIP, use_nrt is always False since NRT is not available.
    """

    def __init__(self):
        self.use_nrt = False

    def __enter__(self):
        self._token = _current_nrt_context.set(self)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        _current_nrt_context.reset(self._token)
        # NOTE(HIP/AMD): Force use_nrt to False if NRT is not available
        if not _USE_NRT:
            self.use_nrt = False


@contextmanager
def nrt_enabled():
    """
    Context manager for enabling NRT via the numba
    config. CUDA_ENABLE_NRT may be toggled dynamically
    for a single kernel launch, so we use this context
    to enable it for those that we know need it.

    NOTE(HIP/AMD): This is a no-op on HIP since NRT is not available.
    """
    if not _USE_NRT:
        # NRT not available, just yield without enabling
        yield
        return

    original_value = getattr(numba_config, "CUDA_ENABLE_NRT", False)
    numba_config.CUDA_ENABLE_NRT = True
    try:
        yield
    finally:
        numba_config.CUDA_ENABLE_NRT = original_value
