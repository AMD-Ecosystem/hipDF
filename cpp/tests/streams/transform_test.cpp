/*
 * Copyright (c) 2024-2025, NVIDIA CORPORATION.
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
// Modifications Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
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

#include <cudf_test/base_fixture.hpp>
#include <cudf_test/column_wrapper.hpp>
#include <cudf_test/default_stream.hpp>

#include <cudf/ast/expressions.hpp>
#include <cudf/column/column_view.hpp>
#include <cudf/jit/runtime_support.hpp>
#include <cudf/transform.hpp>
#include <cudf/types.hpp>

class TransformTest : public cudf::test::BaseFixture {
 protected:
  void SetUp() override
  {
    if (!cudf::is_runtime_jit_supported()) {
      GTEST_SKIP() << "Skipping tests that require runtime JIT support";
    }
  }
};

template <class dtype, class Data>
void test_udf(char const* udf, Data data_init, cudf::size_type size, bool is_ptx)
{
  auto all_valid = cudf::detail::make_counting_transform_iterator(0, [](auto i) { return true; });
  auto data_iter = cudf::detail::make_counting_transform_iterator(0, data_init);
  cudf::test::fixed_width_column_wrapper<dtype, typename decltype(data_iter)::value_type> in(
    data_iter, data_iter + size, all_valid);
  cudf::transform({in},
                  udf,
                  cudf::data_type(cudf::type_to_id<dtype>()),
                  is_ptx,
                  cudf::test::get_default_stream());
}

TEST_F(TransformTest, Transform)
{
  char const* cuda =
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
  char const* amd_llvm_ir = 
    R"'''(
define hidden void @udf_funcname_from_numba_to_be_replaced_in_libcudf(ptr %0, float %1) #0 {
  %3 = alloca ptr, align 8, addrspace(5)
  %4 = alloca float, align 4, addrspace(5)
  %5 = addrspacecast ptr addrspace(5) %3 to ptr
  %6 = addrspacecast ptr addrspace(5) %4 to ptr
  store ptr %0, ptr %5, align 8, !tbaa !7
  store float %1, ptr %6, align 4, !tbaa !11
  %7 = load float, ptr %6, align 4, !tbaa !11
  %8 = load float, ptr %6, align 4, !tbaa !11
  %9 = fmul contract float %7, %8
  %10 = load float, ptr %6, align 4, !tbaa !11
  %11 = fmul contract float %9, %10
  %12 = load float, ptr %6, align 4, !tbaa !11
  %13 = fmul contract float %11, %12
  %14 = load ptr, ptr %5, align 8, !tbaa !7
  store float %13, ptr %14, align 4, !tbaa !11
  ret void
}

attributes #0 = { convergent mustprogress noreturn nounwind "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="gfx90a" "target-features"="+16-bit-insts,+atomic-buffer-global-pk-add-f16-insts,+atomic-fadd-rtn-insts,+ci-insts,+dl-insts,+dot1-insts,+dot10-insts,+dot2-insts,+dot3-insts,+dot4-insts,+dot5-insts,+dot6-insts,+dot7-insts,+dpp,+gfx8-insts,+gfx9-insts,+gfx90a-insts,+mai-insts,+s-memrealtime,+s-memtime-inst,+wavefrontsize64" }

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

  auto data_init = [](cudf::size_type row) { return row % 3; };
  test_udf<float>(cuda, data_init, 500, false);
  test_udf<float>(cudf::HIP_PLATFORM_AMD ? amd_llvm_ir : ptx, data_init, 500, true);
}

TEST_F(TransformTest, ComputeColumn)
{
  auto c_0        = cudf::test::fixed_width_column_wrapper<cudf::size_type>{3, 20, 1, 50};
  auto c_1        = cudf::test::fixed_width_column_wrapper<cudf::size_type>{10, 7, 20, 0};
  auto table      = cudf::table_view{{c_0, c_1}};
  auto col_ref_0  = cudf::ast::column_reference(0);
  auto col_ref_1  = cudf::ast::column_reference(1);
  auto expression = cudf::ast::operation(cudf::ast::ast_operator::ADD, col_ref_0, col_ref_1);
  cudf::compute_column(table, expression, cudf::test::get_default_stream());
}

TEST_F(TransformTest, BoolsToMask)
{
  std::vector<bool> input({1, 0, 1, 0, 1, 0, 1, 0});
  cudf::test::fixed_width_column_wrapper<bool> input_column(input.begin(), input.end());
  cudf::bools_to_mask(input_column, cudf::test::get_default_stream());
}

TEST_F(TransformTest, MaskToBools)
{
  cudf::mask_to_bools(nullptr, 0, 0, cudf::test::get_default_stream());
}

TEST_F(TransformTest, Encode)
{
  cudf::test::fixed_width_column_wrapper<cudf::size_type> input{{1, 2, 3, 2, 3, 2, 1}};
  cudf::encode(cudf::table_view({input}), cudf::test::get_default_stream());
}

TEST_F(TransformTest, OneHotEncode)
{
  auto input    = cudf::test::fixed_width_column_wrapper<cudf::size_type>{8, 8, 8, 9, 9};
  auto category = cudf::test::fixed_width_column_wrapper<cudf::size_type>{8, 9};
  cudf::one_hot_encode(input, category, cudf::test::get_default_stream());
}

TEST_F(TransformTest, NaNsToNulls)
{
  std::vector<float> input = {1, 2, 3, 4, 5};
  std::vector<bool> mask   = {true, true, true, true, false, false};
  auto input_column =
    cudf::test::fixed_width_column_wrapper<float>(input.begin(), input.end(), mask.begin());
  cudf::nans_to_nulls(input_column, cudf::test::get_default_stream());
}

TEST_F(TransformTest, RowBitCount)
{
  std::vector<std::string> strings{"abc", "ï", "", "z", "bananas", "warp", "", "zing"};
  cudf::test::strings_column_wrapper col(strings.begin(), strings.end());
  cudf::row_bit_count(cudf::table_view({col}), cudf::test::get_default_stream());
}

TEST_F(TransformTest, SegmentedRowBitCount)
{
  // clang-format off
  std::vector<std::string> const strings { "daïs", "def", "", "z", "bananas", "warp", "", "zing" };
  std::vector<bool>        const valids  {  1,      0,    0,  1,   0,          1,      1,  1 };
  // clang-format on
  cudf::test::strings_column_wrapper const col(strings.begin(), strings.end(), valids.begin());
  auto const input              = cudf::table_view({col});
  auto constexpr segment_length = 2;
  cudf::segmented_row_bit_count(input, segment_length, cudf::test::get_default_stream());
}
