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
// Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
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

#include <tests/binaryop/assert-binops.h>
#include <tests/binaryop/binop-fixture.hpp>

#include <cudf/utilities/jit_amd_utilities.hpp>

#include <cudf/types.hpp>
#include <cudf/binaryop.hpp>

struct BinaryOperationGenericPTXTest : public BinaryOperationTest {};

TEST_F(BinaryOperationGenericPTXTest, CAdd_Vector_Vector_FP32_FP32_FP32)
{
  // c = a*a*a + b 
  std::string amd_llvm_ir_str = 
    R"'''(
; Function Attrs: convergent mustprogress noreturn nounwind
define weak void @__cxa_pure_virtual() #0 {
  call void @llvm.trap()
  unreachable
}

; Function Attrs: cold noreturn nounwind
declare void @llvm.trap() #1

; Function Attrs: convergent mustprogress noreturn nounwind
define weak void @__cxa_deleted_virtual() #0 {
  call void @llvm.trap()
  unreachable
}

; Function Attrs: convergent mustprogress nounwind
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr %0, float %1, float %2) #2 {
  %4 = alloca ptr, align 8, addrspace(5)
  %5 = alloca float, align 4, addrspace(5)
  %6 = alloca float, align 4, addrspace(5)
  %7 = addrspacecast ptr addrspace(5) %4 to ptr
  %8 = addrspacecast ptr addrspace(5) %5 to ptr
  %9 = addrspacecast ptr addrspace(5) %6 to ptr
  store ptr %0, ptr %7, align 8, !tbaa !7
  store float %1, ptr %8, align 4, !tbaa !11
  store float %2, ptr %9, align 4, !tbaa !11
  %10 = load float, ptr %8, align 4, !tbaa !11
  %11 = load float, ptr %8, align 4, !tbaa !11
  %12 = fmul contract float %10, %11
  %13 = load float, ptr %8, align 4, !tbaa !11
  %14 = fmul contract float %12, %13
  %15 = load float, ptr %9, align 4, !tbaa !11
  %16 = fadd contract float %14, %15
  %17 = load ptr, ptr %7, align 8, !tbaa !7
  store float %16, ptr %17, align 4, !tbaa !11
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind }
attributes #2 = { convergent mustprogress nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5, !5}
!opencl.ocl.version = !{!6, !6, !6, !6, !6, !6, !6, !6, !6, !6}

