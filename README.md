<!---
    MIT License

    Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

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
> This ROCm&trade; port is derived work based on the NVIDIA RAPIDS&reg; cuDF project (**version 25.02**). It aims to
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

For example, the following snippet downloads a CSV, then uses the GPU to parse it into rows and columns and run calculations:
```python
import cudf

tips_df = cudf.read_csv("https://github.com/plotly/datasets/raw/master/tips.csv")
tips_df["tip_percentage"] = tips_df["tip"] / tips_df["total_bill"] * 100

# display average tip by dining party size
print(tips_df.groupby("size").tip_percentage.mean())
```

Or, you can use hipDF as a no-code-change accelerator for pandas, using
[`cudf.pandas`](https://docs.rapids.ai/api/cudf/stable/cudf_pandas).
`cudf.pandas` supports 100% of the pandas API, utilizing hipDF for
supported operations and falling back to pandas when needed:

```python
%load_ext cudf.pandas  # pandas operations now use the GPU!

import pandas as pd

tips_df = pd.read_csv("https://github.com/plotly/datasets/raw/master/tips.csv")
tips_df["tip_percentage"] = tips_df["tip"] / tips_df["total_bill"] * 100

# display average tip by dining party size
print(tips_df.groupby("size").tip_percentage.mean())
```

## Quick Start

> [!NOTE]
> Currently, a docker image is not available for AMD GPUs.

## Installation

> [!CAUTION]
> Incompatibility notice: Mixing RAPIDS and ROCmDS packages/installations is not supported. To avoid conflicts, strictly separate and isolated environments must be maintained if it is required to install both RAPIDS and ROCm-DS packages on the same system.

> [!NOTE]
> We support only AMD GPUs. Use the RAPIDS package for NVIDIA GPUs.

### ROCm/GPU Requirements

* ROCm HIP SDK compilers version 7.0.2
* Build requirements: `rocthrust-dev`, `rocm-llvm-dev`, `hipcub` (Ubuntu)
* Runtime requirements: `rocm-llvm-dev` (Ubuntu)
* Officially supported architecture (gfx90a, gfx942).
* Ubuntu 22.04+
* Python 3.10 or later

<!-- ### CUDA/GPU requirements

* CUDA 12.0+ with a compatible NVIDIA driver
* Volta architecture or better (Compute Capability >=7.0)

### Pip

cuDF can be installed via `pip` from the NVIDIA Python Package Index.
Be sure to select the appropriate cuDF package depending
on the major version of CUDA available in your environment:

```bash
pip install cudf-cu12
```

### Conda

> [!NOTE]
> Currently, this option is not supported for AMD GPUs.

hipDF can be installed with conda (via [miniconda](https://conda.io/miniconda.html) or the full [Anaconda distribution](https://www.anaconda.com/download)) from the `rapidsai` channel:

```bash
# NOTE: Conda installation not supported for hipDF for AMD GPUs.
conda install -c rapidsai -c conda-forge cudf=25.08
```

We also provide [nightly Conda packages](https://anaconda.org/rapidsai-nightly) built from the HEAD
of the latest cuDF development branch.

> [!NOTE]
> hipDF is supported only on Linux, and with Python versions 3.9 and later.

See the [RAPIDS installation guide](https://docs.rapids.ai/install) for more OS and version info. -->

## Install from AMD PyPI
See install [instructions](docs/install/INSTALL.md).

## Build/Install from Source
See build [instructions](docs/install/BUILD.md).


## Open GPU Data Science

The ROCm-DS suite of open source software libraries aims to enable execution of end-to-end data science and analytics pipelines entirely on AMD GPUs. It relies on ROCm HIP primitives for low-level compute optimization, but exposing that GPU parallelism and high-bandwidth memory speed through user-friendly Python interfaces.


### Apache Arrow on GPU

The GPU version of [Apache Arrow](https://arrow.apache.org/) is a common API that enables efficient interchange of tabular data between processes running on the GPU. End-to-end computation on the GPU avoids unnecessary copying and converting of data off the GPU, reducing compute time and cost for high-performance analytics common in artificial intelligence workloads. As the name implies, hipDF uses the Apache Arrow columnar data format on the GPU. Currently, a subset of the features in Apache Arrow are supported.
