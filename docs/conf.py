# Configuration file for the Sphinx documentation builder.
#
# This file only contains a selection of the most common options. For a full
# list see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

from datetime import datetime as _datetime

_today = _datetime.today()

# Rocm-docs-core
external_projects_remote_repository = ""
# TODO extend with AMD Data Science projects
external_projects = [
    "hipDF",
    "hipMM",
    "python", "rocm"
]
external_projects_current_project = "hipDF"

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
version_number = "1.0.0b1"
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
