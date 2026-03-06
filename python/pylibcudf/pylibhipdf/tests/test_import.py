# MIT License
#
# Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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


def test_import_pylibhipdf():
    # Main package
    import pylibhipdf

    # Core submodules (41 top-level modules from pylibcudf)
    import pylibhipdf.aggregation
    import pylibhipdf.binaryop
    import pylibhipdf.column_factories
    import pylibhipdf.concatenate
    import pylibhipdf.contiguous_split
    import pylibhipdf.copying
    import pylibhipdf.datetime
    import pylibhipdf.expressions
    import pylibhipdf.filling
    import pylibhipdf.groupby
    import pylibhipdf.hashing
    import pylibhipdf.interop
    import pylibhipdf.join
    import pylibhipdf.json
    import pylibhipdf.labeling
    import pylibhipdf.lists
    import pylibhipdf.merge
    import pylibhipdf.null_mask
    import pylibhipdf.partitioning
    import pylibhipdf.prefetch
    import pylibhipdf.quantiles
    import pylibhipdf.reduce
    import pylibhipdf.replace
    import pylibhipdf.reshape
    import pylibhipdf.rolling
    import pylibhipdf.round
    import pylibhipdf.search
    import pylibhipdf.sorting
    import pylibhipdf.stream_compaction
    import pylibhipdf.traits
    import pylibhipdf.transform
    import pylibhipdf.transpose
    import pylibhipdf.types
    import pylibhipdf.unary
    import pylibhipdf.utilities

    # IO submodules
    import pylibhipdf.io
    import pylibhipdf.io.avro
    import pylibhipdf.io.csv
    import pylibhipdf.io.datasource
    import pylibhipdf.io.json
    import pylibhipdf.io.orc
    import pylibhipdf.io.parquet
    import pylibhipdf.io.parquet_metadata
    import pylibhipdf.io.text
    import pylibhipdf.io.timezone
    import pylibhipdf.io.types

    # NVText submodules (and test the hiptext variant)
    import pylibhipdf.nvtext
    import pylibhipdf.nvtext.byte_pair_encode
    import pylibhipdf.nvtext.deduplicate
    import pylibhipdf.nvtext.edit_distance
    import pylibhipdf.nvtext.generate_ngrams
    import pylibhipdf.nvtext.jaccard
    import pylibhipdf.nvtext.minhash
    import pylibhipdf.nvtext.ngrams_tokenize
    import pylibhipdf.nvtext.normalize
    import pylibhipdf.nvtext.replace
    import pylibhipdf.nvtext.stemmer
    import pylibhipdf.nvtext.tokenize
    import pylibhipdf.nvtext.wordpiece_tokenize

    # Test hiptext variant alias
    import pylibhipdf.hiptext
    import pylibhipdf.hiptext.byte_pair_encode
    import pylibhipdf.hiptext.deduplicate
    import pylibhipdf.hiptext.edit_distance
    import pylibhipdf.hiptext.generate_ngrams
    import pylibhipdf.hiptext.jaccard
    import pylibhipdf.hiptext.minhash
    import pylibhipdf.hiptext.ngrams_tokenize
    import pylibhipdf.hiptext.normalize
    import pylibhipdf.hiptext.replace
    import pylibhipdf.hiptext.stemmer
    import pylibhipdf.hiptext.tokenize
    import pylibhipdf.hiptext.wordpiece_tokenize

    # Strings submodules
    import pylibhipdf.strings
    import pylibhipdf.strings.attributes
    import pylibhipdf.strings.capitalize
    import pylibhipdf.strings.case
    import pylibhipdf.strings.char_types
    import pylibhipdf.strings.combine
    import pylibhipdf.strings.contains
    import pylibhipdf.strings.extract
    import pylibhipdf.strings.find
    import pylibhipdf.strings.find_multiple
    import pylibhipdf.strings.findall
    import pylibhipdf.strings.padding
    import pylibhipdf.strings.regex_flags
    import pylibhipdf.strings.regex_program
    import pylibhipdf.strings.repeat
    import pylibhipdf.strings.replace
    import pylibhipdf.strings.replace_re
    import pylibhipdf.strings.reverse
    import pylibhipdf.strings.side_type
    import pylibhipdf.strings.slice
    import pylibhipdf.strings.strip
    import pylibhipdf.strings.translate
    import pylibhipdf.strings.wrap

    # Strings nested submodules - convert
    import pylibhipdf.strings.convert
    import pylibhipdf.strings.convert.convert_booleans
    import pylibhipdf.strings.convert.convert_datetime
    import pylibhipdf.strings.convert.convert_durations
    import pylibhipdf.strings.convert.convert_fixed_point
    import pylibhipdf.strings.convert.convert_floats
    import pylibhipdf.strings.convert.convert_integers
    import pylibhipdf.strings.convert.convert_ipv4
    import pylibhipdf.strings.convert.convert_lists
    import pylibhipdf.strings.convert.convert_urls

    # Strings nested submodules - split
    import pylibhipdf.strings.split
    import pylibhipdf.strings.split.partition
    import pylibhipdf.strings.split.split


def test_pylibhipdf_attributes():
    import pylibhipdf
    import pylibcudf

    # Verify version matches pylibcudf
    assert pylibhipdf.__version__ == pylibcudf.__version__

    # Verify key exports are accessible
    from pylibhipdf import Column, Table, Scalar, DataType, TypeId, MaskState, gpumemoryview

    # Verify they're the same objects as pylibcudf
    assert Column is pylibcudf.Column
    assert Table is pylibcudf.Table
    assert Scalar is pylibcudf.Scalar
    assert DataType is pylibcudf.DataType
    assert TypeId is pylibcudf.TypeId
    assert MaskState is pylibcudf.MaskState
    assert gpumemoryview is pylibcudf.gpumemoryview

    # Verify hiptext variant works
    assert pylibhipdf.hiptext is pylibhipdf.nvtext
