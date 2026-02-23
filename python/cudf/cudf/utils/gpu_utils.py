# Copyright (c) 2020-2025, NVIDIA CORPORATION.

# MIT License
#
# Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
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


def validate_setup():
    import importlib.metadata
    import os
    import warnings

    # NOTE(HIP/AMD): Check for conflicting installations.
    # Currently, this will only work in some circumstances, e.g.,
    # if hipdf is installed after cudf into the same environment.
    conflicts = ["cudf", "cudf-cu11", "cudf-cu12"]
    conflicts_installed = [
        conflict
        for conflict in conflicts
        if list(importlib.metadata.distributions(name=conflict))
    ]

    conflicts_installed = ", ".join(conflicts_installed)

    if len(conflicts_installed) > 0:
        warnings.warn(
            "The following conflicting packages were detected:\n"
            f"{conflicts_installed}\n"
            "HipDF may not work correctly, please fix your environment\n"
            "by removing the conflicting packages and re-installing hipDF.\n"
        )

    # TODO: Remove the following check once we arrive at a solution for #4827
    # This is a temporary workaround to unblock internal testing
    # related issue: https://github.com/rapidsai/cudf/issues/4827
    if (
        "RAPIDS_NO_INITIALIZE" in os.environ
        or "CUDF_NO_INITIALIZE" in os.environ
    ):
        return

    import warnings

    from cuda.bindings.runtime import (
        cudaDeviceAttr,
        cudaError_t,
    )

    from rmm._cuda.gpu import (
        CUDARuntimeError,
        deviceGetName,
        driverGetVersion,
        getDeviceAttribute,
        getDeviceCount,
        runtimeGetVersion,
    )

    from cudf.errors import UnsupportedCUDAError

    notify_caller_errors = {
        cudaError_t.cudaErrorInitializationError,
        cudaError_t.cudaErrorInvalidDeviceFunction,
        cudaError_t.cudaErrorInvalidDevice,
        #: cudaError_t.cudaErrorStartupFailure, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorInvalidKernelImage,
        cudaError_t.cudaErrorAlreadyAcquired,
        cudaError_t.cudaErrorOperatingSystem,
        #: cudaError_t.cudaErrorNotPermitted, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorNotSupported,
        #: cudaError_t.cudaErrorSystemNotReady, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        #: cudaError_t.cudaErrorSystemDriverMismatch, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        #: cudaError_t.cudaErrorCompatNotSupportedOnDevice, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorDeviceUninitialized,
        #: cudaError_t.cudaErrorTimeout, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorUnknown,
        #: cudaError_t.cudaErrorApiFailureBase, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
    }

    try:
        gpus_count = getDeviceCount()
    except CUDARuntimeError as e:
        if e.status in notify_caller_errors:
            raise e

        # We must distinguish between "CPU only" and "the driver is
        # insufficient for the runtime".
        if e.status == cudaError_t.cudaErrorInsufficientDriver:
            # cudaDriverGetVersion() returns 0 when ``libcuda.so`` is
            # missing. Otherwise there is a CUDA driver but it is
            # insufficient for the runtime, so we re-raise the original
            # exception
            if driverGetVersion() != 0:
                raise e

        # If there is no GPU detected, set `gpus_count` to -1
        gpus_count = -1
    except RuntimeError as e:
        # When using cuda-python < 12.9, getDeviceCount() can raise a
        # RuntimeError if ``libcuda.so`` is missing. We don't want this to
        # propagate up to the user.
        warnings.warn(str(e))
        return

    if gpus_count > 0:
        # Cupy throws RunTimeException to get GPU count,
        # hence obtaining GPU count by in-house cpp api above

        major_version = getDeviceAttribute(
            cudaDeviceAttr.cudaDevAttrComputeCapabilityMajor, 0
        )

        if major_version < 7:
            # A GPU with NVIDIA Volta™ architecture or newer is required.
            # Reference: https://developer.nvidia.com/cuda-gpus
            # Hardware Generation       Compute Capability
            #    Hopper                 9.x
            #    Ampere                 8.x
            #    Turing                 7.5
            #    Volta                  7.0, 7.2
            #    Pascal                 6.x
            #    Maxwell                5.x
            #    Kepler                 3.x
            #    Fermi                  2.x
            device_name = deviceGetName(0)
            minor_version = getDeviceAttribute(
                cudaDeviceAttr.cudaDevAttrComputeCapabilityMinor, 0
            )
            raise UnsupportedCUDAError(
                "A GPU with NVIDIA Volta™ (Compute Capability 7.0) "
                "or newer architecture is required.\n"
                f"Detected GPU 0: {device_name}\n"
                f"Detected Compute Capability: {major_version}.{minor_version}"
            )

        cuda_runtime_version = runtimeGetVersion()

        if cuda_runtime_version < 12000:
            # Require CUDA Runtime version 12.0 or greater.
            major_version = cuda_runtime_version // 1000
            minor_version = (cuda_runtime_version % 1000) // 10
            raise UnsupportedCUDAError(
                "Detected CUDA Runtime version is "
                f"{major_version}.{minor_version}. "
                "Please update your CUDA Runtime to 12.0 or above."
            )

        cuda_driver_supported_rt_version = driverGetVersion()

        # Though Yes, Externally driver version is represented like `418.39`
        # and cuda runtime version like `10.1`. It is not the similar case
        # at cuda api's level. Coming down to APIs they follow a uniform
        # convention of an integer which corresponds to the versioning
        # like (1000 major + 10 minor) for 10.1 Driver version API doesn't
        # actually indicate driver version, it indicates only the latest
        # CUDA version supported by the driver.
        # For reference :
        # https://docs.nvidia.com/deploy/cuda-compatibility/index.html

        if cuda_driver_supported_rt_version == 0:
            raise UnsupportedCUDAError(
                "We couldn't detect the GPU driver properly. Please follow "
                "the installation guide to ensure your driver is properly "
                "installed: "
                "https://docs.nvidia.com/cuda/cuda-installation-guide-linux/"
            )
        elif cuda_driver_supported_rt_version >= cuda_runtime_version:
            # CUDA Driver Version Check:
            # Driver Runtime version is >= Runtime version
            pass
        elif (
            cuda_driver_supported_rt_version >= 12000
            and cuda_runtime_version >= 12000
        ):
            # With cuda enhanced compatibility any code compiled
            # with 12.x version of cuda can now run on any
            # driver >= 525.60.13. 12000 is the minimum cuda
            # version 525.60.13 supports.
            pass
        else:
            raise UnsupportedCUDAError(
                "Please update your NVIDIA GPU Driver to support CUDA "
                "Runtime.\n"
                f"Detected CUDA Runtime version : {cuda_runtime_version}\n"
                "Latest version of CUDA supported by current "
                f"NVIDIA GPU Driver : {cuda_driver_supported_rt_version}"
            )
    else:
        warnings.warn("No NVIDIA GPU detected")


