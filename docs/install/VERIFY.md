<!---
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
-->

<!---
---
myst:
  html_meta:
    "description": "AMD Data Science library for Data Frames."
    "keywords": "ROCm, AMD Data Science, RAPIDS, AMD, CUDA, Data Frames, SDK"
---
-->

# Verifying your hipDF Installation

```{important}
* Running the instructions in this section requires an AMD GPU in your system.
* hipDF relies on CuPy with the ROCm backend. You must set the `ROCM_HOME` environment variable to the root of your ROCm installation so CuPy can locate ROCm. If ROCm is installed in the default location, set: `export ROCM_HOME=/opt/rocm`
* The instructions assume a Conda environment named `hipdf`. If your environment has a different name, replace `hipdf` in the commands with the environment name.
```

After installing hipDF for use in the Conda environment `hipdf`, you can
verify the correctness of the installation as follows:

```bash
conda activate hipdf
python3
```

Then enter the following code commands:

```python3
import hipdf
print(hipdf.__version__)
```

You should see output that is similar to:

```text
Python 3.12.11 | packaged by conda-forge | (main, Jun  4 2025, 14:45:31) [GCC 13.3.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import hipdf
>>> print(hipdf.__version__)
2.0.00
```
