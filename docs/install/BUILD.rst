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

Building and installing hipDF from source
==========================================

For developers, the following topic walks you through all necessary steps for building hipDF from source files.
For your convenience, the steps for the full installation including python enablement are condensed
into the `install_hipdf.sh <https://github.com/ROCm-DS/hipDF/blob/release/rocmds-26.03/install_hipdf.sh>`__ script. Read and edit the
script carefully to adapt the environment variables for your installation.

The following provides details on building the C++ components, running tests and benchmarks, and for building
the full hipDF installation including the Python layer. End users should see the :doc:`Installation instructions <INSTALL>`.

Build procedure for the C++ components
---------------------------------------

Building the C++/HIP components of hipDF can be achieved via the following command:

.. code-block:: bash

   ./build.sh libcudf tests benchmarks

Here, ``tests`` and ``benchmarks`` are optional flags that enable the respective additional functionalities.

.. note::
   In order to fetch the dependencies ``git`` needs to be installed on your system.

Running tests and benchmarks
-----------------------------

To run the tests use:

.. code-block:: bash

   ctest --test-dir cpp/build/

To run the benchmarks use:

.. code-block:: bash

   find cpp/build/benchmarks/ -type f -executable -exec {} \;

Building and installing hipDF including the Python layer
---------------------------------------------------------

You will perform the following steps:

1. :ref:`Install Conda <step-1-install-conda>`
2. :ref:`Download the hipDF repository <step-2-clone-the-hipdf-repository>`
3. :ref:`Create and activate hipDF Conda environment hipdf_dev <step-3-create-and-activate-hipdf-conda-environment-hipdf_dev>`
4. :ref:`Install the CuPy wheel into hipdf_dev <step-4-install-cupy-into-hipdf_dev>`
5. :ref:`Install Numba HIP into hipdf_dev <step-5-install-numba-hip-into-hipdf_dev>`
6. :ref:`Install hipMM into hipdf_dev <step-6-install-hipmm-into-hipdf_dev>`
7. :ref:`Install hipDF into hipdf_dev <step-7-install-hipdf-into-hipdf_dev>`
8. :ref:`Verify correctness of installation <step-8-verify-correct-installation>`

.. _step-1-install-conda:

Step 1: Install Conda
~~~~~~~~~~~~~~~~~~~~~~

hipDF must be built inside of a predefined Conda environment to ensure that
it is working properly. While the hipDF build process fetches C++
dependencies itself, it has Cython and Python dependencies (CuPy, Numba HIP,
hipMM, HIP Python, ROCm LLVM Python) that need to be installed into the
hipDF Conda environment before you can build and run the package. The
following diagram gives an overview:

.. image:: ../data/install/hipdf_cypy_deps.svg
   :alt: hipDF Cython (build) and Python (runtime) dependencies.

On an x86 Linux machine it is possible to download and install Miniforge with the following command:

.. code-block:: bash

   wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
   sh Miniforge3-Linux-x86_64.sh

For other architectures and operating systems take a look at the webpage of `Miniforge <https://conda-forge.org/download/>`__.

.. _step-2-clone-the-hipdf-repository:

Step 2: Clone the hipDF repository
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create a work directory ``/tmp/hipdf`` and clone the hipDF release branch into this directory:

.. code-block:: bash

   mkdir -p /tmp/hipdf # NOTE: feel free to adapt
   cd /tmp/hipdf

   git clone -b release/rocmds-26.03 https://github.com/ROCm-DS/hipDF hipdf

.. _step-3-create-and-activate-hipdf-conda-environment-hipdf_dev:

Step 3: Create and activate hipDF Conda environment hipdf_dev.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Create and activate the ``hipdf_dev`` Conda environment via:

.. code-block:: bash

   cd /tmp/hipdf/hipdf

   conda env create --name hipdf_dev --file conda/environments/all_rocm_arch-x86_64.yaml
   conda activate hipdf_dev

.. _step-4-install-cupy-into-hipdf_dev:

Step 4: Install CuPy into hipdf_dev
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Via AMD PyPI (recommended)
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   conda activate hipdf_dev
   pip install amd-cupy~=13.5.1 --extra-index-url=https://pypi.amd.com/rocm-7.2.1/simple

From source
^^^^^^^^^^^

These instructions use the AMD MI300 GPU (gfx942 architecture). The following only serves
as an example. ``HCC_AMDGPU_TARGET`` can be set to `any supported architecture <./hipDF-support.rst>`__.

1. In order to build CuPy from source, you will not only require the library
   packages (``hipblas``, ``hipfft``, ...) but also additional development packages
   (``-dev`` suffix on Ubuntu). Please ensure they are installed.

   Typical install command (may require super user privileges):

   .. code-block:: bash

      apt-get update

      apt install -y rocthrust-dev hipcub hipblas \
                     hipblas-dev hipfft hipsparse \
                     hiprand rocsolver rocrand-dev

   .. note::
      Some ROCm installations may require that you append the ROCm version
      as suffix to the package names (example: ``hipblas-dev7.0.0``). You can
      understand what to do via the ``rocm-core`` package, which will be installed
      for any ROCm installation. Check if the installed ``rocm-core`` package has
      the ROCm version as suffix via ``apt list``, then install the CuPy build
      dependencies accordingly.