del validate_setup


def validate_setup():
    import importlib.metadata
    import os
    import warnings

    # NOTE(HIP/AMD): Check for conflicting installations.
    # Currently, this will only work in some circumstances, e.g.,
    # if hipdf is installed after cudf into the same environment.
    conflicts = ["cudf", "cudf-cu11", "cudf-cu12"]
    conflicts_installed = [
        conflict
        for conflict in conflicts
        if list(importlib.metadata.distributions(name=conflict))
    ]

    conflicts_installed = ", ".join(conflicts_installed)

    if len(conflicts_installed) > 0:
        warnings.warn(
            "The following conflicting packages were detected:\n"
            f"{conflicts_installed}\n"
            "HipDF may not work correctly, please fix your environment\n"
            "by removing the conflicting packages and re-installing hipDF.\n"
        )

    # TODO: Remove the following check once we arrive at a solution for #4827
    # This is a temporary workaround to unblock internal testing
    # related issue: https://github.com/rapidsai/cudf/issues/4827
    if (
        "RAPIDS_NO_INITIALIZE" in os.environ
        or "CUDF_NO_INITIALIZE" in os.environ
        or "HIPDF_NO_INITIALIZE" in os.environ
    ):
        return

    from cuda.cudart import cudaError_t

    from rmm._cuda.gpu import (
        CUDARuntimeError,
        getDeviceCount,
    )

    notify_caller_errors = {
        cudaError_t.cudaErrorInitializationError,
        cudaError_t.cudaErrorInsufficientDriver,
        cudaError_t.cudaErrorInvalidDeviceFunction,
        cudaError_t.cudaErrorInvalidDevice,
        #: cudaError_t.cudaErrorStartupFailure, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorInvalidKernelImage,
        cudaError_t.cudaErrorAlreadyAcquired,
        cudaError_t.cudaErrorOperatingSystem,
        #: cudaError_t.cudaErrorNotPermitted, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorNotSupported,
        #: cudaError_t.cudaErrorSystemNotReady, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        #: cudaError_t.cudaErrorSystemDriverMismatch, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        #: cudaError_t.cudaErrorCompatNotSupportedOnDevice, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorDeviceUninitialized,
        #: cudaError_t.cudaErrorTimeout, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
        cudaError_t.cudaErrorUnknown,
        #: cudaError_t.cudaErrorApiFailureBase, #: TODO: HIP/AMD: not supported in HIP, enum hallucination fails for some reason
    }

    try:
        gpus_count = getDeviceCount()
    except CUDARuntimeError as e:
        if e.status in notify_caller_errors:
            raise e
        # If there is no GPU detected, set `gpus_count` to -1
        gpus_count = -1
    except RuntimeError as e:
        # getDeviceCount() can raise a RuntimeError
        # when ``libcuda.so`` is missing.
        # We don't want this to propagate up to the user.
        warnings.warn(str(e))
        return

    if gpus_count > 0:
        return
    else:
        warnings.warn("No AMD GPU detected")
