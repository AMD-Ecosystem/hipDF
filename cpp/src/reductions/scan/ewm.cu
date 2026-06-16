/*
 * SPDX-FileCopyrightText: Copyright (c) 2022-2026, NVIDIA CORPORATION.
 * SPDX-License-Identifier: Apache-2.0
 */

// MIT License
//
// Modifications Copyright (C) 2026 Advanced Micro Devices, Inc. All rights reserved.
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

#include "scan.cuh"

#include <cudf/column/column_device_view.cuh>
#include <cudf/column/column_factories.hpp>
#include <cudf/detail/iterator.cuh>
#include <cudf/detail/null_mask.hpp>
#include <cudf/utilities/type_dispatcher.hpp>

#include <rmm/cuda_stream_view.hpp>
#include <rmm/device_uvector.hpp>
#include <rmm/exec_policy.hpp>

#include <cuda/functional>
#include <cuda/iterator>
#include <cuda/std/utility>
#include <thrust/scan.h>
#include <thrust/transform_scan.h>

namespace cudf {
namespace detail {

template <typename T>
using pair_type = cuda::std::pair<T, T>;

/**
 * @brief functor to be summed over in a prefix sum such that
 * the recurrence in question is solved. See
 * G. E. Blelloch. Prefix sums and their applications. Technical Report
 * CMU-CS-90-190, Nov. 1990. S. 1.4
 * for details
 */
template <typename T>
class recurrence_functor {
 public:
  // NOTE(HIP/AMD): const-qualified so rocPRIM (which stores the scan op as const) can invoke it.
  __device__ pair_type<T> operator()(pair_type<T> ci, pair_type<T> cj) const
  {
    return {ci.first * cj.first, ci.second * cj.first + cj.second};
  }
};

template <typename T>
struct ewma_functor_base {
  T beta;
  const pair_type<T> IDENTITY{1.0, 0.0};
};

template <typename T, bool is_numerator>
struct ewma_adjust_nulls_functor : public ewma_functor_base<T> {
  // NOTE(HIP/AMD): templated tuple parameter so a rocThrust zip_iterator (thrust::tuple) and a
  // CCCL zip (cuda::std::tuple) both bind; structured bindings work for either tuple type.
  template <typename TupleT>
  __device__ pair_type<T> operator()(TupleT const data) const
  {
    // NOTE(HIP/AMD): structured bindings over a rocThrust zip dereference bind to references;
    // copy `input` into a mutable local so it can be reassigned below.
    auto const [valid, exp, input_in] = data;
    T input                           = input_in;
    if (!valid) { return this->IDENTITY; }
    if constexpr (not is_numerator) { input = 1; }

    // The value is non-null, but nulls preceding it
    // must adjust the second element of the pair
    T const beta = this->beta;
    return {beta * ((exp != 0) ? pow(beta, exp) : 1), input};
  }
};

template <typename T, bool is_numerator>
struct ewma_adjust_no_nulls_functor : public ewma_functor_base<T> {
  __device__ pair_type<T> operator()(T const data) const
  {
    T const beta = this->beta;
    if constexpr (is_numerator) {
      return {beta, data};
    } else {
      return {beta, 1.0};
    }
  }
};

template <typename T>
struct ewma_noadjust_nulls_functor : public ewma_functor_base<T> {
  /*
    In the null case, a denominator actually has to be computed. The formula is
    y_{i+1} = (1 - alpha)x_{i-1} + alpha x_i, but really there is a "denominator"
    which is the sum of the weights: alpha + (1 - alpha) == 1. If a null is
    encountered, that means that the "previous" value is downweighted by a
    factor (for each missing value). For example with a single null:
    data = {x_0, NULL, x_1},
    y_2 = (1 - alpha)**2 x_0 + alpha * x_2 / (alpha + (1-alpha)**2)

    As such, the pairs must be updated before summing like the adjusted case to
    properly downweight the previous values. But now but we also need to compute
    the normalization factors and divide the results into them at the end.
  */
  template <typename TupleT>
  __device__ pair_type<T> operator()(TupleT const data) const
  {
    T const beta                              = this->beta;
    auto const [input, index, valid, nullcnt] = data;
    if (index == 0) {
      return {beta, input};
    } else {
      if (!valid) { return this->IDENTITY; }
      // preceding value is valid, return normal pair
      if (nullcnt == 0) { return {beta, (1.0 - beta) * input}; }
      // one or more preceding values is null, adjust by how many
      T const factor = (1.0 - beta) + pow(beta, nullcnt + 1);
      return {(beta * (pow(beta, nullcnt)) / factor), ((1.0 - beta) * input) / factor};
    }
  }
};

template <typename T>
struct ewma_noadjust_no_nulls_functor : public ewma_functor_base<T> {
  template <typename TupleT>
  __device__ pair_type<T> operator()(TupleT const data) const
  {
    T const beta              = this->beta;
    auto const [input, index] = data;
    if (index == 0) {
      return {beta, input};
    } else {
      return {beta, (1.0 - beta) * input};
    }
  }
};

/**
* @brief Return an array whose values y_i are the number of null entries
* in between the last valid entry of the input and the current index.
* Example: {1, NULL, 3, 4, NULL, NULL, 7}
        -> {0, 0     1, 0, 0,    1,    2}
*/
rmm::device_uvector<cudf::size_type> null_roll_up(column_view const& input,
                                                  rmm::cuda_stream_view stream)
{
  rmm::device_uvector<cudf::size_type> output(input.size(), stream);

  auto device_view = column_device_view::create(input, stream);
  auto invalid_it  = thrust::make_transform_iterator(
    cudf::detail::make_validity_iterator(*device_view),
    cuda::proclaim_return_type<int>([] __device__(int valid) -> int { return 1 - valid; }));

  // valid mask {1, 0, 1, 0, 0, 1} leads to output array {0, 0, 1, 0, 1, 2}
  thrust::inclusive_scan_by_key(
    rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
    invalid_it,
    invalid_it + input.size() - 1,
    invalid_it,
    std::next(output.begin()));
  return output;
}

// NOTE(HIP/AMD): rocThrust/rocPRIM's transform_inclusive_scan mis-infers the scan accumulator
// type when the transform output type (here cuda::std::pair<T,T>) differs from the input
// iterator's value type, producing a recurrence_functor no-match. WAR: materialize the
// transform into the output buffer, then run a plain inclusive_scan with the binary op.
template <typename InputIt, typename OutputIt, typename TransformOp>
void ewma_transform_inclusive_scan(InputIt first,
                                   std::size_t count,
                                   OutputIt out,
                                   TransformOp transform_op,
                                   rmm::cuda_stream_view stream)
{
#ifdef __HIP_PLATFORM_AMD__
  using value_t   = typename std::iterator_traits<OutputIt>::value_type;
  auto const dist = static_cast<std::ptrdiff_t>(count);
  thrust::transform(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                    first,
                    first + dist,
                    out,
                    transform_op);
  thrust::inclusive_scan(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                         out,
                         out + dist,
                         out,
                         recurrence_functor<typename value_t::first_type>{});
#else
  thrust::transform_inclusive_scan(
    rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
    first,
    first + count,
    out,
    transform_op,
    recurrence_functor<typename std::iterator_traits<OutputIt>::value_type::first_type>{});
#endif
}

template <typename T>
rmm::device_uvector<T> compute_ewma_adjust(column_view const& input,
                                           T const beta,
                                           rmm::cuda_stream_view stream,
                                           rmm::device_async_resource_ref mr)
{
  rmm::device_uvector<T> output(input.size(), stream);
  rmm::device_uvector<pair_type<T>> pairs(input.size(), stream);

  if (input.has_nulls()) {
    rmm::device_uvector<cudf::size_type> nullcnt = null_roll_up(input, stream);
    auto device_view                             = column_device_view::create(input, stream);
    auto valid_it = cudf::detail::make_validity_iterator(*device_view);
    auto data =
      thrust::make_zip_iterator(valid_it, nullcnt.begin(), input.begin<T>());

    ewma_transform_inclusive_scan(
      data, input.size(), pairs.begin(), ewma_adjust_nulls_functor<T, true>{beta}, stream);
    thrust::transform(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                      pairs.begin(),
                      pairs.end(),
                      output.begin(),
                      [] __device__(pair_type<T> pair) -> T { return pair.second; });

    ewma_transform_inclusive_scan(
      data, input.size(), pairs.begin(), ewma_adjust_nulls_functor<T, false>{beta}, stream);

  } else {
    ewma_transform_inclusive_scan(
      input.begin<T>(), input.size(), pairs.begin(), ewma_adjust_no_nulls_functor<T, true>{beta}, stream);
    thrust::transform(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                      pairs.begin(),
                      pairs.end(),
                      output.begin(),
                      [] __device__(pair_type<T> pair) -> T { return pair.second; });
    auto itr = cuda::counting_iterator<size_type>{0};

    ewma_transform_inclusive_scan(
      itr, input.size(), pairs.begin(), ewma_adjust_no_nulls_functor<T, false>{beta}, stream);
  }

  thrust::transform(
    rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
    pairs.begin(),
    pairs.end(),
    output.begin(),
    output.begin(),
    [] __device__(pair_type<T> pair, T numerator) -> T { return numerator / pair.second; });

  return output;
}

template <typename T>
rmm::device_uvector<T> compute_ewma_noadjust(column_view const& input,
                                             T const beta,
                                             rmm::cuda_stream_view stream,
                                             rmm::device_async_resource_ref mr)
{
  rmm::device_uvector<T> output(input.size(), stream);
  rmm::device_uvector<pair_type<T>> pairs(input.size(), stream);
  rmm::device_uvector<cudf::size_type> nullcnt =
    [&input, stream]() -> rmm::device_uvector<cudf::size_type> {
    if (input.has_nulls()) {
      return null_roll_up(input, stream);
    } else {
      return rmm::device_uvector<cudf::size_type>(input.size(), stream);
    }
  }();
  // denominators are all 1 and do not need to be computed
  // pairs are all (beta, 1-beta x_i) except for the first one

  if (!input.has_nulls()) {
    auto data = thrust::make_zip_iterator(input.begin<T>(), cuda::counting_iterator<size_type>{0});
    ewma_transform_inclusive_scan(
      data, input.size(), pairs.begin(), ewma_noadjust_no_nulls_functor<T>{beta}, stream);

  } else {
    auto device_view = column_device_view::create(input, stream);
    auto valid_it    = detail::make_validity_iterator(*device_view);

    auto data = thrust::make_zip_iterator(
      input.begin<T>(), cuda::counting_iterator<size_type>{0}, valid_it, nullcnt.begin());

    ewma_transform_inclusive_scan(
      data, input.size(), pairs.begin(), ewma_noadjust_nulls_functor<T>{beta}, stream);
  }

  // copy the second elements to the output for now
  thrust::transform(rmm::exec_policy_nosync(stream, cudf::get_current_device_resource_ref()),
                    pairs.begin(),
                    pairs.end(),
                    output.begin(),
                    [] __device__(pair_type<T> pair) -> T { return pair.second; });
  return output;
}

struct ewma_functor {
  template <typename T, CUDF_ENABLE_IF(!std::is_floating_point<T>::value)>
  std::unique_ptr<column> operator()(scan_aggregation const& agg,
                                     column_view const& input,
                                     rmm::cuda_stream_view stream,
                                     rmm::device_async_resource_ref mr)
  {
    CUDF_FAIL("Unsupported type for EWMA.");
  }

