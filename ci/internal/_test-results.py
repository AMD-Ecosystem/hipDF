#!/usr/bin/env python3
# MIT License
#
# Copyright (c) 2026 Advanced Micro Devices, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""Rewrite and merge the per-file pytest-csv reports written by run_tests.

Failure messages span several lines inside quoted fields, so these files
must be handled with a CSV parser rather than line by line.

  _test-results.py suffix-ids <csv_file> <suffix>
      Append <suffix> to the id of every row of <csv_file>, in place.

  _test-results.py merge <csv_output_dir>
      Write every report under <csv_output_dir> to stdout as one CSV,
      without the attempts of flaky tests that a rerun superseded.
      Exit 1 if any test ended in error or failed.
"""

import csv
import sys
from pathlib import Path

FAILURE_STATUSES = {"error", "failed"}

# A failure message can hold a whole DataFrame diff, well past the csv
# module's default field limit of 128 KiB.
csv.field_size_limit(sys.maxsize)


def read_report(path):
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        return header, list(reader)


def suffix_ids(csv_file, suffix):
    header, rows = read_report(csv_file)
    if header is None:
        return 0
    id_col = header.index("id")
    for row in rows:
        row[id_col] += suffix
    with open(csv_file, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    return 0


def status(row, status_col):
    # A row too short to have a status can only come from a corrupted report.
    return row[status_col] if len(row) > status_col else "error"


def final_attempts(rows, id_col, status_col):
    """Drop the rows of attempts that pytest-rerunfailures superseded.

    pytest-csv builds a row before the plugin relabels an attempt as a
    rerun, so a flaky test that passes on its second try leaves a failed row
    and then a passed one. One attempt can also leave two rows, a call and a
    failed teardown. An attempt that passed leaves only its call row, so a
    test whose last row passed is the one case where every earlier row
    belongs to an attempt that was rerun.
    """
    last_row = {row[id_col]: row for row in rows}
    return [
        row
        for row in rows
        if row is last_row[row[id_col]]
        or status(last_row[row[id_col]], status_col) != "passed"
    ]


def merge(csv_output_dir):
    writer = csv.writer(sys.stdout)
    header_written = False
    failed = False
    for path in sorted(Path(csv_output_dir).rglob("*.csv")):
        header, rows = read_report(path)
        if header is None:
            continue
        if not header_written:
            writer.writerow(header)
            header_written = True
        id_col, status_col = header.index("id"), header.index("status")
        for row in final_attempts(rows, id_col, status_col):
            writer.writerow(row)
            if status(row, status_col) in FAILURE_STATUSES:
                failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    commands = {"suffix-ids": suffix_ids, "merge": merge}
    command, *args = sys.argv[1:]
    sys.exit(commands[command](*args))
