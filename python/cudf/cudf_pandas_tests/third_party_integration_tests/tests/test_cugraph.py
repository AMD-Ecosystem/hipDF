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

# Skip the entire file if running on the HIP AMD port
if getattr(cudf, "__is_hip_amd_port__", False):
    pytest.skip(
        "This test is CUDA-specific and not supported on HIP/AMD platform.",
        allow_module_level=True,
    )

import cugraph
import cupy as cp
import networkx as nx
import numpy as np
import pandas as pd

cugraph_algos = [
    "betweenness_centrality",
    "degree_centrality",
    "katz_centrality",
    "sorensen_coefficient",
    "jaccard_coefficient",
]

nx_algos = [
    "betweenness_centrality",
    "degree_centrality",
    "katz_centrality",
]


def assert_cugraph_equal(expect, got):
    if isinstance(expect, cp.ndarray):
        expect = expect.get()
    if isinstance(got, cp.ndarray):
        got = got.get()
    elif isinstance(expect, np.ndarray) and isinstance(got, np.ndarray):
        assert np.array_equal(expect, got)
    else:
        assert expect == got


pytestmark = pytest.mark.assert_eq(fn=assert_cugraph_equal)


@pytest.fixture(scope="session")
def df():
    return pd.DataFrame({"source": [0, 1, 2], "destination": [1, 2, 3]})


@pytest.fixture(scope="session")
def adjacency_matrix():
    data = {
        1: [0, 1, 1, 0],
        2: [1, 0, 0, 1],
        3: [1, 0, 0, 1],
        4: [0, 1, 1, 0],
    }
    df = pd.DataFrame(data, index=[1, 2, 3, 4])
    return df


@pytest.mark.parametrize("algo", cugraph_algos)
def test_cugraph_from_pandas_edgelist(df, algo):
    G = cugraph.Graph()
    G.from_pandas_edgelist(df)
    return getattr(cugraph, algo)(G).to_pandas().values


@pytest.mark.parametrize("algo", cugraph_algos)
def test_cugraph_from_pandas_adjacency(adjacency_matrix, algo):
    G = cugraph.Graph()
    G.from_pandas_adjacency(adjacency_matrix)
    res = getattr(cugraph, algo)(G).to_pandas()
    return res.sort_values(list(res.columns)).values


@pytest.mark.parametrize("algo", cugraph_algos)
def test_cugraph_from_numpy_array(df, algo):
    G = cugraph.Graph()
    G.from_numpy_array(df.values)
    return getattr(cugraph, algo)(G).to_pandas().values


@pytest.mark.parametrize("algo", nx_algos)
def test_networkx_from_pandas_edgelist(df, algo):
    G = nx.from_pandas_edgelist(
        df, "source", "destination", ["source", "destination"]
    )
    return getattr(nx, algo)(G)


@pytest.mark.parametrize("algo", nx_algos)
def test_networkx_from_pandas_adjacency(adjacency_matrix, algo):
    G = nx.from_pandas_adjacency(adjacency_matrix)
    return getattr(nx, algo)(G)


@pytest.mark.parametrize("algo", nx_algos)
def test_networkx_from_numpy_array(adjacency_matrix, algo):
    G = nx.from_numpy_array(adjacency_matrix.values)
    return getattr(nx, algo)(G)
