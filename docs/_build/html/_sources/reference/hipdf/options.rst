..
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

.. _api.options:

====================
Options and settings
====================

.. autosummary::
   :toctree: api/

   hipdf.get_option
   hipdf.set_option
   hipdf.describe_option
   hipdf.option_context

Display options are controlled by pandas
----------------------------------------

Options for display are inherited from pandas. This includes commonly accessed options such as:

- ``display.max_columns``
- ``display.max_info_rows``
- ``display.max_rows``
- ``display.max_seq_items``

For example, to show all rows of a DataFrame or Series in a Jupyter notebook, call ``pandas.set_option("display.max_rows", None)``.

See also the :ref:`full list of pandas display options <pandas:options.available>`.

Available options
-----------------

You can get a list of available options and their descriptions with :func:`~hipdf.describe_option`. When called
with no argument :func:`~hipdf.describe_option` will print out the descriptions for all available options.

.. ipython:: python

   import hipdf
   hipdf.describe_option()