2. Clone the CuPy release branch into the work directory:

   .. code-block:: bash

      cd /tmp/hipdf
      git clone -b release/rocmds-26.03 https://github.com/ROCm/cupy cupy

3. Build and install the CuPy wheel:

   .. code-block:: bash

      cd /tmp/hipdf
      git submodule update --init
      conda activate hipdf_dev
      python3 -m pip install build scipy
      export CUPY_INSTALL_USE_HIP=1
      export ROCM_HOME=/opt/rocm        # NOTE: adapt to your environment
      export HCC_AMDGPU_TARGET="gfx942" # NOTE: set AMD GPU architecture(s)
      SETUPTOOLS_BUILD_PARALLEL=${MAX_JOBS:-1} python3 -m build --wheel
      CUPY_WHEEL=$(find ~+ -type f -name "*cupy*.whl")
      pip install ${CUPY_WHEEL}

You can specify the AMD GPU architectures via the ``HCC_AMDGPU_TARGET``
environment variable (add a separator if needed: ``,``) as shown.
Refer to `Release Compatibility <https://rocm.docs.amd.com/projects/rocm-ds/en/latest/about/compatibility-matrix.html>`__
for supported GPU architectures.

.. _step-5-install-numba-hip-into-hipdf_dev:

Step 5: Install Numba HIP into hipdf_dev.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Provide the version of your ROCm installation here via the
optional dependency key ``rocm-X-Y-Z``, as shown in the following command.

.. code-block:: bash

   conda activate hipdf_dev

   pip install --upgrade pip
   pip install --extra-index-url https://pypi.amd.com/rocm-7.2.1/simple \
     numba-hip[rocm-7-2-1]@git+https://github.com/rocm/numba-hip.git
     # NOTE: adapt ROCm key to your Python version

.. _step-6-install-hipmm-into-hipdf_dev:

Step 6: Install hipMM into hipdf_dev
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Via AMD PyPI (recommended)
^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   pip install amd-hipmm==4.0.0 --extra-index-url=https://pypi.amd.com/rocm-7.2.1/simple

From source
^^^^^^^^^^^

The following instructions use the AMD MI300 GPU (gfx942 architecture). However, this
is only for example purposes. ``RAPIDS_CMAKE_HIP_ARCHITECTURES`` can be
set to `any supported architecture <./hipDF-support.rst>`__.

1. Clone the hipMM release branch into the work directory:

   .. code-block:: bash

      cd /tmp/hipdf
      git clone -b release/rocmds-26.03 https://github.com/ROCm-DS/hipMM hipmm

2. Build and install the hipMM wheel:

   .. code-block:: bash

      conda activate hipdf_dev

      cd /tmp/hipdf/hipmm
      export RAPIDS_CMAKE_HIP_ARCHITECTURES="gfx942" # NOTE: set AMD GPU architecture(s)
      export CXX="hipcc"  # Cython CXX compiler, adapt to your environment
      export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # NOTE: ROCm CMake package location, adapt to your environment

      ./build.sh librmm rmm # Build rmm and install into `hipdf_dev` conda env.

You can set the AMD GPU architecture(s) to build for via the
``RAPIDS_CMAKE_HIP_ARCHITECTURES`` environment variable (separator: ``;``), or rely on auto detection.

.. _step-7-install-hipdf-into-hipdf_dev:

Step 7: Install hipDF into hipdf_dev
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These instructions use the AMD MI300 GPU (gfx942 architecture). However, this
is only for example purposes. ``CUDF_CMAKE_HIP_ARCHITECTURES`` can be set
to `any supported architecture <./hipDF-support.rst>`__.

Install the ``amd-hipdf`` Python package as shown below:

.. code-block:: bash

   conda activate hipdf_dev

   cd /tmp/hipdf/hipdf
   export CXX="hipcc"  # Cython CXX compiler, adapt to your environment
   export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake

   export PARALLEL_LEVEL=16 # NOTE: number of build threads, adapt as needed

   export LDFLAGS="-Wl,-O2 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,--disable-new-dtags -Wl,--gc-sections -Wl,--allow-shlib-undefined -Wl,-rpath,/lib/x86_64-linux-gnu/ -Wl,-rpath,${CONDA_PREFIX}/lib -Wl,-rpath-link,${CONDA_PREFIX}/lib -L${CONDA_PREFIX}/lib"

   export CUDF_CMAKE_HIP_ARCHITECTURES="gfx942" # NOTE: adapt to your AMD GPU architecture

   bash build.sh libcudf pylibcudf cudf # NOTE: the build target is called 'cudf'

You can set the AMD GPU architecture(s) to build for via the
``CUDF_CMAKE_HIP_ARCHITECTURES`` environment variable (separator: ``;``), or rely on auto detection.

.. _step-8-verify-correct-installation:

Step 8: Verify correct installation
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To verify that hipDF was installed correctly, see :doc:`Verifying your hipDF Installation <VERIFY>`.
