/*
 * Copyright (c) 2023, NVIDIA CORPORATION.
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
 */

// Modifications Copyright (c) 2024 Advanced Micro Devices, Inc.
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#pragma once

#include <thrust/device_reference.h>
#include <thrust/tuple.h>

#include <hip/std/type_traits>

#include <tuple>

namespace hipco::detail {

template <typename T, typename = void>
struct is_std_pair_like : hip::std::false_type {
};

template <typename T>
struct is_std_pair_like<T,
                        hip::std::void_t<decltype(std::get<0>(hip::std::declval<T>())),
                                          decltype(std::get<1>(hip::std::declval<T>()))>>
  : hip::std::
      conditional_t<std::tuple_size<T>::value == 2, hip::std::true_type, hip::std::false_type> {
};

template <typename T, typename = void>
struct is_thrust_pair_like_impl : hip::std::false_type {
};

template <typename T>
struct is_thrust_pair_like_impl<
  T,
  hip::std::void_t<decltype(thrust::get<0>(hip::std::declval<T>())),
                    decltype(thrust::get<1>(hip::std::declval<T>()))>>
  : hip::std::conditional_t<thrust::tuple_size<T>::value == 2,
                             hip::std::true_type,
                             hip::std::false_type> {
};

template <typename T>
struct is_thrust_pair_like
  : is_thrust_pair_like_impl<hip::std::remove_reference_t<decltype(thrust::raw_reference_cast(
      hip::std::declval<T>()))>> {
};

}  // namespace hipco::detail