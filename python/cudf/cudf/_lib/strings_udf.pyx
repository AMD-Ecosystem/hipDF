# Copyright (c) 2022-2025, NVIDIA CORPORATION.

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

from libc.stdint cimport uint8_t, uint16_t, uintptr_t
from libcpp.memory cimport unique_ptr
from libcpp.utility cimport move

from pylibcudf cimport Column as plc_Column
from pylibcudf.libcudf.column.column cimport column, column_view
from pylibcudf.libcudf.strings_udf cimport (
    column_from_managed_udf_string_array as cpp_column_from_managed_udf_string_array,
    free_managed_udf_string_array as cpp_free_managed_udf_string_array,
    get_character_cases_table as cpp_get_character_cases_table,
    get_character_flags_table as cpp_get_character_flags_table,
    get_special_case_mapping_table as cpp_get_special_case_mapping_table,
    to_string_view_array as cpp_to_string_view_array,
    managed_udf_string,
)
from rmm.librmm.device_buffer cimport device_buffer
from rmm.pylibrmm.device_buffer cimport DeviceBuffer
from rmm.pylibrmm.stream import DEFAULT_STREAM

import numpy as np


def column_to_string_view_array(plc_Column strings_col):
    cdef unique_ptr[device_buffer] c_buffer
    cdef column_view input_view = strings_col.view()
    with nogil:
        c_buffer = move(cpp_to_string_view_array(input_view))

    return DeviceBuffer.c_from_unique_ptr(move(c_buffer), DEFAULT_STREAM)


def column_from_managed_udf_string_array(DeviceBuffer d_buffer):
    cdef size_t size = int(d_buffer.c_size() / sizeof(managed_udf_string))
    cdef managed_udf_string* data = <managed_udf_string*>d_buffer.c_data()
    cdef unique_ptr[column] c_result

    with nogil:
        c_result = move(cpp_column_from_managed_udf_string_array(data, size))

    return plc_Column.from_libcudf(move(c_result), DEFAULT_STREAM)


def free_managed_udf_string_array(DeviceBuffer d_buffer):
    """Free the udf_string data within managed_udf_string array.

    Use this on HIP/AMD where NRT is not available for automatic memory management.
    """
    cdef size_t size = int(d_buffer.c_size() / sizeof(managed_udf_string))
    cdef managed_udf_string* data = <managed_udf_string*>d_buffer.c_data()

    with nogil:
        cpp_free_managed_udf_string_array(data, size)


def get_character_flags_table_ptr():
    cdef const uint8_t* tbl_ptr = cpp_get_character_flags_table()
    return np.uintp(<uintptr_t>tbl_ptr)


def get_character_cases_table_ptr():
    cdef const uint16_t* tbl_ptr = cpp_get_character_cases_table()
    return np.uintp(<uintptr_t>tbl_ptr)


def get_special_case_mapping_table_ptr():
    cdef const void* tbl_ptr = cpp_get_special_case_mapping_table()
    return np.uintp(<uintptr_t>tbl_ptr)
