<!---
    MIT License

    Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
-->

# <div align="left">&nbsp;hipDF - GPU DataFrames on AMD GPUs</div>

***
> [!NOTE]
> This README is derived from the original RAPIDSAI project's README. More care is necessary to remove/modify parts that are only applicable to the original version.

> [!NOTE]
> This ROCm&trade; port is derived work based on the NVIDIA RAPIDS&reg; cuDF project (**version 26.06**). It aims to
follow the latter's directory structure and API naming as closely as possible to minimize porting friction for users that are interested in using both projects.

## Resources

- [hipDF documentation](https://rocm.docs.amd.com/projects/hipDF/en/latest/)
- [ROCm-DS documentation](https://rocm.docs.amd.com/projects/rocm-ds/en/latest/)

RAPIDS resources:

<!--
- [Try cudf.pandas now](https://nvda.ws/rapids-cudf): Explore `cudf.pandas` on a free GPU enabled instance on Google Colab!
- [Install](https://docs.rapids.ai/install): Instructions for installing cuDF and other [RAPIDS](https://rapids.ai) libraries.
-->
- [cudf (Python) documentation](https://docs.rapids.ai/api/cudf/stable/)
- [libcudf (C++/CUDA) documentation](https://docs.rapids.ai/api/libcudf/stable/)
- [RAPIDS Community](https://rapids.ai/learn-more/#get-involved): Get help, contribute, and collaborate.

## Overview

Built based on the [Apache Arrow](http://arrow.apache.org/) columnar memory format, hipDF is a GPU DataFrame library for loading, joining, aggregating, filtering, and otherwise manipulating data.

hipDF provides a pandas-like API that will be familiar to data engineers & data scientists, so they can use it to easily accelerate their workflows without going into the details of HIP programming.

hipDF is composed of multiple libraries including:

* [libcudf](https://docs.rapids.ai/api/cudf/stable/libcudf_docs/): A HIP C++ library with [Apache Arrow](https://arrow.apache.org/) compliant
data structures and fundamental algorithms for tabular data.
* [pylibcudf](https://docs.rapids.ai/api/cudf/stable/pylibcudf/): A Python library providing [Cython](https://cython.org/) bindings for libcudf.
* [cudf](https://docs.rapids.ai/api/cudf/stable/user_guide/): A Python library providing
    - A DataFrame library mirroring the [pandas](https://pandas.pydata.org/) API
    - A zero-code change accelerator, [cudf.pandas](https://docs.rapids.ai/api/cudf/stable/cudf_pandas/), for existing pandas code.
* [cudf-polars](https://docs.rapids.ai/api/cudf/stable/cudf_polars/): A Python library providing a GPU engine for [Polars](https://pola.rs/)
* [dask-cudf](https://docs.rapids.ai/api/dask-cudf/stable/): A Python library providing a GPU backend for [Dask](https://www.dask.org/) DataFrames

## Quick Start

> [!NOTE]
> Currently, a docker image is not available for AMD GPUs.

## Installation

> [!CAUTION]
> Incompatibility notice: Mixing RAPIDS and ROCmDS packages/installations is not supported. To avoid conflicts, strictly separate and isolated environments must be maintained if it is required to install both RAPIDS and ROCm-DS packages on the same system.

> [!NOTE]
> We support only AMD GPUs. Use the RAPIDS package for NVIDIA GPUs.

### ROCm/GPU Requirements

* ROCm HIP SDK compilers version 7.2.1
* GCC 14 toolchain or later (for building from source)
* Build requirements: `rocthrust-dev`, `rocm-llvm-dev`, `hipcub` (Ubuntu)
* Runtime requirements: `rocm-llvm-dev` (Ubuntu)
* Officially supported architecture (gfx90a, gfx942, gfx950).
* Ubuntu 24.04+
* Python 3.10 or later

<!-- NOTE: The upstream NVIDIA-only install instructions below are intentionally
suppressed for hipDF. The cudf-cu13/cudf-cu12 PyPI wheels and the rapidsai conda
channel are NVIDIA/CUDA-only and inapplicable to AMD GPUs. AMD users should use
the AMD PyPI and source build instructions further below instead.

### System Requirements

Operating System, GPU driver, and supported CUDA version information can be found at the [RAPIDS Installation Guide](https://docs.rapids.ai/install/#system-req)

### pip

A stable release of each cudf library is available on PyPI. You will need to match the major version number of your installed CUDA version with a `-cu##` suffix when installing from PyPI.

A development version of each library is available as a nightly release by including the `-i https://pypi.anaconda.org/rapidsai-wheels-nightly/simple` index.

```bash
# CUDA 13
pip install libcudf-cu13
pip install pylibcudf-cu13
pip install cudf-cu13
pip install cudf-polars-cu13
pip install dask-cudf-cu13

# CUDA 12
pip install libcudf-cu12
pip install pylibcudf-cu12
pip install cudf-cu12
pip install cudf-polars-cu12
pip install dask-cudf-cu12
```

### conda

A stable release of each cudf library is available to be installed with the conda package manager by specifying the `-c rapidsai` channel.

A development version of each library is available as a nightly release by specifying the `-c rapidsai-nightly` channel instead.

```bash
conda install -c rapidsai libcudf
conda install -c rapidsai pylibcudf
conda install -c rapidsai cudf
conda install -c rapidsai cudf-polars
conda install -c rapidsai dask-cudf
```

### source

To install cuDF from source, please follow [the contribution guide](CONTRIBUTING.md#setting-up-your-build-environment) detailing
how to setup the build environment.
-->

## Examples

The following examples showcase reading a parquet file, dropping missing rows with a null value,
and performing a groupby aggregation on the data.

### cudf

`import cudf` and the APIs are largely similar to pandas.

```python
import cudf

df = cudf.read_parquet("data.parquet")
df.dropna().groupby(["A", "B"]).mean()
```

### cudf.pandas

With a Python file containing pandas code:

```python
import pandas as pd

df = pd.read_parquet("data.parquet")
df.dropna().groupby(["A", "B"]).mean()
```

Use cudf.pandas by invoking `python` with `-m cudf.pandas`

```bash
$ python -m cudf.pandas script.py
```

If running the pandas code in an interactive Jupyter environment, call `%load_ext cudf.pandas` before
importing pandas.

```python
In [1]: %load_ext cudf.pandas

In [2]: import pandas as pd

In [3]: df = pd.read_parquet("data.parquet")

In [4]: df.dropna().groupby(["A", "B"]).mean()
```

### cudf-polars

Using Polars' [lazy API](https://docs.pola.rs/user-guide/lazy/), call `collect` with `engine="gpu"` to run
the operation on the GPU

```python
import polars as pl

lf = pl.scan_parquet("data.parquet")
lf.drop_nulls().group_by(["A", "B"]).mean().collect(engine="gpu")
```

## Install from AMD PyPI
See install [instructions](docs/install/INSTALL.md).

## Build/Install from Source
See build [instructions](docs/install/BUILD.md).

## Open GPU Data Science

The ROCm-DS suite of open source software libraries aims to enable execution of end-to-end data science and analytics pipelines entirely on AMD GPUs. It relies on ROCm HIP primitives for low-level compute optimization, but exposing that GPU parallelism and high-bandwidth memory speed through user-friendly Python interfaces.

## Questions and Discussion

For bug reports or feature requests, please [file an issue](https://github.com/rapidsai/cudf/issues/new/choose) on the GitHub issue tracker.

For questions or discussion about cuDF and GPU data processing, feel free to post in the [RAPIDS Slack](https://rapids.ai/slack-invite) workspace.

### Apache Arrow on GPU

The GPU version of [Apache Arrow](https://arrow.apache.org/) is a common API that enables efficient interchange of tabular data between processes running on the GPU. End-to-end computation on the GPU avoids unnecessary copying and converting of data off the GPU, reducing compute time and cost for high-performance analytics common in artificial intelligence workloads. As the name implies, hipDF uses the Apache Arrow columnar data format on the GPU. Currently, a subset of the features in Apache Arrow are supported.

## Contributing

hipDF is open to contributions from the community! Please see our [guide for contributing to hipDF](CONTRIBUTING.md) for more information.
