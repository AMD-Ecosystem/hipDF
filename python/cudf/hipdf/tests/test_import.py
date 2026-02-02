# MIT License
#
# Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
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


def test_import_hipdf():
    import hipdf.utils.utils
    import hipdf.utils.queryutils
    import hipdf.utils.performance_tracking
    import hipdf.utils.ioutils
    import hipdf.utils.gpu_utils
    import hipdf.utils.dtypes
    import hipdf.utils.docutils
    import hipdf.utils.cudautils
    import hipdf.utils.applyutils
    import hipdf.utils._numba
    import hipdf.utils
    import hipdf.testing.testing
    import hipdf.testing
    import hipdf.options
    import hipdf.io.text
    import hipdf.io.parquet
    import hipdf.io.orc
    import hipdf.io.json
    import hipdf.io.hdf
    import hipdf.io.feather
    import hipdf.io.dlpack
    import hipdf.io.csv
    import hipdf.io.avro
    import hipdf.io
    import hipdf.errors
    import hipdf.datasets
    import hipdf.core.window.rolling
    import hipdf.core.window.ewm
    import hipdf.core.window
    import hipdf.core.udf.utils
    import hipdf.core.udf.templates
    import hipdf.core.udf.strings_typing
    import hipdf.core.udf.strings_lowering
    import hipdf.core.udf.scalar_function
    import hipdf.core.udf.row_function
    import hipdf.core.udf.masked_typing
    import hipdf.core.udf.masked_lowering
    import hipdf.core.udf.groupby_utils
    import hipdf.core.udf.groupby_typing
    import hipdf.core.udf.groupby_lowering
    import hipdf.core.udf.api
    import hipdf.core.udf._ops
    import hipdf.core.udf
    import hipdf.core.tools.numeric
    import hipdf.core.tools.datetimes
    import hipdf.core.tools
    import hipdf.core.single_column_frame
    import hipdf.core.series
    import hipdf.core.reshape
    import hipdf.core.resample
    import hipdf.core.multiindex
    import hipdf.core.mixins.scans
    import hipdf.core.mixins.reductions
    import hipdf.core.mixins.mixin_factory
    import hipdf.core.mixins.binops
    import hipdf.core.mixins
    import hipdf.core.missing
    import hipdf.core.join.join
    import hipdf.core.join._join_helpers
    import hipdf.core.join
    import hipdf.core.indexing_utils
    import hipdf.core.indexed_frame
    import hipdf.core.index
    import hipdf.core.groupby.groupby
    import hipdf.core.groupby
    import hipdf.core.frame
    import hipdf.core.dtypes
    import hipdf.core.dataframe
    import hipdf.core.cut
    import hipdf.core.copy_types
    import hipdf.core.common
    import hipdf.core.column_accessor
    import hipdf.core.column.timedelta
    import hipdf.core.column.struct
    import hipdf.core.column.string
    import hipdf.core.column.numerical_base
    import hipdf.core.column.numerical
    import hipdf.core.column.lists
    import hipdf.core.column.interval
    import hipdf.core.column.decimal
    import hipdf.core.column.datetime
    import hipdf.core.column.column
    import hipdf.core.column.categorical
    import hipdf.core.column
    import hipdf.core.buffer.utils
    import hipdf.core.buffer.spillable_buffer
    import hipdf.core.buffer.spill_manager
    import hipdf.core.buffer.exposure_tracked_buffer
    import hipdf.core.buffer.buffer
    import hipdf.core.buffer
    import hipdf.core.algorithms
    import hipdf.core.abc
    import hipdf.core._internals.timezones
    import hipdf.core._internals.stream_compaction
    import hipdf.core._internals.sorting
    import hipdf.core._internals.copying
    import hipdf.core._internals.binaryop
    import hipdf.core._internals.aggregation
    import hipdf.core._internals
    import hipdf.core._compat
    import hipdf.core
    import hipdf.api.types
    import hipdf.api.extensions.accessor
    import hipdf.api.extensions
    import hipdf.api
    import hipdf._version
    import hipdf._lib.strings_udf
    import hipdf._lib
    import hipdf

def test_hipdf_attributes():
    import hipdf
    import cudf
    assert hipdf.__version__ == cudf.__version__
