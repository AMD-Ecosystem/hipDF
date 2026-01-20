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

from cython.operator import dereference

from libcpp cimport bool
from libcpp.memory cimport unique_ptr
from libcpp.utility cimport move
from pylibcudf.libcudf cimport binaryop as cpp_binaryop
from pylibcudf.libcudf.binaryop cimport binary_operator
from pylibcudf.libcudf.column.column cimport column

# NOTE(HIP/AMD): The imports are necessary for binaryop_udf
from pylibcudf.libcudf.types cimport data_type, type_id
from pylibcudf.libcudf.column.column_view cimport column_view
from libcpp.string cimport string
from cudf.core.buffer import acquire_spill_lock
from cudf.utils.dtypes import SUPPORTED_NUMPY_TO_PYLIBCUDF_TYPES
import cudf

from pylibcudf.libcudf.binaryop import \
    binary_operator as BinaryOperator  # no-cython-lint

from rmm.pylibrmm.stream cimport Stream

from .column cimport Column
from .scalar cimport Scalar
from .types cimport DataType
from .utils cimport _get_stream

__all__ = ["BinaryOperator", "binary_operation", "is_supported_operation"]

cpdef Column binary_operation(
    LeftBinaryOperand lhs,
    RightBinaryOperand rhs,
    binary_operator op,
    DataType output_type,
    Stream stream=None
):
    """Perform a binary operation between a column and another column or scalar.

    ``lhs`` and ``rhs`` may be a
    :py:class:`~pylibcudf.column.Column` or a
    :py:class:`~pylibcudf.scalar.Scalar`, but at least one must be a
    :py:class:`~pylibcudf.column.Column`.

    For details, see :cpp:func:`binary_operation`.

    Parameters
    ----------
    lhs : Union[Column, Scalar]
        The left hand side argument.
    rhs : Union[Column, Scalar]
        The right hand side argument.
    op : BinaryOperator
        The operation to perform.
    output_type : DataType
        The data type to use for the output.
    stream : Stream | None
        CUDA stream on which to perform the operation.

    Returns
    -------
    pylibcudf.Column
        The result of the binary operation
    """
    cdef unique_ptr[column] result
    stream = _get_stream(stream)

    if LeftBinaryOperand is Column and RightBinaryOperand is Column:
        with nogil:
            result = cpp_binaryop.binary_operation(
                lhs.view(),
                rhs.view(),
                op,
                output_type.c_obj,
                stream.view()
            )
    elif LeftBinaryOperand is Column and RightBinaryOperand is Scalar:
        with nogil:
            result = cpp_binaryop.binary_operation(
                lhs.view(),
                dereference(rhs.c_obj),
                op,
                output_type.c_obj,
                stream.view()
            )
    elif LeftBinaryOperand is Scalar and RightBinaryOperand is Column:
        with nogil:
            result = cpp_binaryop.binary_operation(
                dereference(lhs.c_obj),
                rhs.view(),
                op,
                output_type.c_obj,
                stream.view()
            )
    else:
        raise ValueError(f"Invalid arguments {lhs} and {rhs}")

    return Column.from_libcudf(move(result), stream)


cpdef bool is_supported_operation(
    DataType out,
    DataType lhs,
    DataType rhs,
    binary_operator op
):
    """Check if an operation is supported for the given data types.

    For details, see :cpp:func::`is_supported_operation`.

    Parameters
    ----------
    out : DataType
        The output data type.
    lhs : DataType
        The left hand side data type.
    rhs : DataType
        The right hand side data type.
    op : BinaryOperator
        The operation to check.

    Returns
    -------
    bool
        True if the operation is supported, False otherwise
    """

    return cpp_binaryop.is_supported_operation(
        out.c_obj,
        lhs.c_obj,
        rhs.c_obj,
        op
    )

# NOTE(HIP/AMD): Thi method is removed from cudf-24.04. 
# We have added it for additional testing puposes.
@acquire_spill_lock()
def binaryop_udf(Column lhs, Column rhs, udf_ptx, dtype, Stream stream=None):
    """
    Apply a user-defined binary operator (a UDF) defined in `udf_ptx` on
    the two input columns `lhs` and `rhs`. The output type of the UDF
    has to be specified in `dtype`, a numpy data type.
    Currently ONLY int32, int64, float32 and float64 are supported.
    """
    cdef column_view c_lhs = lhs.view()
    cdef column_view c_rhs = rhs.view()

    cdef type_id tid = (
        <type_id> (SUPPORTED_NUMPY_TO_PYLIBCUDF_TYPES[cudf.dtype(dtype)])
    )
    cdef data_type c_dtype = data_type(tid)

    cdef string cpp_str = udf_ptx.encode("UTF-8")

    cdef unique_ptr[column] c_result

    with nogil:
        c_result = move(
            cpp_binaryop.binary_operation(
                c_lhs,
                c_rhs,
                cpp_str,
                c_dtype,
                stream.view()
            )
        )

    return Column.from_libcudf(move(c_result), stream)
    
BinaryOperator.__str__ = BinaryOperator.__repr__
