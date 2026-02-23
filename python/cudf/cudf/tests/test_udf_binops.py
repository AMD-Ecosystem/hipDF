# Copyright (c) 2018-2022, NVIDIA CORPORATION.

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

import numpy as np
import pytest
from numba.cuda import compile_ptx
from numba.np import numpy_support

import pylibcudf as plc
import rmm

import cudf
from cudf import Series
from cudf.utils import dtypes as dtypeutils

_driver_version = rmm._cuda.gpu.driverGetVersion()
_runtime_version = rmm._cuda.gpu.runtimeGetVersion()
_CUDA_JIT128INT_SUPPORTED = (_driver_version >= 11050) and (
    _runtime_version >= 11050
)
_CUDA_JIT128INT_SUPPORTED = True  # NOTE(HIP/AMD): ROCm>=7.0.0 supports this


@pytest.mark.skipif(not _CUDA_JIT128INT_SUPPORTED, reason="requires CUDA 11.5")
@pytest.mark.parametrize(
    "dtype", sorted(list(dtypeutils.NUMERIC_TYPES - {"int8"}))
)
def test_generic_ptx(dtype):
    size = 500
    rng = np.random.default_rng(42)

    lhs_arr = rng.random(size).astype(dtype)
    lhs_col = Series(lhs_arr)._column

    rhs_arr = rng.random(size).astype(dtype)
    rhs_col = Series(rhs_arr)._column

    def generic_function(a, b):
        return a**3 + b

    nb_type = numpy_support.from_dtype(cudf.dtype(dtype))
    type_signature = (nb_type, nb_type)

    # TODO(HIP/AMD): hardcoding this name because the cudf backend will search for it to identify the UDF in the code
    ptx_code, output_type = compile_ptx(
        generic_function,
        type_signature,
        device=True,
        name="udf_funcname_from_numba_to_be_replaced_in_libcudf",
    )

    dtype = numpy_support.as_dtype(output_type).type

    out_col = plc.binaryop.binaryop_udf(
        lhs_col.to_pylibcudf(mode="read"),
        rhs_col.to_pylibcudf(mode="read"),
        ptx_code,
        dtype,
    )
    # Wrap the plc column into a cuDF Series
    out_series = Series.from_pylibcudf(out_col)
    # Convert to NumPy array on host
    out_arr = out_series.to_numpy()

    result = lhs_arr**3 + rhs_arr

    np.testing.assert_almost_equal(result, out_arr)
