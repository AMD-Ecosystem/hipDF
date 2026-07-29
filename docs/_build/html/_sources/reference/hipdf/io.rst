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

.. _api.io:

============
Input/output
============
.. currentmodule:: hipdf

CSV
~~~
.. autosummary::
   :toctree: api/

   read_csv
   DataFrame.to_csv

Text
~~~~
.. autosummary::
   :toctree: api/

   read_text

JSON
~~~~
.. autosummary::
   :toctree: api/

   read_json
   DataFrame.to_json

Parquet
~~~~~~~
.. autosummary::
   :toctree: api/

   read_parquet
   DataFrame.to_parquet
   io.parquet.read_parquet_metadata
   io.parquet.ParquetDatasetWriter
   io.parquet.ParquetDatasetWriter.close
   io.parquet.ParquetDatasetWriter.write_table


ORC
~~~
.. autosummary::
   :toctree: api/

   read_orc
   DataFrame.to_orc

HDFStore: PyTables (HDF5)
~~~~~~~~~~~~~~~~~~~~~~~~~
.. autosummary::
   :toctree: api/

   read_hdf
   DataFrame.to_hdf

.. warning::

   HDF reader and writers are not GPU accelerated. These currently use CPU via Pandas.
   This may be GPU accelerated in the future.

Feather
~~~~~~~
.. autosummary::
   :toctree: api/

   read_feather
   DataFrame.to_feather

.. warning::

   Feather reader and writers are not GPU accelerated. These currently use CPU via Pandas.
   This may be GPU accelerated in the future.

Avro
~~~~
.. autosummary::
   :toctree: api/

   read_avro
