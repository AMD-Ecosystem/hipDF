# SPDX-FileCopyrightText: Copyright (c) 2023-2025, NVIDIA CORPORATION.
# SPDX-License-Identifier: Apache-2.0

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

from __future__ import annotations

import glob
import os
import pickle
from typing import TYPE_CHECKING, BinaryIO

import _pytest
import _pytest.config
import _pytest.nodes
import pytest

if TYPE_CHECKING:
    import _pytest.python

# NOTE(HIP/AMD): On the ROCm port, torch ships its own bundled ROCm stack including
# librocm_smi64, whose static ROCm-SMI map is double-freed by a C++ static destructor
# at process teardown when torch coexists with the system ROCm stack driven by
# rmm/cudf (a ROCm-SMI teardown bug -- reproducible with a bare `import rmm; import
# torch; <gpu op>`, and unrelated to libcudf/libhipcxx which are not even loaded).
# All tests have already run and reported by the time the destructors fire, so the
# abort (SIGABRT / "double free or corruption", exit 134) is a spurious teardown
# artifact. Bypass the buggy destructors by hard-exiting with the real pytest status
# during interpreter shutdown. Guarded to the HIP/AMD port only.
import atexit as _atexit

from _pytest.stash import StashKey

import cudf as _cudf
from cudf.pandas.module_accelerator import disable_module_accelerator
from cudf.testing._rocm_smi import exit_if_rocm_smi_loaded, stash_exitstatus

if getattr(_cudf, "__is_hip_amd_port__", False):
    _hipdf_exit_status = {"code": 0}

    def pytest_sessionfinish(session, exitstatus):
        _hipdf_exit_status["code"] = int(exitstatus)

    @_atexit.register
    def _hipdf_hard_exit():
        import sys as _sys

        try:
            _sys.stdout.flush()
            _sys.stderr.flush()
        finally:
            os._exit(_hipdf_exit_status["code"])


file_handle_key = StashKey[BinaryIO]()
basename_key = StashKey[str]()
test_folder_key = StashKey[str]()
results = StashKey[tuple[dict, dict]]()


def pytest_addoption(parser):
    parser.addoption(
        "--compare",
        action="store_true",
        default=False,
        help="Run comparison step?",
    )


def read_results(f):
    while True:
        try:
            yield pickle.load(f)
        except EOFError:
            return


def pytest_collection_modifyitems(
    session, config: _pytest.config.Config, items: list[_pytest.nodes.Item]
):
    if config.getoption("--compare"):
        current_pass = "compare"
    elif "cudf.pandas" in config.option.plugins:
        current_pass = "cudf_pandas"
    else:
        current_pass = "gold"

    def swap_xfail(item: _pytest.nodes.Item, name: str):
        """Replace custom `xfail_**` mark with a `xfail` mark having the same kwargs."""

        old_mark = item.keywords[name]
        new_mark = pytest.mark.xfail(**old_mark.kwargs)

        # Replace all "xfail_**" mark in the node chain with the "xfail" mark
        # if not found, the node chain is not modified.
        for node, mark in item.iter_markers_with_node(name):
            idx = node.own_markers.index(mark)
            node.own_markers[idx] = new_mark

    for item in items:
        if current_pass == "gold" and "xfail_gold" in item.keywords:
            swap_xfail(item, "xfail_gold")
        elif (
            current_pass == "cudf_pandas"
            and "xfail_cudf_pandas" in item.keywords
        ):
            swap_xfail(item, "xfail_cudf_pandas")
        elif current_pass == "compare" and "xfail_compare" in item.keywords:
            swap_xfail(item, "xfail_compare")


def get_full_nodeid(pyfuncitem):
    # Get the full path to the test file
    filepath = pyfuncitem.path
    # Get the test name and any parameters
    test_name = "::".join(pyfuncitem.nodeid.split("::")[1:])
    # Combine the full file path with the test name
    full_nodeid = f"{filepath}::{test_name}"
    return full_nodeid


def read_all_results(pattern):
    results = {}
    for filepath in glob.glob(pattern):
        with open(filepath, "rb") as f:
            results.update(dict(read_results(f)))
    return results


