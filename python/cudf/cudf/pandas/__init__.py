# SPDX-FileCopyrightText: Copyright (c) 2023-2025, NVIDIA CORPORATION & AFFILIATES.
# All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# MIT License
#
# Modifications Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import os
import warnings

from hip import hip

import pylibcudf
import rmm.mr

from .fast_slow_proxy import (
    as_proxy_object,
    is_proxy_instance,
    is_proxy_object,
)
from .magics import load_ipython_extension
from .profiler import Profiler

__all__ = [
    "Profiler",
    "as_proxy_object",
    "install",
    "is_proxy_instance",
    "is_proxy_object",
    "load_ipython_extension",
]


LOADED = False


def install():
    """Enable Pandas Accelerator Mode."""
    from .module_accelerator import ModuleAccelerator

    loader = ModuleAccelerator.install("pandas", "cudf", "pandas")
    global LOADED
    LOADED = loader is not None
    if (
        "RAPIDS_NO_INITIALIZE" in os.environ
        or "CUDF_NO_INITIALIZE" in os.environ
    ):
        return

    try:
        # The default mode is "managed_pool" if UVM is supported, otherwise "pool"
        managed_memory_is_supported = (
            pylibcudf.utils._is_concurrent_managed_access_supported()
        )
    except RuntimeError as e:
        warnings.warn(str(e))
        return
    rmm_mode = os.getenv("CUDF_PANDAS_RMM_MODE")
    rmm_mode_explicitly_set = rmm_mode is not None
    if rmm_mode is None:
        rmm_mode = "managed_pool" if managed_memory_is_supported else "pool"

    # TODO(HIP/AMD): On MI300A, prefetching is not supported due to a known ROCm issue. Bypass prefetching by default.
    is_mi300a = False
    prop = hip.hipDeviceProp_t()
    hip.hipGetDeviceProperties(prop, 0)
    arch_name = prop.name.decode("utf-8")
    gcn_arch_name = (
        prop.gcnArchName.decode("utf-8")
        if hasattr(prop, "gcnArchName")
        else ""
    )

    # Extract the base GCN architecture (e.g., "gfx1100")
    import re

    gfx_match = re.match(r"(gfx[0-9a-fA-F]+)", gcn_arch_name)
    gfx_arch = gfx_match.group(1) if gfx_match else ""

    if "300A" in arch_name:
        is_mi300a = True

    # According to LLVM AMDGPU documentation, gfx11xx (RDNA 3/3.5) and gfx1200/gfx1201 (RDNA 4)
    # do not support XNACK (they are listed without xnack in the target features column)
    # MI series architectures (gfx90a, gfx94x, gfx95x) do support XNACK
    is_rdna_arch = gfx_arch.startswith("gfx11") or gfx_arch in (
        "gfx1200",
        "gfx1201",
    )

    # Check HSA_XNACK setting for page migration support, do not use prefetching if not set
    # RDNA devices do not support page migration, so disable prefetch adaptor to avoid crashes
    hsa_xnack = os.getenv("HSA_XNACK", "0")
    use_prefetch_adaptor = (
        hsa_xnack != "0" and not is_mi300a and not is_rdna_arch
    )
    bypass_check = os.getenv("CUDF_PANDAS_BYPASS_XNACK_CHECK", "0") == "1"

    if "managed" in rmm_mode:
        if not managed_memory_is_supported:
            raise ValueError(
                f"Managed memory is not supported on this system, so the requested {rmm_mode=} is invalid."
            )
        # For RDNA architectures, bypass the XNACK check and warn about experimental status
        if is_rdna_arch:
            warnings.warn(
                f"cudf.pandas on RDNA architecture ({gfx_arch}) is currently in experimental mode only "
                "and is not recommended for production workloads. RDNA architectures do not support "
                "XNACK, which may affect performance and stability.",
                UserWarning,
            )
        elif hsa_xnack == "0" and not bypass_check and not is_mi300a:
            raise RuntimeError(
                "cudf.pandas requires HSA_XNACK=1 for managed memory operations. "
                f"Current setting HSA_XNACK={hsa_xnack!r}. Please set HSA_XNACK=1 in your environment. "
                "To bypass this check (experimental, not recommended), set CUDF_PANDAS_BYPASS_XNACK_CHECK=1."
            )
        elif hsa_xnack == "0" and bypass_check and not is_mi300a:
            warnings.warn(
                f"HSA_XNACK check bypassed. Current HSA_XNACK={hsa_xnack!r}. "
                "This may cause crashes with managed memory operations on recent AMDGPU drivers.",
                UserWarning,
            )

    # Check if a non-default memory resource is set
    current_mr = rmm.mr.get_current_device_resource()
    if not isinstance(current_mr, rmm.mr.CudaMemoryResource):
        # Warn only if the user explicitly set CUDF_PANDAS_RMM_MODE
        if rmm_mode_explicitly_set:
            warnings.warn(
                "cudf.pandas detected an already configured memory resource, ignoring "
                f"'CUDF_PANDAS_RMM_MODE={rmm_mode}'",
                UserWarning,
            )
        return

    free_memory, _ = rmm.mr.available_device_memory()
    free_memory = int(round(float(free_memory) * 0.80 / 256) * 256)
    new_mr = current_mr

    if rmm_mode == "pool":
        new_mr = rmm.mr.PoolMemoryResource(
            current_mr,
            initial_pool_size=free_memory,
        )
    elif rmm_mode == "async":
        new_mr = rmm.mr.CudaAsyncMemoryResource(initial_pool_size=free_memory)
    elif rmm_mode == "managed":
        managed_mr = rmm.mr.ManagedMemoryResource()
        if use_prefetch_adaptor:
            new_mr = rmm.mr.PrefetchResourceAdaptor(managed_mr)
        else:
            new_mr = managed_mr
    elif rmm_mode == "managed_pool":
        pool_mr = rmm.mr.PoolMemoryResource(
            rmm.mr.ManagedMemoryResource(),
            initial_pool_size=free_memory,
        )
        if use_prefetch_adaptor:
            new_mr = rmm.mr.PrefetchResourceAdaptor(pool_mr)
        else:
            new_mr = pool_mr
    elif rmm_mode != "cuda":
        raise ValueError(f"Unsupported {rmm_mode=}")

    rmm.mr.set_current_device_resource(new_mr)

    if use_prefetch_adaptor:
        pylibcudf.prefetch.enable()


def pytest_load_initial_conftests(early_config, parser, args):
    # We need to install ourselves before conftest.py import (which
    # might import pandas) This hook is guaranteed to run before that
    # happens see
    # https://docs.pytest.org/en/7.1.x/reference/\
    # reference.html#pytest.hookspec.pytest_load_initial_conftests
    try:
        install()
    except RuntimeError:
        raise RuntimeError(
            "An existing plugin has already loaded pandas. Interposing failed."
        )
