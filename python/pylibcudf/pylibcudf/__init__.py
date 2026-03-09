# Copyright (c) 2023-2025, NVIDIA CORPORATION.

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

# If libcudf was installed as a wheel, we must request it to load the library symbols.
# Otherwise, we assume that the library was installed in a system path that ld can find.
try:
    import libcudf
except ModuleNotFoundError:
    pass
else:
    libcudf.load_library()
    del libcudf

from . import (
    aggregation,
    binaryop,
    column_factories,
    concatenate,
    contiguous_split,
    copying,
    datetime,
    expressions,
    filling,
    groupby,
    hashing,
    interop,
    io,
    join,
    json,
    labeling,
    lists,
    merge,
    null_mask,
    nvtext,
    partitioning,
    prefetch,
    quantiles,
    reduce,
    replace,
    reshape,
    rolling,
    round,
    search,
    sorting,
    stream_compaction,
    strings,
    traits,
    transform,
    transpose,
    types,
    unary,
    utilities,
)
from ._version import __git_commit__, __version__
from .column import Column
from .gpumemoryview import gpumemoryview
from .scalar import Scalar
from .table import Table
from .types import DataType, MaskState, TypeId

__all__ = [
    "Column",
    "DataType",
    "MaskState",
    "Scalar",
    "Table",
    "TypeId",
    "aggregation",
    "binaryop",
    "column_factories",
    "concatenate",
    "contiguous_split",
    "copying",
    "datetime",
    "expressions",
    "filling",
    "gpumemoryview",
    "groupby",
    "hashing",
    "interop",
    "io",
    "join",
    "json",
    "labeling",
    "lists",
    "merge",
    "null_mask",
    "nvtext",
    "partitioning",
    "prefetch",
    "quantiles",
    "reduce",
    "replace",
    "reshape",
    "rolling",
    "round",
    "search",
    "sorting",
    "stream_compaction",
    "strings",
    "traits",
    "transform",
    "transpose",
    "types",
    "unary",
    "utilities",
]
