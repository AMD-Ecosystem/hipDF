/*
 * Copyright (c) 2019-2025, NVIDIA CORPORATION.
 *
 * Copyright 2018-2019 BlazingDB, Inc.
 *     Copyright 2018 Christian Noboa Mardini <christian@blazingdb.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
// MIT License
//
// Modifications Copyright (C) 2023-2026 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <cudf/cuda_runtime.h>

#include "assert_unary.h"

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/column_wrapper.hpp>
#include <cudf_test/random.hpp>
#include <cudf/utilities/jit_amd_utilities.hpp>
#include <cudf_test/type_lists.hpp>

#include <cudf/types.hpp>
#include <cudf/detail/iterator.cuh>
#include <cudf/transform.hpp>

namespace transformation {

struct RuntimeSupportTest : public cudf::test::BaseFixture {
 protected:
  cudf::test::fixed_width_column_wrapper<float> a{1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

  cudf::test::fixed_width_column_wrapper<float> b{
    0.1F, 0.25F, 0.5F, 0.1F, 0.4F, 0.75F, 0.2F, 0.33F, 0.45F, 0.66F};

  cudf::test::fixed_width_column_wrapper<float> b_nulls{
    {0.1F, 0.25F, 0.5F, 0.1F, 0.4F, 0.75F, 0.2F, 0.33F, 0.45F, 0.66F},
    {true, true, true, true, true, true, true, true, true, false}};

  cudf::test::fixed_width_column_wrapper<float> t{0.5f};

  cudf::test::fixed_width_column_wrapper<float> bad_col{1, 2, 3, 4, 5, 6, 7, 8, 9};

  cudf::test::structs_column_wrapper struct_col{a, b};

  static constexpr char const* udf =
    R"***(
    __device__ inline void lerp(float* out, float a, float b, float t) { *out = a - t * a + t * b; }
    )***";
};

struct AssertsTest : public RuntimeSupportTest {};

TEST_F(AssertsTest, TypeSupport)
{
  EXPECT_NO_THROW(cudf::transform({a, b, t},
                                  udf,
                                  cudf::data_type{cudf::type_id::FLOAT32},
                                  false,
                                  std::nullopt,
                                  cudf::null_aware::NO));

  EXPECT_THROW(cudf::transform({a, b, t},
                               udf,
                               cudf::data_type{cudf::type_id::STRUCT},
                               false,
                               std::nullopt,
                               cudf::null_aware::NO),
               std::invalid_argument);

  EXPECT_THROW(cudf::transform({struct_col, t},
                               udf,
                               cudf::data_type{cudf::type_id::FLOAT32},
                               false,
                               std::nullopt,
                               cudf::null_aware::NO),
               std::invalid_argument);
}

TEST_F(AssertsTest, UnequalRowCount)
{
  EXPECT_THROW(cudf::transform({a, b, bad_col},
                               udf,
                               cudf::data_type{cudf::type_id::FLOAT32},
                               false,
                               std::nullopt,
                               cudf::null_aware::NO),
               std::invalid_argument);
}

TEST_F(AssertsTest, NullSupport)
{
  EXPECT_NO_THROW(cudf::transform({a, b_nulls, t},
                                  udf,
                                  cudf::data_type{cudf::type_id::FLOAT32},
                                  false,
                                  std::nullopt,
                                  cudf::null_aware::NO));
}

struct UnaryOperationIntegrationTest : public cudf::test::BaseFixture {};

template <class dtype, class Op, class Data>
void test_udf(char const* udf, Op op, Data data_init, cudf::size_type size, bool is_ptx)
{
  auto all_valid = cudf::detail::make_counting_transform_iterator(0, [](auto i) { return true; });
  auto data_iter = cudf::detail::make_counting_transform_iterator(0, data_init);

  cudf::test::fixed_width_column_wrapper<dtype, typename decltype(data_iter)::value_type> in(
    data_iter, data_iter + size, all_valid);

  std::unique_ptr<cudf::column> out =
    cudf::transform({in}, udf, cudf::data_type(cudf::type_to_id<dtype>()), is_ptx);

  ASSERT_UNARY<dtype, dtype>(out->view(), in, op);
}

TEST_F(UnaryOperationIntegrationTest, Transform_FP32_FP32)
{
  // c = a*a*a*a
  std::string const cuda =
    R"***(
__device__ inline void    fdsf   (
       float* C,
       float a
)
{
  *C = a*a*a*a;
}
)***";

  // c = a*a*a*a
  std::string amd_llvm_ir = 
    R"'''(
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr noundef %0, float noundef %1) #2 {
  %3 = alloca ptr, align 8, addrspace(5)
  %4 = alloca float, align 4, addrspace(5)
  %5 = addrspacecast ptr addrspace(5) %3 to ptr
  %6 = addrspacecast ptr addrspace(5) %4 to ptr
  store ptr %0, ptr %5, align 8, !tbaa !6
  store float %1, ptr %6, align 4, !tbaa !11
  %7 = load float, ptr %6, align 4, !tbaa !11
  %8 = load float, ptr %6, align 4, !tbaa !11
  %9 = fmul contract float %7, %8
  %10 = load float, ptr %6, align 4, !tbaa !11
  %11 = fmul contract float %9, %10
  %12 = load float, ptr %6, align 4, !tbaa !11
  %13 = fmul contract float %11, %12
  %14 = load ptr, ptr %5, align 8, !tbaa !6
  store float %13, ptr %14, align 4, !tbaa !11
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { convergent mustprogress noinline nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4, !4, !4, !4, !4, !4, !4, !4, !4, !4, !4}
!opencl.ocl.version = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5}

!0 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!1 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 8, !"PIC Level", i32 2}
!4 = !{!"AMD clang version 20.0.0git (https://github.com/RadeonOpenCompute/llvm-project roc-7.1.0 25425 1b0eada6b0ee93e2e694c8c146d23fca90bc11c5)"}
!5 = !{i32 2, i32 0}
!6 = !{!7, !7, i64 0}
!7 = !{!"p1 float", !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"float", !9, i64 0}
    )'''";

  std::string const ptx =
    R"***(
//
// Generated by NVIDIA NVVM Compiler
//
// Compiler Build ID: CL-24817639
// Cuda compilation tools, release 10.0, V10.0.130
// Based on LLVM 3.4svn
//

.version 6.3
.target sm_70
.address_size 64

	// .globl	_ZN8__main__7add$241Ef
.common .global .align 8 .u64 _ZN08NumbaEnv8__main__7add$241Ef;
.common .global .align 8 .u64 _ZN08NumbaEnv5numba7targets7numbers14int_power_impl12$3clocals$3e13int_power$242Efx;

.visible .func  (.param .b32 func_retval0) _ZN8__main__7add$241Ef(
	.param .b64 _ZN8__main__7add$241Ef_param_0,
	.param .b32 _ZN8__main__7add$241Ef_param_1
)
{
	.reg .f32 	%f<4>;
	.reg .b32 	%r<2>;
	.reg .b64 	%rd<2>;


	ld.param.u64 	%rd1, [_ZN8__main__7add$241Ef_param_0];
	ld.param.f32 	%f1, [_ZN8__main__7add$241Ef_param_1];
	mul.f32 	%f2, %f1, %f1;
	mul.f32 	%f3, %f2, %f2;
	st.f32 	[%rd1], %f3;
	mov.u32 	%r1, 0;
	st.param.b32	[func_retval0+0], %r1;
	ret;
}
)***";

  using dtype    = float;
  auto op        = [](dtype a) { return a * a * a * a; };
  auto data_init = [](cudf::size_type row) { return row % 3; };

  test_udf<dtype>(cuda.c_str(), op, data_init, 500, false);
  test_udf<dtype>(cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx.c_str(), op, data_init, 500, true);

  test_udf<dtype>(cuda.c_str(), op, data_init, 0, false);
  test_udf<dtype>(cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx.c_str(), op, data_init, 0, true);
}

TEST_F(UnaryOperationIntegrationTest, Transform_INT32_INT32)
{
  // c = a * a - a
  std::string const cuda =
    "__device__ inline void f(int* output,int input){*output = input*input - input;}";

  // c = a * a - a
  std::string amd_llvm_ir = 
    R"'''(
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr noundef %0, i32 noundef %1) #2 {
  %3 = alloca ptr, align 8, addrspace(5)
  %4 = alloca i32, align 4, addrspace(5)
  %5 = addrspacecast ptr addrspace(5) %3 to ptr
  %6 = addrspacecast ptr addrspace(5) %4 to ptr
  store ptr %0, ptr %5, align 8, !tbaa !6
  store i32 %1, ptr %6, align 4, !tbaa !11
  %7 = load i32, ptr %6, align 4, !tbaa !11
  %8 = load i32, ptr %6, align 4, !tbaa !11
  %9 = mul nsw i32 %7, %8
  %10 = load i32, ptr %6, align 4, !tbaa !11
  %11 = sub nsw i32 %9, %10
  %12 = load ptr, ptr %5, align 8, !tbaa !6
  store i32 %11, ptr %12, align 4, !tbaa !11
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { convergent mustprogress noinline nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4, !4, !4, !4, !4, !4, !4, !4, !4, !4, !4}
!opencl.ocl.version = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5}

!0 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!1 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 8, !"PIC Level", i32 2}
!4 = !{!"AMD clang version 20.0.0git (https://github.com/RadeonOpenCompute/llvm-project roc-7.1.0 25425 1b0eada6b0ee93e2e694c8c146d23fca90bc11c5)"}
!5 = !{i32 2, i32 0}
!6 = !{!7, !7, i64 0}
!7 = !{!"p1 int", !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"int", !9, i64 0}
    )'''";

  std::string const ptx =
    R"***(
.func _Z1fPii(
        .param .b64 _Z1fPii_param_0,
        .param .b32 _Z1fPii_param_1
)
{
        .reg .b32       %r<4>;
        .reg .b64       %rd<3>;


        ld.param.u64    %rd1, [_Z1fPii_param_0];
        ld.param.u32    %r1, [_Z1fPii_param_1];
        cvta.to.global.u64      %rd2, %rd1;
        mul.lo.s32      %r2, %r1, %r1;
        sub.s32         %r3, %r2, %r1;
        st.global.u32   [%rd2], %r3;
        ret;
}
)***";

  using dtype    = int;
  auto op        = [](dtype a) { return a * a - a; };
  auto data_init = [](cudf::size_type row) { return row % 78; };

  test_udf<dtype>(cuda.c_str(), op, data_init, 500, false);
  test_udf<dtype>(cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx.c_str(), op, data_init, 500, true);
}

TEST_F(UnaryOperationIntegrationTest, Transform_INT8_INT8)
{
  // Capitalize all the lower case letters
  // Assuming ASCII, the PTX code is compiled from the following CUDA code

  std::string const cuda =
    R"***(
__device__ inline void f(
  signed char* output,
  signed char input
){
	if(input > 96 && input < 123){
  	*output = input - 32;
  }else{
  	*output = input;
  }
}
)***";

  // LLVM IR equivalent to cuda UDF
  std::string amd_llvm_ir = 
    R"'''(
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr noundef %0, i8 noundef signext %1) #2 {
  %3 = alloca ptr, align 8, addrspace(5)
  %4 = alloca i8, align 1, addrspace(5)
  %5 = addrspacecast ptr addrspace(5) %3 to ptr
  %6 = addrspacecast ptr addrspace(5) %4 to ptr
  store ptr %0, ptr %5, align 8, !tbaa !6
  store i8 %1, ptr %6, align 1, !tbaa !11
  %7 = load i8, ptr %6, align 1, !tbaa !11
  %8 = sext i8 %7 to i32
  %9 = icmp sgt i32 %8, 96
  br i1 %9, label %10, label %20

10:                                               ; preds = %2
  %11 = load i8, ptr %6, align 1, !tbaa !11
  %12 = sext i8 %11 to i32
  %13 = icmp slt i32 %12, 123
  br i1 %13, label %14, label %20

14:                                               ; preds = %10
  %15 = load i8, ptr %6, align 1, !tbaa !11
  %16 = sext i8 %15 to i32
  %17 = sub nsw i32 %16, 32
  %18 = trunc i32 %17 to i8
  %19 = load ptr, ptr %5, align 8, !tbaa !6
  store i8 %18, ptr %19, align 1, !tbaa !11
  br label %23

20:                                               ; preds = %10, %2
  %21 = load i8, ptr %6, align 1, !tbaa !11
  %22 = load ptr, ptr %5, align 8, !tbaa !6
  store i8 %21, ptr %22, align 1, !tbaa !11
  br label %23

23:                                               ; preds = %20, %14
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { convergent mustprogress noinline nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4, !4, !4, !4, !4, !4, !4, !4, !4, !4, !4}
!opencl.ocl.version = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5}

!0 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!1 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 8, !"PIC Level", i32 2}
!4 = !{!"AMD clang version 20.0.0git (https://github.com/RadeonOpenCompute/llvm-project roc-7.1.0 25425 1b0eada6b0ee93e2e694c8c146d23fca90bc11c5)"}
!5 = !{i32 2, i32 0}
!6 = !{!7, !7, i64 0}
!7 = !{!"p1 omnipotent char", !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!9, !9, i64 0}
    )'''";

  std::string const ptx =
    R"***(
.func _Z1fPcc(
        .param .b64 _Z1fPcc_param_0,
        .param .b32 _Z1fPcc_param_1
)
{
        .reg .pred      %p<2>;
        .reg .b16       %rs<6>;
        .reg .b32       %r<3>;
        .reg .b64       %rd<3>;


        ld.param.u64    %rd1, [_Z1fPcc_param_0];
        cvta.to.global.u64      %rd2, %rd1;
        ld.param.s8     %rs1, [_Z1fPcc_param_1];
        add.s16         %rs2, %rs1, -97;
        and.b16         %rs3, %rs2, 255;
        setp.lt.u16     %p1, %rs3, 26;
        cvt.u32.u16     %r1, %rs1;
        add.s32         %r2, %r1, 224;
        cvt.u16.u32     %rs4, %r2;
        selp.b16        %rs5, %rs4, %rs1, %p1;
        st.global.u8    [%rd2], %rs5;
        ret;
}
)***";

  using dtype    = int8_t;
  auto op        = [](dtype a) { return std::toupper(a); };
  auto data_init = [](cudf::size_type row) { return 'a' + (row % 26); };

  test_udf<dtype>(cuda.c_str(), op, data_init, 500, false);
  test_udf<dtype>(cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx.c_str(), op, data_init, 500, true);
}

TEST_F(UnaryOperationIntegrationTest, Transform_Datetime)
{
  // Add one day to timestamp in microseconds

  std::string const cuda =
    R"***(
__device__ inline void f(cudf::timestamp_us* output, cudf::timestamp_us input)
{
  using dur = cuda::std::chrono::duration<int32_t, cuda::std::ratio<86400>>;
  *output = static_cast<cudf::timestamp_us>(input + dur{1});
}

)***";

  using dtype = cudf::timestamp_us;
  auto op     = [](dtype a) {
    using dur = cuda::std::chrono::duration<int32_t, cuda::std::ratio<86400>>;
    return static_cast<cudf::timestamp_us>(a + dur{1});
  };
  auto random_eng = cudf::test::UniformRandomGenerator<cudf::timestamp_us::rep>(0, 100000000);
  auto data_init  = [&random_eng](cudf::size_type row) { return random_eng.generate(); };

  test_udf<dtype>(cuda.c_str(), op, data_init, 500, false);
}

struct TernaryOperationTest : public cudf::test::BaseFixture {};

TEST_F(TernaryOperationTest, TransformWithScalar)
{
  std::string const cuda =
    R"***(
__device__ inline void transform(
       float* out,
       float a,
       float b,
       float c
)
{
  *out = (a + b) * c;
}
)***";

  // Generated from NUMBA, using:
  //
  // ```py
  //
  // from numba import cuda, float32
  // from numba.cuda import compile_ptx_for_current_device
  //
  // # Define a CUDA device function
  //
  // @cuda.jit(device=True)
  // def op(a, b, c):
  //         return (a + b) * c
  //
  // # Define argument types for the function
  // arg_types = (float32, float32, float32)
  //
  // # Compile the device function as relocatable
  // ptx, _ = cuda.compile_ptx_for_current_device(op, arg_types, device=True)
  //
  //
  // # Print the PTX code
  // print("Relocatable PTX Code:")
  // print(ptx)
  //
  //
  // ```
  //
  std::string const ptx =
    R"***(
//
// Generated by NVIDIA NVVM Compiler
//
// Compiler Build ID: CL-35404655
// Cuda compilation tools, release 12.8, V12.8.61
// Based on NVVM 7.0.1
//

.version 8.7
.target sm_86
.address_size 64

	// .globl	_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff
.common .global .align 8 .u64 _ZN08NumbaEnv8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff;

.visible .func  (.param .b32 func_retval0) _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff(
	.param .b64 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_0,
	.param .b32 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_1,
	.param .b32 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_2,
	.param .b32 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_3
)
{
	.reg .f32 	%f<6>;
	.reg .b32 	%r<2>;
	.reg .b64 	%rd<2>;


	ld.param.u64 	%rd1, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_0];
	ld.param.f32 	%f1, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_1];
	ld.param.f32 	%f2, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_2];
	ld.param.f32 	%f3, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_3];
	add.f32 	%f4, %f1, %f2;
	mul.f32 	%f5, %f4, %f3;
	st.f32 	[%rd1], %f5;
	mov.u32 	%r1, 0;
	st.param.b32 	[func_retval0+0], %r1;
	ret;

}
)***";

  std::string const amd_llvm_ir = 
    R"***(
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr noundef %0, float noundef %1, float noundef %2, float noundef %3) #2 {
  %5 = alloca ptr, align 8, addrspace(5)
  %6 = alloca float, align 4, addrspace(5)
  %7 = alloca float, align 4, addrspace(5)
  %8 = alloca float, align 4, addrspace(5)
  %9 = addrspacecast ptr addrspace(5) %5 to ptr
  %10 = addrspacecast ptr addrspace(5) %6 to ptr
  %11 = addrspacecast ptr addrspace(5) %7 to ptr
  %12 = addrspacecast ptr addrspace(5) %8 to ptr
  store ptr %0, ptr %9, align 8, !tbaa !6
  store float %1, ptr %10, align 4, !tbaa !11
  store float %2, ptr %11, align 4, !tbaa !11
  store float %3, ptr %12, align 4, !tbaa !11
  %13 = load float, ptr %10, align 4, !tbaa !11
  %14 = load float, ptr %11, align 4, !tbaa !11
  %15 = fadd contract float %13, %14
  %16 = load float, ptr %12, align 4, !tbaa !11
  %17 = fmul contract float %15, %16
  %18 = load ptr, ptr %9, align 8, !tbaa !6
  store float %17, ptr %18, align 4, !tbaa !11
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { convergent mustprogress noinline nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4, !4, !4, !4, !4, !4, !4, !4, !4, !4, !4}
!opencl.ocl.version = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5}

!0 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!1 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 8, !"PIC Level", i32 2}
!4 = !{!"AMD clang version 20.0.0git (https://github.com/RadeonOpenCompute/llvm-project roc-7.1.0 25425 1b0eada6b0ee93e2e694c8c146d23fca90bc11c5)"}
!5 = !{i32 2, i32 0}
!6 = !{!7, !7, i64 0}
!7 = !{!"p1 float", !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"float", !9, i64 0}
)***";

  using T = float;

  constexpr T A   = 90;
  constexpr T B   = 100;
  constexpr T C   = 5;
  constexpr T OUT = (A + B) * C;

  std::vector<T> a_host(200, A);
  std::vector<T> b_host(200, B);
  std::vector<T> c_host(1, C);
  std::vector<T> expected_host(200, OUT);

  cudf::test::fixed_width_column_wrapper<T> a(a_host.begin(), a_host.end());
  cudf::test::fixed_width_column_wrapper<T> b(b_host.begin(), b_host.end());
  cudf::test::fixed_width_column_wrapper<T> c(c_host.begin(), c_host.end());
  cudf::test::fixed_width_column_wrapper<T> expected(expected_host.begin(), expected_host.end());

  std::unique_ptr<cudf::column> cuda_result =
    cudf::transform({a, b, c}, cuda, cudf::data_type(cudf::type_to_id<T>()), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*cuda_result, expected);

  std::unique_ptr<cudf::column> ptx_result =
    cudf::transform({a, b, c}, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx, cudf::data_type(cudf::type_to_id<T>()), true);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*ptx_result, expected);
}

template <typename T>
struct TernaryDecimalOperationTest : public cudf::test::BaseFixture {};

TYPED_TEST_SUITE(TernaryDecimalOperationTest, cudf::test::FixedPointTypes);

TYPED_TEST(TernaryDecimalOperationTest, TransformDecimalsAndScalar)
{
  using T = TypeParam;

  auto type_name = cudf::type_to_name(cudf::data_type(cudf::type_to_id<T>()));

  // clang-format off
  std::string const cuda =
    "__device__ void transform("
    + type_name + "* out, "
    + type_name + " a,"
    + type_name + " b,"
    + type_name + " c) {\n"
    + "*out = ((a + b) * c);"
    + " }";
  // clang-format on

  T const A(10, numeric::scale_type{0});
  T const B(20, numeric::scale_type{-1});
  T const C(5, numeric::scale_type{-2});
  T const RES = ((A + B) * C);

  std::vector<typename T::rep> a_host(200, A.value());
  std::vector<typename T::rep> b_host(200, B.value());
  std::vector<typename T::rep> c_host(1, C.value());
  std::vector<typename T::rep> expected_host(200, RES.value());

  cudf::test::fixed_point_column_wrapper<typename T::rep> a(
    a_host.begin(), a_host.end(), A.scale());
  cudf::test::fixed_point_column_wrapper<typename T::rep> b(
    b_host.begin(), b_host.end(), B.scale());
  cudf::test::fixed_point_column_wrapper<typename T::rep> c(
    c_host.begin(), c_host.end(), C.scale());
  cudf::test::fixed_point_column_wrapper<typename T::rep> expected(
    expected_host.begin(), expected_host.end(), RES.scale());

  std::unique_ptr<cudf::column> cuda_result =
    cudf::transform({a, b, c}, cuda, cudf::data_type(cudf::type_to_id<T>(), RES.scale()), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*cuda_result, expected);
}

struct StringOperationTest : public cudf::test::BaseFixture {};

TEST_F(StringOperationTest, StringComparison)
{
  auto a = cudf::test::strings_column_wrapper{"a", "b", "ccc", "dddd", "eee"};
  auto b = cudf::test::strings_column_wrapper{"a", "b", "d", "dddddd", "e"};
  auto c = cudf::test::strings_column_wrapper{"a", "b", "e", "ddd", "e"};

  std::string cuda = R"***(
  __device__ void compare(bool * out, cudf::string_view a, cudf::string_view b, cudf::string_view c){
    *out = (a == b) || (b == c);
  }
  )***";

  auto expected = cudf::test::fixed_width_column_wrapper<bool>{true, true, false, false, true};
  auto result   = cudf::transform({a, b, c}, cuda, cudf::data_type(cudf::type_id::BOOL8), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected, result->view());
}

TEST_F(StringOperationTest, StringContains)
{
  auto a = cudf::test::strings_column_wrapper{"a", "ab", "ccc", "dddd", "eee", "123"};
  auto b = cudf::test::strings_column_wrapper{"aa", "b", "d", "dddddd", "e", "321"};

  std::string cuda = R"***(
  __device__ void transform(bool * out, cudf::string_view a, cudf::string_view b){
    *out =  a.find(b) != cudf::string_view::npos;
  }
  )***";

  auto expected =
    cudf::test::fixed_width_column_wrapper<bool>{false, true, false, false, true, false};
  auto result = cudf::transform({a, b}, cuda, cudf::data_type(cudf::type_id::BOOL8), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected, result->view());
}

TEST_F(StringOperationTest, StringFind)
{
  auto a = cudf::test::strings_column_wrapper{"a", "b", " h", "123"};
  auto b = cudf::test::strings_column_wrapper{"aa", "about", "oh hi", "012345"};

  std::string cuda = R"***(
  __device__ void transform(int32_t * out, cudf::string_view a, cudf::string_view b){
    *out =  b.find(a);
  }
  )***";

  auto expected = cudf::test::fixed_width_column_wrapper<cudf::size_type>{0, 1, 2, 1};
  auto result   = cudf::transform({a, b}, cuda, cudf::data_type(cudf::type_id::INT32), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected, result->view());
}

TEST_F(StringOperationTest, MixedTypes)
{
  auto a = cudf::test::strings_column_wrapper{"a", "b", "ccc", "dddd", "eee", "123"};
  auto b = cudf::test::strings_column_wrapper{"a", "b", "d", "dddddd", "e", "321"};
  auto c = cudf::test::fixed_width_column_wrapper<int32_t>{1, 2, 3, 4, 5, 6};
  auto d = cudf::test::fixed_width_column_wrapper<int32_t>{1, 2, 5, 6, 7, 8};

  std::string cuda = R"***(
  __device__ void transform(bool * out, cudf::string_view a, cudf::string_view b, int32_t c, int32_t d){
    *out =  (a == b) && (c == d);
  }
  )***";

  auto expected =
    cudf::test::fixed_width_column_wrapper<bool>{true, true, false, false, false, false};
  auto result = cudf::transform({a, b, c, d}, cuda, cudf::data_type(cudf::type_id::BOOL8), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected, result->view());
}

TEST_F(StringOperationTest, Output)
{
  auto a = cudf::test::strings_column_wrapper{"this", "b", "c", "d", "e", "f"};
  auto b = cudf::test::strings_column_wrapper{"aa", "is", "dd", "ddd", "e", "fff"};
  auto c = cudf::test::strings_column_wrapper{"a", "b", "the", "dddd", "e", "fff"};
  auto d = cudf::test::strings_column_wrapper{"a", "b", "d", "largest", "lexicographical", "test"};
  auto empty = cudf::test::strings_column_wrapper{};

  std::string cuda = R"***(
    __device__ void transform(cudf::string_view * out, cudf::string_view a, cudf::string_view b, cudf::string_view c, cudf::string_view d){
      *out =  std::max(std::max(std::max(a, b), c), d);
    }
    )***";

  auto expected =
    cudf::test::strings_column_wrapper{"this", "is", "the", "largest", "lexicographical", "test"};
  auto result = cudf::transform({a, b, c, d}, cuda, cudf::data_type(cudf::type_id::STRING), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected, result->view());

  auto expected_empty = cudf::test::strings_column_wrapper{};
  auto result_empty   = cudf::transform(
    {empty, empty, empty, empty}, cuda, cudf::data_type(cudf::type_id::STRING), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected_empty, result_empty->view());
}

TEST_F(StringOperationTest, StringConcat)
{
  auto first_name = cudf::test::strings_column_wrapper{
    "John", "Mia", "Abd", "Mendes", "Arya", "John", "François", "José", "Søren", "张"};
  auto last_name = cudf::test::strings_column_wrapper{
    "Doe", "Folk", "Louis", "Xi", "Serenity", "Scott", "Ольга", "Łukasz", "Zoë", "伟"};
  rmm::device_buffer scratch(100 * static_cast<cudf::column_view>(first_name).size(),
                             cudf::get_default_stream());
  auto scratch_sizes = cudf::test::fixed_width_column_wrapper<int32_t>{100};

  std::string cuda = R"***(
__device__ void transform(void* user_data, cudf::size_type row,
                          cudf::string_view* out,
                          cudf::string_view first_name,
                          cudf::string_view last_name,
                          int32_t size)
{
  char* it = static_cast<char*>(user_data) + static_cast<size_t>(row) * static_cast<size_t>(size);
  char const* const begin = it;

  memcpy(it, first_name.data(), first_name.size_bytes());
  it += first_name.size_bytes();

  memcpy(it, " ", 1);
  it += 1;

  memcpy(it, last_name.data(), last_name.size_bytes());
  it += last_name.size_bytes();

  *out = cudf::string_view{begin, static_cast<cudf::size_type>(it - begin)};
}
    )***";

  auto expected = cudf::test::strings_column_wrapper{"John Doe",
                                                     "Mia Folk",
                                                     "Abd Louis",
                                                     "Mendes Xi",
                                                     "Arya Serenity",
                                                     "John Scott",
                                                     "François Ольга",
                                                     "José Łukasz",
                                                     "Søren Zoë",
                                                     "张 伟"};
  auto result   = cudf::transform({first_name, last_name, scratch_sizes},
                                cuda,
                                cudf::data_type(cudf::type_id::STRING),
                                false,
                                scratch.data(),
                                cudf::null_aware::NO);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(expected, result->view());
}

struct NullTest : public cudf::test::BaseFixture {
 protected:
  char const* const cuda =
    "__device__ inline void lerp(float* output, float low, float high, float t){*output = low - t "
    "* low + t * high; }";

  // Generated from NUMBA, using:
  //
  // ```py
  //
  // from numba import cuda, float32
  // from numba.cuda import compile_ptx_for_current_device
  //
  // # Define a CUDA device function
  //
  // @cuda.jit(device=True)
  // def op(low, high, t):
  //         return low - t * low + t * high
  //
  // # Define argument types for the function
  // arg_types = (float32, float32, float32)
  //
  // # Compile the device function as relocatable
  // ptx, _ = cuda.compile_ptx_for_current_device(op, arg_types, device=True)
  //
  //
  // # Print the PTX code
  // print("Relocatable PTX Code:")
  // print(ptx)
  //
  //
  // ```
  //
  char const* const ptx =
    R"***(
//
// Generated by NVIDIA NVVM Compiler
//
// Compiler Build ID: CL-35813241
// Cuda compilation tools, release 12.9, V12.9.41
// Based on NVVM 7.0.1
//

.version 8.8
.target sm_86
.address_size 64

// .globl	_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff
.common .global .align 8 .u64 _ZN08NumbaEnv8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff;

.visible .func  (.param .b32 func_retval0) _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff(
.param .b64 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_0,
.param .b32 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_1,
.param .b32 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_2,
.param .b32 _ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_3
)
{
.reg .f32 	%f<7>;
.reg .b32 	%r<2>;
.reg .b64 	%rd<2>;


ld.param.u64 	%rd1, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_0];
ld.param.f32 	%f1, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_1];
ld.param.f32 	%f2, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_2];
ld.param.f32 	%f3, [_ZN8__main__2opB2v1B96cw51cXTLSUwv1sCUt9Ww0FEw09RRQPKiLTj0gIGIFp_2b2oLQFEYYkHSQB1OQAk0Bynm21OizQ1K0UoIGvDpQE8oxrNQE_3dEfff_param_3];
mul.f32 	%f4, %f1, %f3;
sub.f32 	%f5, %f1, %f4;
fma.rn.f32 	%f6, %f2, %f3, %f5;
st.f32 	[%rd1], %f6;
mov.u32 	%r1, 0;
st.param.b32 	[func_retval0+0], %r1;
ret;
}
)***";

  std::string const amd_llvm_ir =  
R"'''(
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr noundef %0, float noundef %1, float noundef %2, float noundef %3) #2 {
  %5 = alloca ptr, align 8, addrspace(5)
  %6 = alloca float, align 4, addrspace(5)
  %7 = alloca float, align 4, addrspace(5)
  %8 = alloca float, align 4, addrspace(5)
  %9 = addrspacecast ptr addrspace(5) %5 to ptr
  %10 = addrspacecast ptr addrspace(5) %6 to ptr
  %11 = addrspacecast ptr addrspace(5) %7 to ptr
  %12 = addrspacecast ptr addrspace(5) %8 to ptr
  store ptr %0, ptr %9, align 8, !tbaa !6
  store float %1, ptr %10, align 4, !tbaa !11
  store float %2, ptr %11, align 4, !tbaa !11
  store float %3, ptr %12, align 4, !tbaa !11
  %13 = load float, ptr %10, align 4, !tbaa !11
  %14 = load float, ptr %12, align 4, !tbaa !11
  %15 = load float, ptr %10, align 4, !tbaa !11
  %16 = fmul contract float %14, %15
  %17 = fsub contract float %13, %16
  %18 = load float, ptr %12, align 4, !tbaa !11
  %19 = load float, ptr %11, align 4, !tbaa !11
  %20 = fmul contract float %18, %19
  %21 = fadd contract float %17, %20
  %22 = load ptr, ptr %9, align 8, !tbaa !6
  store float %21, ptr %22, align 4, !tbaa !11
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { convergent mustprogress noinline nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4, !4, !4, !4, !4, !4, !4, !4, !4, !4, !4}
!opencl.ocl.version = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5}

!0 = !{i32 1, !"amdhsa_code_object_version", i32 600}
!1 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!2 = !{i32 1, !"wchar_size", i32 4}
!3 = !{i32 8, !"PIC Level", i32 2}
!4 = !{!"AMD clang version 20.0.0git (https://github.com/RadeonOpenCompute/llvm-project roc-7.1.0 25425 1b0eada6b0ee93e2e694c8c146d23fca90bc11c5)"}
!5 = !{i32 2, i32 0}
!6 = !{!7, !7, i64 0}
!7 = !{!"p1 float", !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"float", !9, i64 0} 
)'''";

  float const LOW         = 100.0F;
  float const HIGH        = 200.0F;
  float const T           = 0.25F;
  float const RES         = LOW - T * LOW + T * HIGH;
  cudf::size_type const N = 200;

  std::vector<float> low_host      = std::vector<float>(N, LOW);
  std::vector<float> high_host     = std::vector<float>(N, HIGH);
  std::vector<float> t_host        = std::vector<float>(N, T);
  std::vector<float> t_scalar_host = std::vector<float>(1, T);
  std::vector<float> expected_host = std::vector<float>(N, RES);

  auto fourth()
  {
    return cudf::detail::make_counting_transform_iterator(0, [](auto i) { return (i % 4) == 0; });
  }

  auto fifth()
  {
    return cudf::detail::make_counting_transform_iterator(0, [](auto i) { return (i % 5) == 0; });
  }
};

TEST_F(NullTest, ColumnNulls)
{
  auto low =
    cudf::test::fixed_width_column_wrapper<float>(low_host.begin(), low_host.end(), fourth())
      .release();
  auto high =
    cudf::test::fixed_width_column_wrapper<float>(high_host.begin(), high_host.end(), fifth())
      .release();
  auto t = cudf::test::fixed_width_column_wrapper<float>(t_host.begin(), t_host.end()).release();
  auto expected =
    cudf::test::fixed_width_column_wrapper<float>(expected_host.begin(), expected_host.end())
      .release();

  auto [expected_mask, expect_null_count] = cudf::bitmask_and(cudf::table_view({*low, *high}));

  expected->set_null_mask(std::move(expected_mask), expect_null_count);

  auto cuda_result =
    cudf::transform({*low, *high, *t}, cuda, cudf::data_type(cudf::type_id::FLOAT32), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*cuda_result, *expected);

  auto ptx_result =
    cudf::transform({*low, *high, *t}, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx, cudf::data_type(cudf::type_id::FLOAT32), true);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*ptx_result, *expected);
}

TEST_F(NullTest, ColumnNulls_And_Scalar)
{
  auto low =
    cudf::test::fixed_width_column_wrapper<float>(low_host.begin(), low_host.end(), fourth())
      .release();
  auto high =
    cudf::test::fixed_width_column_wrapper<float>(high_host.begin(), high_host.end(), fifth())
      .release();
  auto t_scalar =
    cudf::test::fixed_width_column_wrapper<float>(t_scalar_host.begin(), t_scalar_host.end())
      .release();
  auto expected =
    cudf::test::fixed_width_column_wrapper<float>(expected_host.begin(), expected_host.end())
      .release();

  auto [expected_mask, expect_null_count] = cudf::bitmask_and(cudf::table_view({*low, *high}));

  expected->set_null_mask(std::move(expected_mask), expect_null_count);

  auto cuda_result =
    cudf::transform({*low, *high, *t_scalar}, cuda, cudf::data_type(cudf::type_id::FLOAT32), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*cuda_result, *expected);

  auto ptx_result =
    cudf::transform({*low, *high, *t_scalar}, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx, cudf::data_type(cudf::type_id::FLOAT32), true);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*ptx_result, *expected);
}

TEST_F(NullTest, ColumnNulls_And_ScalarNull)
{
  auto low =
    cudf::test::fixed_width_column_wrapper<float>(low_host.begin(), low_host.end(), fourth())
      .release();
  auto high =
    cudf::test::fixed_width_column_wrapper<float>(high_host.begin(), high_host.end(), fifth())
      .release();
  auto t_scalar = cudf::test::fixed_width_column_wrapper<float>(
                    t_scalar_host.begin(), t_scalar_host.end(), {false})
                    .release();
  auto expected =
    cudf::test::fixed_width_column_wrapper<float>(expected_host.begin(), expected_host.end())
      .release();

  expected->set_null_mask(cudf::create_null_mask(low_host.size(), cudf::mask_state::ALL_NULL),
                          low->size());

  auto cuda_result =
    cudf::transform({*low, *high, *t_scalar}, cuda, cudf::data_type(cudf::type_id::FLOAT32), false);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*cuda_result, *expected);

  auto ptx_result =
    cudf::transform({*low, *high, *t_scalar}, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir.c_str() : ptx, cudf::data_type(cudf::type_id::FLOAT32), true);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*ptx_result, *expected);
}

TEST_F(NullTest, IsNull)
{
  auto udf = R"***(
  __device__ inline void is_null(bool * output, cuda::std::optional<float> input)
  {
    *output = !input.has_value();
  }
  )***";

  auto value = cudf::test::fixed_width_column_wrapper<float>({1.0f, 2.0f, 3.0f, 4.0f, 5.0f},
                                                             {false, false, true, false, true})
                 .release();

  auto expected = cudf::test::fixed_width_column_wrapper<bool>({true, true, false, true, false});

  auto result = cudf::transform({*value},
                                udf,
                                cudf::data_type(cudf::type_id::BOOL8),
                                false,
                                std::nullopt,
                                cudf::null_aware::YES);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*result, expected);
}

TEST_F(NullTest, NullProject)
{
  auto udf = R"***(
__device__ inline void null_lerp(
       float* output,
       cuda::std::optional<float> low,
       cuda::std::optional<float> high,
       cuda::std::optional<float> t
)
{
auto lerp = [] (auto l, auto h, auto t) {
return l - t * l + t * h;
};
  *output =  low.has_value() && high.has_value() && t.has_value()
    ? lerp(*low, *high, *t)
    : 0.0F;
}
)***";

  auto low =
    cudf::test::fixed_width_column_wrapper<float>(low_host.begin(), low_host.end(), fourth())
      .release();
  auto high =
    cudf::test::fixed_width_column_wrapper<float>(high_host.begin(), high_host.end(), fifth())
      .release();
  auto t = cudf::test::fixed_width_column_wrapper<float>(t_host.begin(), t_host.end()).release();

  auto expected_iter = cudf::detail::make_counting_transform_iterator(
    0, [&](auto i) { return ((i % 5) == 0) && ((i % 4) == 0) ? expected_host[i] : 0.0F; });

  auto expected =
    cudf::test::fixed_width_column_wrapper<float>(expected_iter, expected_iter + low_host.size())
      .release();

  auto cuda_result = cudf::transform({*low, *high, *t},
                                     udf,
                                     cudf::data_type(cudf::type_id::FLOAT32),
                                     false,
                                     std::nullopt,
                                     cudf::null_aware::YES);

  CUDF_TEST_EXPECT_COLUMNS_EQUAL(*cuda_result, *expected);
}

}  // namespace transformation