!0 = !{i32 4, !"amdgpu_hostcall", i32 1}
!1 = !{i32 1, !"amdgpu_code_object_version", i32 600}
!2 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{i32 8, !"PIC Level", i32 2}
!5 = !{!"AMD clang version 17.0.0 (https://github.com/RadeonOpenCompute/llvm-project roc-6.0.0 23483 7208e8d15fbf218deb74483ea8c549c67ca4985e)"}
!6 = !{i32 2, i32 0}
!7 = !{!8, !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"float", !9, i64 0}
	)'''";

  char const* amd_llvm_ir = amd_llvm_ir_str.c_str();

  // c = a*a*a + b
  char const* ptx =
    R"***(
//
// Generated by NVIDIA NVVM Compiler
//
// Compiler Build ID: CL-26218862
// Cuda compilation tools, release 10.1, V10.1.168
// Based on LLVM 3.4svn
//

.version 6.4
.target sm_70
.address_size 64

	// .globl	_ZN8__main__7add$241Eff
.common .global .align 8 .u64 _ZN08NumbaEnv8__main__7add$241Eff;
.common .global .align 8 .u64 _ZN08NumbaEnv5numba7targets7numbers13int_power$242Efx;

.visible .func  (.param .b32 func_retval0) _ZN8__main__7add$241Eff(
	.param .b64 _ZN8__main__7add$241Eff_param_0,
	.param .b32 _ZN8__main__7add$241Eff_param_1,
	.param .b32 _ZN8__main__7add$241Eff_param_2
)
{
	.reg .f32 	%f<5>;
	.reg .b32 	%r<2>;
	.reg .b64 	%rd<2>;


	ld.param.u64 	%rd1, [_ZN8__main__7add$241Eff_param_0];
	ld.param.f32 	%f1, [_ZN8__main__7add$241Eff_param_1];
	ld.param.f32 	%f2, [_ZN8__main__7add$241Eff_param_2];
	mul.f32 	%f3, %f1, %f1;
	fma.rn.f32 	%f4, %f3, %f1, %f2;
	st.f32 	[%rd1], %f4;
	mov.u32 	%r1, 0;
	st.param.b32	[func_retval0+0], %r1;
	ret;
}
)***";

  using TypeOut = float;
  using TypeLhs = float;
  using TypeRhs = float;

  auto CADD = [](TypeLhs a, TypeRhs b) { return a * a * a + b; };

  auto lhs = make_random_wrapped_column<TypeLhs>(500);
  auto rhs = make_random_wrapped_column<TypeRhs>(500);

  auto out = cudf::binary_operation(lhs, rhs, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir : ptx, cudf::data_type(cudf::type_to_id<TypeOut>()));

  // pow has a max ULP error of 2 per CUDA programming guide
  ASSERT_BINOP<TypeOut, TypeLhs, TypeRhs>(*out, lhs, rhs, CADD, NearEqualComparator<TypeOut>{2});
}

TEST_F(BinaryOperationGenericPTXTest, CAdd_Vector_Vector_INT64_INT32_INT32)
{
  // c = a*a*a + b 
  std::string amd_llvm_ir_str = 
    R"'''(
; Function Attrs: cold noreturn nounwind
declare void @llvm.trap() #1

; Function Attrs: convergent mustprogress noreturn nounwind
define weak void @__cxa_deleted_virtual() #0 {
  call void @llvm.trap()
  unreachable
}

; Function Attrs: convergent mustprogress nounwind
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr %0, i32 %1, i32 %2) #2 {
  %4 = alloca ptr, align 8, addrspace(5)
  %5 = alloca i32, align 4, addrspace(5)
  %6 = alloca i32, align 4, addrspace(5)
  %7 = addrspacecast ptr addrspace(5) %4 to ptr
  %8 = addrspacecast ptr addrspace(5) %5 to ptr
  %9 = addrspacecast ptr addrspace(5) %6 to ptr
  store ptr %0, ptr %7, align 8, !tbaa !7
  store i32 %1, ptr %8, align 4, !tbaa !11
  store i32 %2, ptr %9, align 4, !tbaa !11
  %10 = load i32, ptr %8, align 4, !tbaa !11
  %11 = load i32, ptr %8, align 4, !tbaa !11
  %12 = mul nsw i32 %10, %11
  %13 = load i32, ptr %8, align 4, !tbaa !11
  %14 = mul nsw i32 %12, %13
  %15 = load i32, ptr %9, align 4, !tbaa !11
  %16 = add nsw i32 %14, %15
  %17 = sext i32 %16 to i64
  %18 = load ptr, ptr %7, align 8, !tbaa !7
  store i64 %17, ptr %18, align 8, !tbaa !13
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind }
attributes #2 = { convergent mustprogress nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5, !5}
!opencl.ocl.version = !{!6, !6, !6, !6, !6, !6, !6, !6, !6, !6}

