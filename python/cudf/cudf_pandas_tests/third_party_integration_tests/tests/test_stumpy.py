# Copyright (c) 2023-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

# Skip the entire file if running on the HIP AMD port (Issue #336).
if getattr(cudf, "__is_hip_amd_port__", False):
    pytest.skip(
        "This test is CUDA-specific and not supported on HIP/AMD platform.",
        allow_module_level=True,
    )

import numpy as np
import pandas as pd
import stumpy
from numba import cuda
from pandas._testing import assert_equal


def stumpy_assert_equal(expected, got):
    def as_float64(x):
        if isinstance(x, (tuple, list)):
            return [as_float64(y) for y in x]
        else:
            return x.astype(np.float64)

    assert_equal(as_float64(expected), as_float64(got))


pytestmark = pytest.mark.assert_eq(fn=stumpy_assert_equal)


def test_1d_time_series():
    rng = np.random.default_rng(42)
    ts = pd.Series(rng.random(10))
    m = 3

    return stumpy.stump(ts, m)


def test_1d_gpu():
    rng = np.random.default_rng(42)
    your_time_series = rng.random(10000)
    window_size = (
        50  # Approximately, how many data points might be found in a pattern
    )
    all_gpu_devices = [
        int(device.id) for device in cuda.list_devices()
    ]  # Get a list of all available GPU devices

    return stumpy.gpu_stump(
        your_time_series, m=window_size, device_id=all_gpu_devices
    )


def test_multidimensional_timeseries():
    rng = np.random.default_rng(42)
    # Each row represents data from a different dimension while each column represents
    # data from the same dimension
    your_time_series = rng.random((3, 1000))
    # Approximately, how many data points might be found in a pattern
    window_size = 50

    return stumpy.mstump(your_time_series, m=window_size)


def test_anchored_time_series_chains():
    rng = np.random.default_rng(42)
    your_time_series = rng.random(10000)
    window_size = (
        50  # Approximately, how many data points might be found in a pattern
    )

    matrix_profile = stumpy.stump(your_time_series, m=window_size)

    left_matrix_profile_index = matrix_profile[:, 2]
    right_matrix_profile_index = matrix_profile[:, 3]
    idx = 10  # Subsequence index for which to retrieve the anchored time series chain for

    anchored_chain = stumpy.atsc(
        left_matrix_profile_index, right_matrix_profile_index, idx
    )

    all_chain_set, longest_unanchored_chain = stumpy.allc(
        left_matrix_profile_index, right_matrix_profile_index
    )

    return anchored_chain, all_chain_set, longest_unanchored_chain


def test_semantic_segmentation():
    rng = np.random.default_rng(42)
    your_time_series = rng.random(10000)
    window_size = (
        50  # Approximately, how many data points might be found in a pattern
    )

    matrix_profile = stumpy.stump(your_time_series, m=window_size)

    subseq_len = 50
    return stumpy.fluss(
        matrix_profile[:, 1], L=subseq_len, n_regimes=2, excl_factor=1
    )
