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

.. meta::
  :description: hipDF documentation and API reference library
  :keywords: hipDF, cuDF, Pandas, ROCm-DS, API, documentation

.. _hipDF-support:

*******************************************************
System requirements
*******************************************************

This topic lists the system requirements for using hipDF.

* ROCm version: `7.2.3 <https://rocm.docs.amd.com/projects/install-on-linux/en/docs-7.2.3/>`__
* Operating Systems: Ubuntu 24.04 and 22.04  

.. note::

   Building hipDF from source files requires GCC 13 or later, which is not delivered as part of Ubuntu 22.04 by default. You must install it manually. 
* AMD Instinct GPUs: 

  - MI355X (GPU target gfx950) 
  - MI325X / MI300X (GPU target gfx942) 
  - MI250 / MI210 (GPU target gfx90a) 

* Python versions: 3.10, 3.11, 3.12, 3.13

Conda virtual environment
-------------------------

The steps in this guide require a Conda installation.
A minimal free version of Conda is `Miniforge <https://conda-forge.org/download/>`__.
