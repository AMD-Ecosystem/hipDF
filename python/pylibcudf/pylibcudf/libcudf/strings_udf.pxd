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

from libc.stdint cimport uint8_t, uint16_t
from libcpp.memory cimport unique_ptr
from libcpp.string cimport string
from libcpp.vector cimport vector
from pylibcudf.exception_handler cimport libcudf_exception_handler
from pylibcudf.libcudf.column.column cimport column
from pylibcudf.libcudf.column.column_view cimport column_view
from pylibcudf.libcudf.types cimport size_type

from rmm.librmm.device_buffer cimport device_buffer

cdef extern from "cudf/strings/udf/managed_udf_string.cuh" namespace \
        "cudf::strings::udf" nogil:
    cdef cppclass managed_udf_string

cdef extern from "cudf/strings/udf/udf_apis.hpp"  namespace \
        "cudf::strings::udf" nogil:

    cdef int get_cuda_build_version() except +libcudf_exception_handler
    cdef unique_ptr[device_buffer] to_string_view_array(
        column_view
    ) except +libcudf_exception_handler
    cdef unique_ptr[column] column_from_managed_udf_string_array(
        managed_udf_string* strings, size_type size,
    ) except +libcudf_exception_handler
    cdef void free_managed_udf_string_array(
        managed_udf_string* strings, size_type size,
    ) except +libcudf_exception_handler

cdef extern from "cudf/strings/detail/char_tables.hpp" namespace \
        "cudf::strings::detail" nogil:
    cdef const uint8_t* get_character_flags_table() except +libcudf_exception_handler
    cdef const uint16_t* get_character_cases_table() except +libcudf_exception_handler
    cdef const void* get_special_case_mapping_table() except +libcudf_exception_handler
