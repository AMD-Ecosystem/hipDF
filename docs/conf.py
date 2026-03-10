# MIT License
#
# Copyright (C) 2025-2026 Advanced Micro Devices, Inc. All rights reserved.
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

# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

from datetime import datetime as _datetime

_today = _datetime.today()

# Rocm-docs-core
external_projects_remote_repository = ""
# TODO extend with ROCm-DS projects
external_projects = ["hipdf", "hipmm", "python", "rocm"]
external_projects_current_project = "hipdf"

setting_all_article_info = True
all_article_info_os = ["linux"]
all_article_info_author = ""

# specific settings override any general settings (eg: all_article_info_<field>)
# TODO extend
article_pages = [
    {
        "file": "index",
        "read-time": "1 min read",
    },
]

html_theme = "rocm_docs_theme"
html_theme_options = {"flavor": "rocm-ds"}
html_context = {"docs_header_version": "26.03"}

external_toc_path = "./sphinx/_toc.yml"

extensions = [
    "rocm_docs",
    "breathe",
    "sphinx.ext.intersphinx",
    "sphinx.ext.autodoc",  # Automatically create API documentation from Python docstrings
    "sphinx.ext.autosummary",
    # "numpydoc",
    "sphinx_markdown_tables",
    "sphinx.ext.doctest",
    # "sphinx.ext.linkcode", # TODO requires to specify `def linkcode_resolve` function, more details: linkcode_resolve
    # "IPython.sphinxext.ipython_console_highlighting",
    # "IPython.sphinxext.ipython_directive",
    # "nbsphinx",
    # "recommonmark",
    "sphinx_copybutton",
]


# for PDF output on Read the Docs
version_number = "3.0.0"
project = "hipDF"
author = "Advanced Micro Devices, Inc."
copyright = f"Copyright (c) 2023-{_today.strftime(r'%Y')} Advanced Micro Devices, Inc. All rights reserved."
version = version_number
release = version_number
cpp_maximum_signature_line_length = 10
left_nav_title = f"hipDF {version_number} documentation"

doxygen_root = "../cpp/doxygen"
doxysphinx_enabled = False
doxygen_project = {
    "name": "doxygen",
    "path": "../cpp/doxygen/xml",
}

autodoc_default_options = {
    "members": True,
    "undoc-members": True,
    "special-members": "__init__, __getitem__",
    "inherited-members": True,
    "show-inheritance": True,
    "imported-members": False,
    "member-order": "bysource",  # bysource: seems unfortunately not to work for Cython modules
}
