# SPDX-FileCopyrightText: Copyright (c) 2023-2024, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#
# Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
import numpy as np
import pandas as pd
import pytest
from feature_engine.imputation import DropMissingData
from feature_engine.preprocessing import MatchVariables

# Both tests return a DataFrame; the default `gold == cudf` comparison is
# ambiguous for those.
pytestmark = pytest.mark.assert_eq(fn=pd.testing.assert_frame_equal)


def test_drop_missing_data():
    data = {
        "x": [np.nan, 1, 1, 0, np.nan],
        "y": ["a", np.nan, "b", np.nan, "a"],
    }
    df = pd.DataFrame(data)

    dmd = DropMissingData()
    dmd.fit(df)

    return dmd.transform(df)


def test_match_variables():
    train = pd.DataFrame(
        {
            "Name": ["tom", "nick", "krish", "jack"],
            "City": ["London", "Manchester", "Liverpool", "Bristol"],
            "Age": [20, 21, 19, 18],
            "Marks": [0.9, 0.8, 0.7, 0.6],
        }
    )

    test = pd.DataFrame(
        {
            "Name": ["tom", "sam", "nick"],
            "Age": [20, 22, 23],
            "Marks": [0.9, 0.7, 0.6],
            "Hobbies": ["tennis", "rugby", "football"],
        }
    )

    match_columns = MatchVariables()

    match_columns.fit(train)

    df_transformed = match_columns.transform(test)

    return df_transformed
