..
    MIT License

    Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.

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

Installing hipDF
=================

You can install hipDF via AMD PyPI, which is recommended for end users, or build
and install it from source as described in :doc:`Building hipDF from source <BUILD>`.

See :ref:`hipDF-support` for information regarding supported operating systems, ROCm versions,
and AMD GPUs before installing hipDF.

Prerequisites
-------------

The following ROCm components must be installed:

- `hipBLAS <https://rocm.docs.amd.com/projects/hipBLAS/en/docs-10.0.0/>`__
- `hipFFT <https://rocm.docs.amd.com/projects/hipFFT/en/docs-10.0.0/>`__
- `hipRAND <https://rocm.docs.amd.com/projects/hipRAND/en/docs-10.0.0/>`__
- `rocRAND <https://rocm.docs.amd.com/projects/rocRAND/en/docs-10.0.0/>`__
- `hipSPARSE <https://rocm.docs.amd.com/projects/hipSPARSE/en/docs-10.0.0/>`__

The steps in this guide require a Conda installation.
A minimal free version of Conda is `Miniforge <https://conda-forge.org/download/>`__.

Install hipDF via AMD PyPI
---------------------------

.. warning::
   Only install hipDF using AMD's official package index.
   To ensure security, integrity, and supportability of your builds, consume packages exclusively from AMD's official package index. Do not install, mirror, or resolve dependencies from any third‑party or unofficial indexes.

Packaged versions of hipDF and its dependencies are distributed via
`AMD PyPI <https://pypi.amd.com/rocm-10.0.0/simple>`__. This section discusses how to install
hipDF via this package index.

Create and activate a Conda environment with a compatible Python version, such as 3.11 or 3.12 as shown below. For more information on compatible Python versions, see :ref:`hipDF-support`.

.. code-block:: bash

   conda create --name hipdf python=3.12 #Specify your Python version
   conda activate hipdf

hipDF can then be installed into this environment using pip and the AMD PyPI URL:

.. code-block:: bash

   pip install amd-hipdf==4.0.0 --extra-index-url=https://pypi.amd.com/rocm-10.0.0/simple

Installing ``amd-hipdf`` pulls in the matching ``amd-libhipdf`` and
``amd-pylibhipdf`` packages, so most users need only the command above. This
release publishes the following wheels:

.. list-table::
   :header-rows: 1

   * - Package
     - Contents
   * - ``amd-libhipdf``
     - The hipDF C++ headers and the libhipdf shared library. Install this on
       its own for a C++-only deployment.
   * - ``amd-pylibhipdf``
     - The low-level Python bindings for libhipdf.
   * - ``amd-hipdf``
     - The hipDF DataFrame library, and the package most users install.
   * - ``amd-dask_hipdf``
     - The Dask integration, for distributing hipDF DataFrames across
       multiple GPUs.

Verify correct installation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To verify that hipDF was installed correctly, see :doc:`Verifying your hipDF Installation <VERIFY>`.
