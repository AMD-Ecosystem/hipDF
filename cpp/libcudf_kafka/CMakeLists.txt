# =============================================================================
# Copyright (c) 2018-2025, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.
# =============================================================================
# MIT License
#
# Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

cmake_minimum_required(VERSION 3.30.4 FATAL_ERROR)

include(../../cmake/rapids_config.cmake)
include(rapids-cmake)
include(rapids-cpm)
#: include(rapids-cuda) 
include(rapids-hip)
include(rapids-export)
include(rapids-find)

project(
  CUDF_KAFKA
  VERSION "${RAPIDS_VERSION}"
  LANGUAGES CXX
)

# Set a default build type if none was specified
rapids_cmake_build_type(Release)

# ##################################################################################################
# * conda environment -----------------------------------------------------------------------------
rapids_cmake_support_conda_env(conda_env MODIFY_PREFIX_PATH)

# ##################################################################################################
# * Build options
option(BUILD_TESTS "Build tests for libcudf_kafka" ON)

message(VERBOSE "CUDF_KAFKA: Build gtests: ${BUILD_TESTS}")

# ##################################################################################################
# * Dependencies

# add third party dependencies using CPM
rapids_cpm_init()
include(cmake/thirdparty/get_cudf.cmake)
include(cmake/thirdparty/get_rdkafka.cmake)

# # GTests if enabled
if(BUILD_TESTS)
  # GoogleTest
  include(../cmake/thirdparty/get_gtest.cmake)

  # include CTest module -- automatically calls enable_testing()
  include(CTest)
  add_subdirectory(tests)
endif()

# ##################################################################################################
# * library target --------------------------------------------------------------------------------
add_library(cudf_kafka SHARED src/kafka_consumer.cpp src/kafka_callback.cpp)

# ##################################################################################################
# * include paths ---------------------------------------------------------------------------------
target_include_directories(
  cudf_kafka PUBLIC "$<BUILD_INTERFACE:${CUDF_KAFKA_SOURCE_DIR}/include>"
                    "$<INSTALL_INTERFACE:include>"
)

# ##################################################################################################
# * library paths ---------------------------------------------------------------------------------
#: target_link_libraries(cudf_kafka PUBLIC cudf::cudf RDKAFKA::RDKAFKA)
target_link_libraries(cudf_kafka PUBLIC cudf::cudf RDKAFKA::RDKAFKA)

# Add Conda library, and include paths if specified
if(TARGET conda_env)
  target_link_libraries(cudf_kafka PRIVATE conda_env)
endif()

set_target_properties(
  cudf_kafka
  PROPERTIES BUILD_RPATH "\$ORIGIN"
             INSTALL_RPATH "\$ORIGIN" # set target compile options
             CXX_STANDARD 17
             CXX_STANDARD_REQUIRED ON
)

add_library(cudf_kafka::cudf_kafka ALIAS cudf_kafka)

# ##################################################################################################
# * cudf_kafka Install ----------------------------------------------------------------------------
rapids_cmake_install_lib_dir(lib_dir)
install(
  TARGETS cudf_kafka
  DESTINATION ${lib_dir}
  EXPORT cudf_kafka-exports
)

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

rapids_export(
  INSTALL cudf_kafka
  EXPORT_SET cudf_kafka-exports
  GLOBAL_TARGETS cudf_kafka
  NAMESPACE cudf_kafka::
)

rapids_export(
  BUILD cudf_kafka
  EXPORT_SET cudf_kafka-exports
  GLOBAL_TARGETS cudf_kafka
  NAMESPACE cudf_kafka::
)
