# =============================================================================
# Copyright (c) 2018-2022, NVIDIA CORPORATION.
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

if(GPU_WARNINGS_AS_ERRORS)
  list(APPEND CUDF_GPU_FLAGS -Werror -Wno-c++11-narrowing-const-reference -Wno-deprecated  -Wno-pass-failed -Wno-implicit-conversion-floating-point-to-bool ) #TODO(HIP): WAR for some transformation passes failing in hipcub, might degrade performance (see internal issue #202); accept implicit conversion of math operations to integer types like bool
endif()

if(DISABLE_DEPRECATION_WARNINGS)
  list(APPEND CUDF_CXX_FLAGS -Wno-deprecated-declarations)
  list(APPEND CUDF_GPU_FLAGS -Wno-deprecated-declarations)
endif()

if(GPU_ENABLE_LINEINFO)
  #TODO 
  message(FATAL_ERROR "CUDF does not support line-number information for hip platform")
endif()

if(CMAKE_BUILD_TYPE MATCHES Debug)
  message(VERBOSE "CUDF: Building with debugging flags")
  # NOTE(HIP/AMD): CMake incorrectly sets -O as default debug flag, see https://github.com/Kitware/CMake/commit/b805f55325382ede2e3b4e426e4e837d371b7330
  set(CMAKE_HIP_FLAGS_DEBUG "-Og -g -ggdb")
  # NOTE(HIP/AMD): We use -mcmodel=large here to ensure that all code and data references remain valid, 
  # even if the executable or shared object becomes very large. The default small code model 
  # on x86-64 uses 32-bit relative addressing, which can overflow for large binaries. 
  add_compile_options(-mcmodel=large)
  add_link_options(-mcmodel=large)
  add_link_options(-fuse-ld=lld)

endif()

macro(set_cudf_target_properties)
  set_target_properties(
    cudf
    PROPERTIES BUILD_RPATH "\$ORIGIN"
               INSTALL_RPATH "\$ORIGIN"
               # set target compile options
               CXX_STANDARD 17
               CXX_STANDARD_REQUIRED ON
               # For std:: support of __int128_t. Can be removed once using cuda::std
               CXX_EXTENSIONS ON
               HIP_STANDARD 17
               HIP_STANDARD_REQUIRED ON
               POSITION_INDEPENDENT_CODE ON
               INTERFACE_POSITION_INDEPENDENT_CODE ON
  )
  
  # Export the compiler flags and definitions so the downstream applications can optionally retrieve
  # and use them.
  set_target_properties(
    cudf
    PROPERTIES EXPORT_PROPERTIES
               "CUDF_CXX_FLAGS;CUDF_HIP_FLAGS;CUDF_CXX_DEFINITIONS;CUDF_GPU_DEFINITIONS"
               CUDF_CXX_FLAGS "${CUDF_CXX_FLAGS}"
               CUDF_HIP_FLAGS "${CUDF_GPU_FLAGS}"
               CUDF_CXX_DEFINITIONS "${CUDF_CXX_DEFINITIONS}"
               CUDF_GPU_DEFINITIONS "${CUDF_GPU_DEFINITIONS}"
  )
  
  # Note: This must come before the target_compile_options below so that the function can modify the
  # flags if necessary.
  if(CUDF_CLANG_TIDY OR CUDF_IWYU)
    set(linters)
    if(CUDF_CLANG_TIDY)
      list(APPEND linters CLANG_TIDY)
    endif()
    if(CUDF_IWYU)
      list(APPEND linters IWYU)
    endif()
    enable_static_checkers(
      cudf SKIPPED_FILES src/io/comp/cpu_unbz2.cpp src/io/comp/brotli_dict.cpp ${linters}
    )
  endif()

  target_compile_options(
    cudf PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${CUDF_CXX_FLAGS}>"
                  "$<$<COMPILE_LANGUAGE:HIP>:${CUDF_GPU_FLAGS}>"
  )
  
  if(CUDF_BUILD_STACKTRACE_DEBUG)
    # Remove any optimization level to avoid nvcc warning "incompatible redefinition for option
    # 'optimize'".
    string(REGEX REPLACE "(\-O[0123])" "" CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}")
    string(REGEX REPLACE "(\-O[0123])" "" CMAKE_HIP_FLAGS_RELEASE "${CMAKE_HIP_FLAGS_RELEASE}")
    string(REGEX REPLACE "(\-O[0123])" "" CMAKE_HIP_FLAGS_MINSIZEREL
                         "${CMAKE_HIP_FLAGS_MINSIZEREL}"
    )
    string(REGEX REPLACE "(\-O[0123])" "" CMAKE_HIP_FLAGS_RELWITHDEBINFO
                         "${CMAKE_HIP_FLAGS_RELWITHDEBINFO}"
    )
  
    add_library(cudf_backtrace INTERFACE)
    target_compile_definitions(cudf_backtrace INTERFACE _BUILD_STACKTRACE_DEBUG)
    target_compile_options(
      cudf_backtrace INTERFACE "$<$<COMPILE_LANGUAGE:CXX>:-Og>"
                               "$<$<COMPILE_LANGUAGE:HIP>:-Xcompiler=-Og>"
    )
    target_link_options(
      cudf_backtrace INTERFACE "$<$<LINK_LANGUAGE:CXX>:-rdynamic>"
      "$<$<LINK_LANGUAGE:HIP>:-Xlinker=-rdynamic>"
    )
    target_link_libraries(cudf PRIVATE cudf_backtrace)
  endif()

  target_compile_definitions(
    cudf PUBLIC "$<$<COMPILE_LANGUAGE:CXX>:${CUDF_CXX_DEFINITIONS}>"
                 "$<BUILD_INTERFACE:$<$<COMPILE_LANGUAGE:HIP>:${CUDF_GPU_DEFINITIONS}>>"
  )

  if(GPU_STATIC_RUNTIME)
    #TODO
    message(FATAL_ERROR "CUDF does not support static runtime linking")
  else()
    # Tell CMake what HIP language runtime to use
    set_target_properties(cudf PROPERTIES HIP_RUNTIME_LIBRARY Shared)
    # Make sure to export to consumers what runtime we used
    target_link_libraries(cudf PUBLIC hip::host)
  endif()
endmacro()

macro(set_cudftest_default_stream_target)
  set_target_properties(
    cudftest_default_stream
    PROPERTIES BUILD_RPATH "\$ORIGIN"
               INSTALL_RPATH "\$ORIGIN"
               # set target compile options
               CXX_STANDARD 17
               CXX_STANDARD_REQUIRED ON
               HIP_STANDARD 17
               HIP_STANDARD_REQUIRED ON
               POSITION_INDEPENDENT_CODE ON
               INTERFACE_POSITION_INDEPENDENT_CODE ON
  )
endmacro()

macro(set_cudftestutil_target)
  set_target_properties(
    cudftestutil
    PROPERTIES BUILD_RPATH "\$ORIGIN"
               INSTALL_RPATH "\$ORIGIN"
               # set target compile options
               CXX_STANDARD 17
               CXX_STANDARD_REQUIRED ON
               HIP_STANDARD 17
               HIP_STANDARD_REQUIRED ON
               POSITION_INDEPENDENT_CODE ON
               INTERFACE_POSITION_INDEPENDENT_CODE ON
  )
endmacro()
