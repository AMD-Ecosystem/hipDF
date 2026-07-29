..
    MIT License

    Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

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

.. meta::
  :description: hipDF documentation and API reference library
  :keywords: hipDF, cuDF, Pandas, AMD Data Science, API, documentation

.. _hipDF-index:

********************************************************************
hipDF documentation
********************************************************************

hipDF enables GPU-accelerated DataFrames based on the Apache Arrow columnar memory
format. Its API is similar to that of Pandas, letting you accelerate both your existing and new
data science workloads on AMD GPUs with high-level functions that eliminate the
need to go into low-level HIP programming. This library enables large-scale data processing on AMD Instinct
GPUs, enabling data manipulation tasks such as loading, joining, aggregating, and filtering
to be performed on data in GPU memory. hipDF offers both a Python and C++ API, supporting
a wide range of use cases. For more information and to learn about what's new in the latest release, see :ref:`what-is-hipdf`

The hipDF code is open and hosted at `https://github.com/AMD-Ecosystem/hipDF <https://github.com/AMD-Ecosystem/hipDF>`_.

The hipDF documentation is structured as follows:

.. grid:: 2
  :gutter: 3

  .. grid-item-card:: Installation

    * :doc:`hipDF supported environments, features, and interfaces <./install/hipDF-support>`
    * `Install hipDF <./install/INSTALL.html>`_
    * `Build hipDF <./install/BUILD.html>`_
    * `Verify hipDF Installation <./install/VERIFY.html>`_

  .. grid-item-card:: How to

    * :doc:`Using hipDF's cudf.pandas acceleration with HIP managed memory <./how-to/cudf_pandas>`

  .. grid-item-card:: Reference

    * :ref:`hipDF-reference`

To contribute to the documentation refer to `Contributing to AMD Data Science  <https://rocm.docs.amd.com/projects/rocm-ds/en/latest/contribute/contributing.html>`__.

You can find licensing information on the `Licenses <https://rocm.docs.amd.com/projects/rocm-ds/en/latest/about/license.html>`__ page.
