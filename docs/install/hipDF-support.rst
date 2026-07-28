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

.. _hipDF-support:

*******************************************************
hipDF supported environments, features, and interfaces
*******************************************************

hipDF requires ROCm 7.0.2 running on a `ROCm-supported operating system <https://rocm.docs.amd.com/projects/install-on-linux/en/docs-7.0.2/reference/system-requirements.html#supported-operating-systems>`__. Using Ubuntu 22.04 or later is recommended.
See `ROCm installation for Linux <https://rocm.docs.amd.com/projects/install-on-linux/en/latest/>`_
for installation instructions.

hipDF is supported on gfx942 and gfx90a only.

hipDF only supports features from cuDF 25.02. Support is limited to C++ and Python interfaces.
A Java interface is not supported.

hipDF does not support:

* zstd compression and decompression
* GPU direct storage (KvikIO, cuFile)
* rocTX tracing
* Per-thread default streams (PTDS)
* Integration with Dask hipDF or Dask HIP
* Interoperability with Polars
* Integration with third-party packages cuML, cuGraph, ibis, and stumpy
* The ``hipstreamz`` and ``hipdf_kafka`` Python packages