!0 = !{i32 4, !"amdgpu_hostcall", i32 1}
!1 = !{i32 1, !"amdgpu_code_object_version", i32 600}
!2 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{i32 8, !"PIC Level", i32 2}
!5 = !{!"AMD clang version 17.0.0 (https://github.com/RadeonOpenCompute/llvm-project roc-6.0.0 23483 7208e8d15fbf218deb74483ea8c549c67ca4985e)"}
!6 = !{i32 2, i32 0}
!7 = !{!8, !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"int", !9, i64 0}
!13 = !{!14, !14, i64 0}
!14 = !{!"long", !9, i64 0}
    )'''";

  char const* amd_llvm_ir = amd_llvm_ir_str.c_str();

  // c = a*a*a + b
  char const* ptx =
    R"***(
//
// Generated by NVIDIA NVVM Compiler
//
// Compiler Build ID: CL-26218862
// Cuda compilation tools, release 10.1, V10.1.168
// Based on LLVM 3.4svn
//

.version 6.4
.target sm_70
.address_size 64

	// .globl	_ZN8__main__7add$241Eii
.common .global .align 8 .u64 _ZN08NumbaEnv8__main__7add$241Eii;
.common .global .align 8 .u64 _ZN08NumbaEnv5numba7targets7numbers14int_power_impl12$3clocals$3e13int_power$242Exx;

.visible .func  (.param .b32 func_retval0) _ZN8__main__7add$241Eii(
	.param .b64 _ZN8__main__7add$241Eii_param_0,
	.param .b32 _ZN8__main__7add$241Eii_param_1,
	.param .b32 _ZN8__main__7add$241Eii_param_2
)
{
	.reg .b32 	%r<3>;
	.reg .b64 	%rd<7>;


	ld.param.u64 	%rd1, [_ZN8__main__7add$241Eii_param_0];
	ld.param.u32 	%r1, [_ZN8__main__7add$241Eii_param_1];
	cvt.s64.s32	%rd2, %r1;
	mul.wide.s32 	%rd3, %r1, %r1;
	mul.lo.s64 	%rd4, %rd3, %rd2;
	ld.param.s32 	%rd5, [_ZN8__main__7add$241Eii_param_2];
	add.s64 	%rd6, %rd4, %rd5;
	st.u64 	[%rd1], %rd6;
	mov.u32 	%r2, 0;
	st.param.b32	[func_retval0+0], %r2;
	ret;
}
)***";

  using TypeOut = int64_t;
  using TypeLhs = int32_t;
  using TypeRhs = int32_t;

  auto CADD = [](TypeLhs a, TypeRhs b) { return a * a * a + b; };

  auto lhs = make_random_wrapped_column<TypeLhs>(500);
  auto rhs = make_random_wrapped_column<TypeRhs>(500);

  auto out = cudf::binary_operation(lhs, rhs, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir : ptx, cudf::data_type(cudf::type_to_id<TypeOut>()));

  ASSERT_BINOP<TypeOut, TypeLhs, TypeRhs>(*out, lhs, rhs, CADD);
}

TEST_F(BinaryOperationGenericPTXTest, CAdd_Vector_Vector_INT64_INT32_INT64)
{
  // c = a*a*a + b*b
  std::string amd_llvm_ir_str = 
    R"'''(
; Function Attrs: convergent mustprogress noreturn nounwind
define weak void @__cxa_pure_virtual() #0 {
  call void @llvm.trap()
  unreachable
}

; Function Attrs: cold noreturn nounwind
declare void @llvm.trap() #1

; Function Attrs: convergent mustprogress noreturn nounwind
define weak void @__cxa_deleted_virtual() #0 {
  call void @llvm.trap()
  unreachable
}

; Function Attrs: convergent mustprogress nounwind
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr %0, i32 %1, i64 %2) #2 {
  %4 = alloca ptr, align 8, addrspace(5)
  %5 = alloca i32, align 4, addrspace(5)
  %6 = alloca i64, align 8, addrspace(5)
  %7 = addrspacecast ptr addrspace(5) %4 to ptr
  %8 = addrspacecast ptr addrspace(5) %5 to ptr
  %9 = addrspacecast ptr addrspace(5) %6 to ptr
  store ptr %0, ptr %7, align 8, !tbaa !7
  store i32 %1, ptr %8, align 4, !tbaa !11
  store i64 %2, ptr %9, align 8, !tbaa !13
  %10 = load i32, ptr %8, align 4, !tbaa !11
  %11 = load i32, ptr %8, align 4, !tbaa !11
  %12 = mul nsw i32 %10, %11
  %13 = load i32, ptr %8, align 4, !tbaa !11
  %14 = mul nsw i32 %12, %13
  %15 = sext i32 %14 to i64
  %16 = load i64, ptr %9, align 8, !tbaa !13
  %17 = load i64, ptr %9, align 8, !tbaa !13
  %18 = mul nsw i64 %16, %17
  %19 = add nsw i64 %15, %18
  %20 = load ptr, ptr %7, align 8, !tbaa !7
  store i64 %19, ptr %20, align 8, !tbaa !13
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }
attributes #1 = { cold noreturn nounwind }
attributes #2 = { convergent mustprogress nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5, !5, !5, !5, !5, !5, !5, !5, !5, !5, !5}
!opencl.ocl.version = !{!6, !6, !6, !6, !6, !6, !6, !6, !6, !6}

