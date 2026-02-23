# Copyright (c) 2024-2025, NVIDIA CORPORATION.

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

from __future__ import annotations

import contextlib
import functools
import hashlib
import sys

import rmm.statistics

from cudf.options import get_option

# import nvtx  # NOTE(HIP/AMD): we follow cudf/pandas/annotation.py here


class nvtx:  # type: ignore
    """Noop-stub with the same API as nvtx."""

    @staticmethod
    def enabled():
        return False

    push_range = lambda *args, **kwargs: None  # noqa: E731
    pop_range = lambda *args, **kwargs: None  # noqa: E731

    class annotate:
        """No-op annotation/context-manager"""

        def __init__(
            self,
            message: str | None = None,
            color: str | None = None,
            domain: str | None = None,
            category: str | int | None = None,
        ):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        __call__ = lambda self, fn: fn  # noqa: E731


nvtx_annotate = nvtx.annotate

_NVTX_COLORS = ["green", "blue", "purple", "rapids"]


def _get_color_for_nvtx(name):
    m = hashlib.sha256()
    m.update(name.encode())
    hash_value = int(m.hexdigest(), 16)
    idx = hash_value % len(_NVTX_COLORS)
    return _NVTX_COLORS[idx]


def _performance_tracking(func, domain="cudf_python"):
    """Decorator for applying performance tracking (if enabled)."""

    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        with contextlib.ExitStack() as stack:
            if get_option("memory_profiling"):
                # NB: the user still needs to call `rmm.statistics.enable_statistics()`
                #     to enable memory profiling.
                stack.enter_context(
                    rmm.statistics.profiler(
                        name=rmm.statistics._get_descriptive_name_of_object(
                            func
                        )
                    )
                )
            if nvtx.enabled():
                stack.enter_context(
                    nvtx.annotate(
                        message=func.__qualname__,
                        color=_get_color_for_nvtx(func.__qualname__),
                        domain=domain,
                    )
                )
            return func(*args, **kwargs)

    return wrapper


_dask_cudf_performance_tracking = functools.partial(
    _performance_tracking, domain="dask_cudf_python"
)


def get_memory_records() -> dict[
    str, rmm.statistics.ProfilerRecords.MemoryRecord
]:
    """Get the memory records from the memory profiling

    Returns
    -------
    Dict that maps function names to memory records. Empty if
    memory profiling is disabled
    """
    return rmm.statistics.default_profiler_records.records


def print_memory_report(file=sys.stdout) -> None:
    """Pretty print the result of the memory profiling

    Parameters
    ----------
    file
        The output stream
    """
    print(rmm.statistics.default_profiler_records.report(), file=file)
