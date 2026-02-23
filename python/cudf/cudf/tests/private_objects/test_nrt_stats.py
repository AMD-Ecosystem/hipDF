# Copyright (c) 2025, NVIDIA CORPORATION.

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

import pytest

import cudf

if getattr(cudf, "__is_hip_amd_port__", False):
    pytest.skip(
        "This test is not supported on HIP/AMD platform (missing NRT implementation).",
        allow_module_level=True,
    )

from numba import config
from numba.cuda.memory_management.nrt import rtsys

from cudf._lib import strings_udf
from cudf.core.column import ColumnBase, as_column
from cudf.core.udf.scalar_function import SeriesApplyKernel
from cudf.core.udf.utils import (
    _get_input_args_from_frame,
    _make_free_string_kernel,
    _return_arr_from_dtype,
)
from cudf.utils._numba import _CUDFNumbaConfig


@pytest.mark.skip(reason="https://github.com/rapidsai/cudf/issues/19880")
def test_string_udf_basic(monkeypatch):
    monkeypatch.setattr(config, "CUDA_NRT_STATS", True)

    def double(st):
        return st + st

    sr = cudf.Series(["a", "b", "c"])

    sr.apply(double)

    stats = rtsys.get_allocation_stats()

    # one meminfo for each string that is later freed
    assert stats.mi_alloc - stats.mi_free == 0

    # one NRT_Allocate call for each string (string heap copy)
    # and later its matching free
    assert stats.alloc - stats.free == 0


@pytest.mark.skip(reason="https://github.com/rapidsai/cudf/issues/19880")
def test_string_udf_conditional_allocations(monkeypatch):
    monkeypatch.setattr(config, "CUDA_NRT_STATS", True)

    # One thread allocates an intermediate string
    # but the others do not
    def double(st):
        if st == "b":
            return st + st == "BB"
        return st == "a" or st == "c"

    sr = cudf.Series(["a", "b", "c"])

    before_stats = rtsys.get_allocation_stats()
    sr.apply(double)
    after_stats = rtsys.get_allocation_stats()

    assert after_stats.mi_alloc - before_stats.mi_free == 1
    assert after_stats.alloc - before_stats.free == 1


@pytest.mark.skip(reason="https://github.com/rapidsai/cudf/issues/19880")
def test_string_udf_free_kernel(monkeypatch):
    monkeypatch.setattr(config, "CUDA_NRT_STATS", True)

    def double(st):
        return st + st

    sr = cudf.Series(["a", "b", "c"])

    kernel, retty = SeriesApplyKernel(sr, double, ()).get_kernel()

    ans_col = _return_arr_from_dtype(retty, len(sr))
    ans_mask = as_column(True, length=len(sr), dtype="bool")
    output_args = [(ans_col, ans_mask), len(sr)]
    input_args = _get_input_args_from_frame(sr)
    launch_args = output_args + input_args

    with _CUDFNumbaConfig():
        kernel.forall(len(sr))(*launch_args)
    col = ColumnBase.from_pylibcudf(
        strings_udf.column_from_managed_udf_string_array(ans_col)
    )

    # MemInfos that own the strings should still be alive
    # and in turn, so should the heap strings
    stats = rtsys.get_allocation_stats()
    assert stats.mi_alloc - stats.mi_free == len(sr)
    assert stats.alloc - stats.free == len(sr)

    # free kernel should equalize all allocations
    free_kernel = _make_free_string_kernel()
    with _CUDFNumbaConfig():
        free_kernel.forall(len(col))(ans_col, len(col))

    stats = rtsys.get_allocation_stats()

    assert stats.mi_alloc - stats.mi_free == 0
    assert stats.alloc - stats.free == 0
