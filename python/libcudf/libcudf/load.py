# SPDX-FileCopyrightText: Copyright (c) 2024-2025, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0
#

# MIT License
#
# Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

import ctypes
import os

# Loading with RTLD_LOCAL adds the library itself to the loader's
# loaded library cache without loading any symbols into the global
# namespace. This allows libraries that express a dependency on
# this library to be loaded later and successfully satisfy this dependency
# without polluting the global symbol table with symbols from
# libcudf that could conflict with symbols from other DSOs.
PREFERRED_LOAD_FLAG = ctypes.RTLD_LOCAL


def _load_system_installation(soname: str):
    """Try to dlopen() the library indicated by ``soname``
    Raises ``OSError`` if library cannot be loaded.
    """
    return ctypes.CDLL(soname, PREFERRED_LOAD_FLAG)


def _load_wheel_installation(soname: str):
    """Try to dlopen() the library indicated by ``soname``

    Returns ``None`` if the library cannot be loaded.
    """
    if os.path.isfile(
        lib := os.path.join(os.path.dirname(__file__), "lib64", soname)
    ):
        return ctypes.CDLL(lib, PREFERRED_LOAD_FLAG)

    if os.path.isfile(
        lib := os.path.join(os.path.dirname(__file__), "lib", soname)
    ):
        return ctypes.CDLL(lib, PREFERRED_LOAD_FLAG)

    return None


def _preload_rocm_sdk():
    """Load the ROCm runtime from the rocm-sdk wheels, if they are installed.

    torch and hip-python always load ROCm from the rocm-sdk wheels when they
    are present, while libcudf.so would otherwise resolve libamdhip64.so.7
    through LD_LIBRARY_PATH or the system loader, typically from /opt/rocm.
    Two ROCm runtimes in one process abort in LLVM ("Option ... registered
    more than once"). Once loaded, the rocm-sdk copy satisfies every later
    lookup of the same soname, whatever LD_LIBRARY_PATH says.
    """
    try:
        import rocm_sdk
    except ImportError:
        return
    try:
        rocm_sdk.initialize_process(preload_shortnames=["amdhip64"])
    except Exception:
        # find_libraries() raises a variety of errors for partial
        # installations; fall back to the system loader in that case.
        pass


def load_library():
    """Dynamically load libcudf.so and its dependencies"""
    # NOTE(HIP/AMD): must run before anything that links libamdhip64.so.7,
    # rapids_logger included.
    _preload_rocm_sdk()

    try:
        from cuda.pathfinder import load_nvidia_dynamic_lib

        load_nvidia_dynamic_lib("nvJitLink")
    except ModuleNotFoundError:
        pass

    try:
        # librmm and libkvikio must be loaded before libcudf because libcudf references
        # them.
        import libkvikio
        import librmm
        import nvidia.libnvcomp
        import rapids_logger

        rapids_logger.load_library()
        librmm.load_library()
        libkvikio.load_library()
        nvidia.libnvcomp.load_library()
    except ModuleNotFoundError:
        # libcudf's runtime dependency on libkvikio may be satisfied by a natively
        # installed library or a conda package, in which case the import will fail and
        # we assume the library is discoverable on system paths.
        pass

    return _load_library("libcudf.so")


def _load_library(soname):
    prefer_system_installation = (
        os.getenv("RAPIDS_LIBCUDF_PREFER_SYSTEM_LIBRARY", "false").lower()
        != "false"
    )

    found_lib = None
    if prefer_system_installation:
        # Prefer a system library if one is present to
        # avoid clobbering symbols that other packages might expect, but if no
        # other library is present use the one in the wheel.
        try:
            found_lib = _load_system_installation(soname)
        except OSError:
            found_lib = _load_wheel_installation(soname)
    else:
        # Prefer the libraries bundled in this package. If they aren't found
        # (which might be the case in builds where the library was prebuilt before
        # packaging the wheel), look for a system installation.
        try:
            found_lib = _load_wheel_installation(soname)
            if found_lib is None:
                found_lib = _load_system_installation(soname)
        except OSError:
            # If none of the searches above succeed, just silently return None
            # and rely on other mechanisms (like RPATHs on other DSOs) to
            # help the loader find the library.
            pass

    # The caller almost never needs to do anything with this library, but no
    # harm in offering the option since this object at least provides a handle
    # to inspect where the library was loaded from.
    return found_lib
