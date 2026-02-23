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

# Changelog for hipDF

Documentation for hipDF is available at
[https://rocm.docs.amd.com/projects/hipDF/en/latest/](https://rocm.docs.amd.com/projects/hipDF/en/latest/).

## hipDF 2.0.0 for ROCm-DS 25.10

### Added

 * Major upgrade aligning hipDF APIs with RAPIDS cuDF 25.02 APIs. For the detailed changes, see the original changelog at [original changelog](CHANGELOG_UPSTREAM_CUDF_25.02.md)

### Known limitations and notes
 * DEBUG builds with -O0 optimization are not currently supported. Use -Og or higher for DEBUG builds (default setting). Support for -O0 is planned in a future toolchain update.
 * When using the cudf.pandas acceleration layer with XNACK enabled and workloads that significantly exceed physical GPU VRAM (oversubscription), some systems may exhibit instability or reduced performance under heavy memory pressure.
 * Using the cudf.pandas acceleration layer with XNACK disabled (`HSA_XNACK=0`) can trigger instabilities.

## hipDF 1.0.0b1 for ROCm-DS 25.05

### Added

* Initial release based on cuDF 23.10.