!0 = !{i32 4, !"amdgpu_hostcall", i32 1}
!1 = !{i32 1, !"amdgpu_code_object_version", i32 600}
!2 = !{i32 1, !"amdgpu_printf_kind", !"hostcall"}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{i32 8, !"PIC Level", i32 2}
!5 = !{!"AMD clang version 17.0.0 (https://github.com/RadeonOpenCompute/llvm-project roc-6.0.0 23483 7208e8d15fbf218deb74483ea8c549c67ca4985e)"}
!6 = !{i32 2, i32 0}
!7 = !{!8, !8, i64 0}
!8 = !{!"any pointer", !9, i64 0}
!9 = !{!"omnipotent char", !10, i64 0}
!10 = !{!"Simple C++ TBAA"}
!11 = !{!12, !12, i64 0}
!12 = !{!"int", !9, i64 0}
!13 = !{!14, !14, i64 0}
!14 = !{!"long", !9, i64 0}
	)'''";

  char const* amd_llvm_ir = amd_llvm_ir_str.c_str();

  // c = a*a*a + b*b
  char const* ptx =
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

	// .globl	_ZN8__main__7add$241Eix
.common .global .align 8 .u64 _ZN08NumbaEnv8__main__7add$241Eix;
.common .global .align 8 .u64 _ZN08NumbaEnv5numba7targets7numbers14int_power_impl12$3clocals$3e13int_power$242Exx;

.visible .func  (.param .b32 func_retval0) _ZN8__main__7add$241Eix(
	.param .b64 _ZN8__main__7add$241Eix_param_0,
	.param .b32 _ZN8__main__7add$241Eix_param_1,
	.param .b64 _ZN8__main__7add$241Eix_param_2
)
{
	.reg .b32 	%r<3>;
	.reg .b64 	%rd<8>;


	ld.param.u64 	%rd1, [_ZN8__main__7add$241Eix_param_0];
	ld.param.u32 	%r1, [_ZN8__main__7add$241Eix_param_1];
	ld.param.u64 	%rd2, [_ZN8__main__7add$241Eix_param_2];
	cvt.s64.s32	%rd3, %r1;
	mul.wide.s32 	%rd4, %r1, %r1;
	mul.lo.s64 	%rd5, %rd4, %rd3;
	mul.lo.s64 	%rd6, %rd2, %rd2;
	add.s64 	%rd7, %rd6, %rd5;
	st.u64 	[%rd1], %rd7;
	mov.u32 	%r2, 0;
	st.param.b32	[func_retval0+0], %r2;
	ret;
}

)***";

  using TypeOut = int64_t;
  using TypeLhs = int32_t;
  using TypeRhs = int64_t;

  auto CADD = [](TypeLhs a, TypeRhs b) { return a * a * a + b * b; };

  auto lhs = make_random_wrapped_column<TypeLhs>(500);
  auto rhs = make_random_wrapped_column<TypeRhs>(500);

  auto out = cudf::binary_operation(lhs, rhs, cudf::HIP_PLATFORM_AMD ? amd_llvm_ir : ptx, cudf::data_type(cudf::type_to_id<TypeOut>()));

  ASSERT_BINOP<TypeOut, TypeLhs, TypeRhs>(*out, lhs, rhs, CADD);
}