  template <typename T, CUDF_ENABLE_IF(std::is_floating_point<T>::value)>
  std::unique_ptr<column> operator()(scan_aggregation const& agg,
                                     column_view const& input,
                                     rmm::cuda_stream_view stream,
                                     rmm::device_async_resource_ref mr)
  {
    auto const ewma_agg       = dynamic_cast<ewma_aggregation const*>(&agg);
    auto const history        = ewma_agg->history;
    auto const center_of_mass = ewma_agg->center_of_mass;

    // center of mass is easier for the user, but the recurrences are
    // better expressed in terms of the derived parameter `beta`
    T const beta = center_of_mass / (center_of_mass + 1.0);

    auto result = [&]() {
      if (history == cudf::ewm_history::INFINITE) {
        return compute_ewma_adjust(input, beta, stream, mr);
      } else {
        return compute_ewma_noadjust(input, beta, stream, mr);
      }
    }();
    return std::make_unique<column>(cudf::data_type(cudf::type_to_id<T>()),
                                    input.size(),
                                    result.release(),
                                    rmm::device_buffer{},
                                    0);
  }
};

std::unique_ptr<column> exponentially_weighted_moving_average(column_view const& input,
                                                              scan_aggregation const& agg,
                                                              rmm::cuda_stream_view stream,
                                                              rmm::device_async_resource_ref mr)
{
  return type_dispatcher(input.type(), ewma_functor{}, agg, input, stream, mr);
}

}  // namespace detail
}  // namespace cudf
