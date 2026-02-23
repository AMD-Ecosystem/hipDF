# MIT License
#
# Copyright (c) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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
import pandas as pd
import pytest

import cudf
from cudf.testing import assert_eq


@pytest.fixture(scope="module")
def data():
    rng = np.random.default_rng(42)
    num_records = 2000
    pdf = pd.DataFrame(
        {
            "TransactionType": rng.choice(
                ["Deposit", "Withdrawal", "Transfer", "Payment"], num_records
            ),
        }
    )
    gdf = cudf.from_pandas(pdf)
    return pdf, gdf


def convert_udf_strings(transformation, pdf, gdf):
    def transform_func(transformation):
        if transformation == "lower":
            return lambda x: x.lower()
        elif transformation == "upper":
            return lambda x: x.upper()
        elif transformation == "replace":
            return lambda x: x + " replaced"
        else:
            raise ValueError("Unsupported transformation type")

    pdf["TransactionType"] = pdf["TransactionType"].apply(
        transform_func(transformation)
    )
    gdf["TransactionType"] = gdf["TransactionType"].apply(
        transform_func(transformation)
    )

    assert_eq(pdf, gdf)


@pytest.mark.parametrize(
    "conversion",
    ["lower", "upper", "replace"],
)
def test_convert_udf_strings(conversion, data):
    pdf, gdf = data
    convert_udf_strings(conversion, pdf, gdf)
