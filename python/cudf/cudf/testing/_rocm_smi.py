# Copyright (c) 2019-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

"""Shared workaround for the ROCm SMI teardown double-free SIGABRT.

NOTE(HIP/AMD): When both PyTorch and the cuDF/ROCm stack are loaded in the
same process, the process aborts at interpreter shutdown with "double free or
corruption (!prev)" / SIGABRT (exit 134) *after* all tests have already passed.

Root cause: the abort is in the legacy ``librocm_smi64.so`` C++ static-storage
``std::map<amd::smi::DevInfoTypes, const char *>`` destructor, running from
``__run_exit_handlers`` at ``exit()``. That library is pulled in only by
PyTorch (``libtorch_hip.so`` -> ``DT_NEEDED librocm_smi64.so``, ``rsmi_init``),
while the cuDF/ROCm stack uses the newer ``libamd_smi.so``. With both SMI
libraries co-resident the legacy destructor double-frees.

This module centralizes the pytest workaround so each test suite's
``conftest.py`` can opt in without duplicating the logic:

    from cudf.testing._rocm_smi import (
        stash_exitstatus,
        exit_if_rocm_smi_loaded,
    )

    def pytest_sessionfinish(session, exitstatus):
        stash_exitstatus(session, exitstatus)

    def pytest_unconfigure(config):
        exit_if_rocm_smi_loaded(config)

The proper fix belongs upstream (PyTorch-ROCm should link the supported
``libamd_smi.so`` instead of the deprecated ``librocm_smi64.so``, and ROCm
SMI's static-map teardown should be made safe). See issue #442 for full
analysis and minimal reproducers.
"""

from __future__ import annotations

import os
import sys

_EXITSTATUS_ATTR = "_hipdf_exitstatus"


def rocm_smi_loaded() -> bool:
    """Return True if the legacy ROCm SMI library is mapped in this process.

    NOTE(HIP/AMD): PyTorch's ``libtorch_hip.so`` links the deprecated
    ``librocm_smi64.so`` and calls ``rsmi_init``. When that library is loaded
    after the rest of the ROCm stack (which uses the newer ``libamd_smi.so``),
    its static ``std::map<amd::smi::DevInfoTypes, const char *>`` destructor
    runs from ``__run_exit_handlers`` and double-frees, aborting the process
    with "double free or corruption (!prev)" *after* all tests have passed.

    Full analysis and minimal reproducers: see issue #442.
    (NOTE: reproduce with LD_PRELOAD unset; preloading librocm_smi64 makes a
    bare ``import torch`` abort on its own, masking the import-order behaviour.)
    """
    # ROCm, librocm_smi64.so and PyTorch-ROCm builds only exist on Linux, so
    # this bug cannot occur elsewhere. The detection relies on Linux procfs;
    # on any other platform (or a container without /proc) we report "not
    # loaded" and let normal interpreter shutdown proceed.
    if not sys.platform.startswith("linux"):
        return False
    try:
        with open("/proc/self/maps") as maps:
            return any("librocm_smi64.so" in line for line in maps)
    except OSError:
        return False


def stash_exitstatus(session, exitstatus) -> None:
    """Stash the pytest exit status on the config.

    Call this from ``pytest_sessionfinish`` so the real exit code can be
    propagated by :func:`exit_if_rocm_smi_loaded`, which runs later (in
    ``pytest_unconfigure``) and does not otherwise have access to it.
    """
    setattr(session.config, _EXITSTATUS_ATTR, int(exitstatus))


def exit_if_rocm_smi_loaded(config) -> None:
    """Avoid the ROCm SMI teardown double-free abort.

    Intended to be called at the end of ``pytest_unconfigure`` (the very last
    pytest hook, after the terminal summary and any reporting plugins have
    run). If the buggy ``librocm_smi64`` library is mapped, bypass the C/C++
    static destructors (which would otherwise abort with SIGABRT) by calling
    ``os._exit`` while preserving the real pytest exit status. Normal runs (no
    torch / no ROCm SMI) and non-Linux platforms are untouched.
    """
    if not rocm_smi_loaded():
        return

    exitstatus = getattr(config, _EXITSTATUS_ATTR, 0)
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(exitstatus)
