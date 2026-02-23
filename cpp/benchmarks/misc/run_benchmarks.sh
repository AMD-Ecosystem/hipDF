#!/usr/bin/env bash

# MIT License
#
# Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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
# =============================================================================

device_id=7

export HIP_VISIBLE_DEVICES=${device_id}
output_directory=results_gbench_$(date +"%Y-%m-%d")

mkdir ${output_directory}

for b in *_BENCH;
do
        ./${b} --benchmark_out_format=csv --benchmark_out=${output_directory}/${b}.csv >> ${output_directory}.log
done
#nvbench has special argument to set the device id
unset HIP_VISIBLE_DEVICES


output_directory=results_nvbench_$(date +"%Y-%m-%d")

mkdir ${output_directory}

for b in *_NVBENCH;
do
        ./${b} -d ${device_id} --csv ${output_directory}/${b}.csv >> ${output_directory}.log
done
