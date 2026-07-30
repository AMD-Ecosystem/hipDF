---
myst:
  html_meta:
    "description": "AMD Data Science library for Data Frames."
    "keywords": "ROCm, AMD Data Science, Data Science, RAPIDS, AMD, CUDA, Data Frames, SDK"
---

# Installing hipDF

> **IMPORTANT:**
> You can install hipDF via AMD PyPI (recommended for regular users) or build
> and install it from source (for developers).

## Requirements

hipDF requires ROCm 6.4.0 or later running on Ubuntu 22.04 or later.
See {doc}`hipDF supported environments, features, and interfaces <./hipDF-support>`
for more details, including supported GPU architectures.

The following ROCm components must be installed:

- [hipBLAS](https://rocm.docs.amd.com/projects/hipBLAS/en/latest/index.html)
- [hipFFT](https://rocm.docs.amd.com/projects/hipFFT/en/latest/index.html)
- [hipRAND](https://rocm.docs.amd.com/projects/hipRAND/en/latest/index.html)
- [rocRAND](https://rocm.docs.amd.com/projects/rocRAND/en/latest/index.html)
- [hipSPARSE](https://rocm.docs.amd.com/projects/hipSPARSE/en/latest/)

The steps in this guide require a Conda installation.
A minimal free version of Conda is [Miniforge](https://conda-forge.org/download/).

## Install hipDF via AMD PyPI

Packaged versions of hipDF and its dependencies are distributed via
[AMD PyPI](https://pypi.amd.com/simple). This section discusses how to install
hipDF via this package index.

Create and activate a Conda environment with Python 3.10 and latest `libstdcxx-ng` as shown below:

```bash
conda create --name hipdf python=3.10
conda install -c conda-forge libstdcxx-ng # make sure that libstdcxx-ng>=13.2 is installed
conda activate hipdf
```

hipDF can then be installed into this environment using pip and the AMD PyPI URL:

```bash
pip install amd-hipdf==1.0.0b1 --extra-index-url=https://pypi.amd.com/simple
```

## Build hipDF from source

> **IMPORTANT:**
> The following section walks you through all necessary steps for the build process.
> For your convenience, we condensed these steps also into the
> [install_hipdf.sh](../../install_hipdf.sh) script. Read and edit the
> script carefully to adapt the environment variables for your installation.

### Installation Procedure

You will perform the following steps:

1. [Install Conda](#step-1-install-conda)
2. [Download the hipDF repository](#step-2-clone-the-hipdf-repository)
3. [Create and activate hipDF Conda environment `hipdf_dev`](#step-3-create-and-activate-hipdf-conda-environment-hipdf_dev)
4. [Install the CuPy wheel into `hipdf_dev`](#step-4-install-cupy-into-hipdf_dev)
5. [Install Numba HIP into `hipdf_dev`](#step-5-install-numba-hip-into-hipdf_dev)
6. [Install hipMM into `hipdf_dev`](#step-6-install-hipmm-into-hipdf_dev)
7. [Install hipDF into `hipdf_dev`](#step-7-install-hipdf-into-hipdf_dev)
8. [Verify correctness of installation](#step-8-verify-correct-installation)

#### Step 1: Install Conda

hipDF must be built inside of a predefined Conda environment to ensure that
it is working properly. While the hipDF build process fetches C++
dependencies itself, it has Cython and Python dependencies (CuPy, Numba HIP,
hipMM, HIP Python, ROCm LLVM Python) that need to be installed into the
hipDF Conda environment before you can build and run the package. The
following diagram gives an overview:

![hipDF Cython (build) and Python (runtime) dependencies.](../data/install/hipdf_cypy_deps.svg)

#### Step 2: Clone the hipDF repository

We create a work directory `/tmp/hipdf` and clone hipDF into this repository:

```bash
mkdir -p /tmp/hipdf # NOTE: feel free to adapt

cd /tmp/hipdf
git clone https://github.com/AMD-Ecosystem/hipDF hipdf -b release/1.0.x
```

#### Step 3: Create and activate hipDF Conda environment `hipdf_dev`.

We create and activate the `hipdf_dev` Conda environment via:

```bash
cd /tmp/hipdf/hipdf

conda env create --name hipdf_dev --file conda/environments/all_rocm_arch-x86_64.yaml
conda activate hipdf_dev
```

#### Step 4: Install CuPy into `hipdf_dev`

##### Via AMD PyPI (recommended)

```bash
conda activate hipdf_dev
pip install amd-cupy~=13.4 --extra-index-url=https://pypi.amd.com/simple
```

##### From source

> **NOTE:**
> These instructions use the AMD MI300 GPU (gfx942 architecture). However,
> this is only for example purposes. ``HCC_AMDGPU_TARGET`` can be set to
> {doc}`any supported architecture <./hipDF-support>`.

1. In order to build CuPy from source, you will not only require the library
   packages (`hipblas`, `hipfft`, ...) but also additional development packages
   (`-dev` suffix on Ubuntu). Please ensure they are installed.

   Typical install command (may require super user privileges):

   ```bash
   apt-get update

   apt install -y rocthrust-dev hipcub hipblas \
                  hipblas-dev hipfft hipsparse \
                  hiprand rocsolver rocrand-dev
   ```

   > **NOTE:**
   > Some ROCm installations may require that you append the ROCm version
   > as suffix to the package names (example: `hipblas-dev6.4.0`). You can
   > understand what to do via the `rocm-core` package, which will be installed
   > for any ROCm installation. Check if the installed `rocm-core` package has
   > the ROCm version as suffix via `apt list`, then install the CuPy build
   > dependencies accordingly.

2. Clone CuPy into the work directory:

   ```bash
   cd /tmp/hipdf
   git clone https://github.com/ROCm/cupy cupy -b rocmds/develop/13.4.x
   ```

3. Build and install the CuPy wheel:

   ```bash
   cd /tmp/hipdf
   git submodule update --init

   conda activate hipdf_dev
   export CUPY_INSTALL_USE_HIP=1
   export ROCM_HOME=/opt/rocm        # NOTE: adapt to your environment
   export HCC_AMDGPU_TARGET="gfx942" # NOTE: set AMD GPU architecture(s)
   python3 setup.py --cupy-package-name amd-cupy bdist_wheel # build the wheel
   pip install ./dist/amd_cupy*.whl
   ```

> **IMPORTANT:**
> We provide AMD GPU architectures here via the `HCC_AMDGPU_TARGET`
> environment variable (separator: `,`).
> Refer to [Release Compatibility](https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html)
> for supported GPU architectures.

#### Step 5: Install Numba HIP into `hipdf_dev`.

> **IMPORTANT:**
> You must provide the version of your ROCm installation here via the
> optional dependency key `rocm-X-Y-Z`.

```bash
conda activate hipdf_dev

pip install --upgrade pip
pip install --extra-index-url https://test.pypi.org/simple \
  numba-hip[rocm-6-4-0]@git+https://github.com/rocm/numba-hip.git
  # NOTE: adapt ROCm key to your Python version
```

#### Step 6: Install hipMM into `hipdf_dev`

##### Via AMD PyPI (recommended)

```bash
pip install amd-hipmm==1.0.0b1 --extra-index-url=https://pypi.amd.com/simple
```

##### From source

> **NOTE:**
> These instructions use the AMD MI300 GPU (gfx942 architecture). However, this
> is only for example purposes. ``RAPIDS_CMAKE_HIP_ARCHITECTURES`` can be
> set to {doc}`any supported architecture <./hipDF-support>`.

1. Clone hipMM into the work directory:

   ```bash
   cd /tmp/hipdf
   git clone https://github.com/AMD-Ecosystem/hipMM hipmm -b release/1.0.x
   ```

2. Build and install the hipMM wheel:

   ```bash
   conda activate hipdf_dev

   cd /tmp/hipdf
   git clone https://github.com/AMD-Ecosystem/hipMM hipmm -b release/1.0.x

   cd /tmp/hipdf/hipmm
   export RAPIDS_CMAKE_HIP_ARCHITECTURES="gfx942" # NOTE: set AMD GPU architecture(s)
   export CXX="hipcc"  # Cython CXX compiler, adapt to your environment
   export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # NOTE: ROCm CMake package location, adapt to your environment

   ./build.sh rmm # Build rmm and install into `hipdf_dev` conda env.
   ```

   > **IMPORTANT:**
   > Set the AMD GPU architecture(s) to build for via the
   > `RAPIDS_CMAKE_HIP_ARCHITECTURES` environment variable (separator: `;`)
   > or rely on auto detection.

#### Step 7: Install hipDF into `hipdf_dev`

> **NOTE:**
> These instructions use the AMD MI300 GPU (gfx942 architecture). However, this
> is only for example purposes. ``CUDF_CMAKE_HIP_ARCHITECTURES`` can be set
> to {doc}`any supported architecture <./hipDF-support>`.

Install the `amd-hipdf` Python package as shown below:

```bash
conda activate hipdf_dev

cd /tmp/hipdf/hipdf
export CXX="hipcc"  # Cython CXX compiler, adapt to your environment
export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake

export PARALLEL_LEVEL=16 # NOTE: number of build threads, adapt as needed

export LDFLAGS="-Wl,-O2 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,--disable-new-dtags -Wl,--gc-sections -Wl,--allow-shlib-undefined -Wl,-rpath,/lib/x86_64-linux-gnu/ -Wl,-rpath,${CONDA_PREFIX}/lib -Wl,-rpath-link,${CONDA_PREFIX}/lib -L${CONDA_PREFIX}/lib"

export CUDF_CMAKE_HIP_ARCHITECTURES="gfx942" # NOTE: adapt to your AMD GPU architecture

bash build.sh libcudf cudf # NOTE: the build target is called 'cudf'
```

> **IMPORTANT:**
> Set the AMD GPU architecture(s) to build for via the
> `CUDF_CMAKE_HIP_ARCHITECTURES` environment variable (separator: `;`) or rely
> on auto detection.

#### Step 8: Verify correct installation

> **IMPORTANT:**
> Running the instructions in this section requires an AMD GPU.

You have just completed installing hipDF for use in the Conda environment
`hipdf_dev`. To verify the correctness of the installation, run:

```bash
conda activate hipdf_dev
python3
```

Then enter the following code commands:

```python3
import hipdf
print(hipdf.__version__)
```

You should see output that is similar to:

```text
Python 3.10.12 (main, Feb  4 2025, 14:57:36) [GCC 11.4.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import hipdf
>>> print(hipdf.__version__)
1.0.00b1
```