def pytest_configure(config: _pytest.config.Config):
    # Register custom markers to avoid PytestUnknownMarkWarning
    config.addinivalue_line(
        "markers",
        "assert_eq(fn): custom assertion function for comparing results",
    )
    config.addinivalue_line(
        "markers",
        "xfail_gold: mark test as expected to fail in gold (pandas) pass",
    )
    config.addinivalue_line(
        "markers",
        "xfail_cudf_pandas: mark test as expected to fail in cudf.pandas pass",
    )
    config.addinivalue_line(
        "markers",
        "xfail_compare: mark test as expected to fail in compare pass",
    )

    gold_basename = "results-gold"
    cudf_basename = "results-cudf-pandas"
    test_folder = os.path.join(os.path.dirname(__file__))

    if config.getoption("--compare"):
        gold_path = os.path.join(test_folder, f"{gold_basename}*.pickle")
        cudf_path = os.path.join(test_folder, f"{cudf_basename}*.pickle")
        with disable_module_accelerator():
            gold_results = read_all_results(gold_path)
        cudf_results = read_all_results(cudf_path)
        config.stash[results] = (gold_results, cudf_results)
    else:
        if any(
            plugin.strip() == "cudf.pandas" for plugin in config.option.plugins
        ):
            basename = cudf_basename
        else:
            basename = gold_basename

        if hasattr(config, "workerinput"):
            # If we're on an xdist worker, open a worker-unique pickle file.
            worker = config.workerinput["workerid"]
            filename = f"{basename}-{worker}.pickle"
        else:
            filename = f"{basename}.pickle"

        pickle_path = os.path.join(test_folder, filename)
        config.stash[file_handle_key] = open(pickle_path, "wb")
        config.stash[test_folder_key] = test_folder
        config.stash[basename_key] = basename


def pytest_pyfunc_call(pyfuncitem: _pytest.python.Function):
    if pyfuncitem.config.getoption("--compare"):
        gold_results, cudf_results = pyfuncitem.config.stash[results]
        key = get_full_nodeid(pyfuncitem)
        try:
            gold = gold_results[key]
        except KeyError:
            assert False, "pickled gold result is not available"
        try:
            cudf = cudf_results[key]
        except KeyError:
            assert False, "pickled cudf result is not available"
        if gold is None and cudf is None:
            raise ValueError(f"Integration test {key} did not return a value")
        asserter = pyfuncitem.get_closest_marker("assert_eq")
        if asserter is None:
            assert gold == cudf, "Test failed"
        else:
            asserter.kwargs["fn"](gold, cudf)
    else:
        # Replace default call of test function with one that captures the
        # result
        testfunction = pyfuncitem.obj
        funcargs = pyfuncitem.funcargs
        testargs = {
            arg: funcargs[arg] for arg in pyfuncitem._fixtureinfo.argnames
        }
        result = testfunction(**testargs)
        # Tuple-based key-value pairs, key is the node-id
        try:
            pickle.dump(
                (get_full_nodeid(pyfuncitem), result),
                pyfuncitem.config.stash[file_handle_key],
            )
        except pickle.PicklingError:
            pass
    return True


def pytest_sessionfinish(session, exitstatus):
    # Stash the exit status so it can be propagated by pytest_unconfigure when
    # we need to short-circuit interpreter shutdown (see cudf.testing._rocm_smi).
    stash_exitstatus(session, exitstatus)


def pytest_unconfigure(config):
    try:
        _close_result_files(config)
    finally:
        # WAR(HIP/AMD): avoid the ROCm SMI teardown double-free abort. Must run
        # last, after the result files above are closed/merged, because it may
        # short-circuit interpreter shutdown via os._exit. See
        # cudf.testing._rocm_smi and issue #442.
        exit_if_rocm_smi_loaded(config)


def _close_result_files(config):
    if config.getoption("--compare"):
        return
    if file_handle_key not in config.stash:
        # We didn't open a pickle file
        return
    if not hasattr(config, "workerinput"):
        # If we're the controlling process
        if (
            hasattr(config.option, "numprocesses")
            and config.option.numprocesses is not None
        ):
            # Concat the worker partial pickle results and remove them
            for i in range(config.option.numprocesses):
                worker_result = os.path.join(
                    config.stash[test_folder_key],
                    f"{config.stash[basename_key]}-gw{i}.pickle",
                )
                with open(worker_result, "rb") as f:
                    config.stash[file_handle_key].write(f.read())
                os.remove(worker_result)
    # Close our file
    config.stash[file_handle_key].close()
    del config.stash[file_handle_key]
