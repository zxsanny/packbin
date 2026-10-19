#pragma once

// The one place the core takes standard names from (AZ-2068). A compiler with a C++ library gets
// <cstddef>, <cstdint> and <cstring>; avr-gcc ships none (no <cstdint>, a 4-byte double), so there
// the C headers are included and their names declared in std. The type traits and the fixed array
// the core needs are written below in packbin::detail and used on every target, so no target needs
// <type_traits> or <array>.

#if __has_include(<cstdint>)
#include <cstddef>
#include <cstdint>
#include <cstring>
#else
#include <stddef.h>
#include <stdint.h>
#include <string.h>

namespace std {
using ::int16_t;
using ::int32_t;
using ::int64_t;
using ::int8_t;
using ::memcmp;
using ::memcpy;
using ::memmove;
using ::memset;
using ::size_t;
using ::uint16_t;
using ::uint32_t;
using ::uint64_t;
using ::uint8_t;
}  // namespace std
#endif

namespace packbin {
namespace detail {

template <typename T, T V>
struct integral_constant {
  static constexpr T value = V;
};
using true_type = integral_constant<bool, true>;
using false_type = integral_constant<bool, false>;

template <typename A, typename B>
struct is_same : false_type {};
template <typename A>
struct is_same<A, A> : true_type {};

template <typename T>
struct remove_cv {
  using type = T;
};
template <typename T>
struct remove_cv<T const> {
  using type = T;
};
template <typename T>
struct remove_cv<T volatile> {
  using type = T;
};
template <typename T>
struct remove_cv<T const volatile> {
  using type = T;
};

template <typename T, typename... Us>
constexpr bool is_one_of() {
  return (is_same<typename remove_cv<T>::type, Us>::value || ...);
}

template <typename T>
struct is_void : integral_constant<bool, is_one_of<T, void>()> {};

template <typename T>
struct is_integral
    : integral_constant<bool, is_one_of<T, bool, char, signed char, unsigned char, wchar_t,
                                        char16_t, char32_t, short, unsigned short, int, unsigned,
                                        long, unsigned long, long long, unsigned long long>()> {};

template <typename T>
struct is_floating_point : integral_constant<bool, is_one_of<T, float, double, long double>()> {};

template <typename T>
struct is_arithmetic
    : integral_constant<bool, is_integral<T>::value || is_floating_point<T>::value> {};

template <typename T, bool = is_arithmetic<T>::value>
struct is_unsigned : integral_constant<bool, (T(0) < T(-1))> {};
template <typename T>
struct is_unsigned<T, false> : false_type {};

template <bool C, typename A, typename B>
struct conditional {
  using type = A;
};
template <typename A, typename B>
struct conditional<false, A, B> {
  using type = B;
};
template <bool C, typename A, typename B>
using conditional_t = typename conditional<C, A, B>::type;

template <typename T>
struct is_array : false_type {};
template <typename T, std::size_t N>
struct is_array<T[N]> : true_type {};

template <typename T>
struct extent : integral_constant<std::size_t, 0> {};
template <typename T, std::size_t N>
struct extent<T[N]> : integral_constant<std::size_t, N> {};

template <typename T>
struct remove_extent {
  using type = T;
};
template <typename T, std::size_t N>
struct remove_extent<T[N]> {
  using type = T;
};
template <typename T>
using remove_extent_t = typename remove_extent<T>::type;

// N values of T in place, with the members of std::array the core and its callers use.
template <typename T, std::size_t N>
struct FixedArray {
  T items[N];

  constexpr T& operator[](std::size_t i) { return items[i]; }
  constexpr T const& operator[](std::size_t i) const { return items[i]; }
  constexpr T* data() { return items; }
  constexpr T const* data() const { return items; }
  constexpr T* begin() { return items; }
  constexpr T const* begin() const { return items; }
  constexpr T* end() { return items + N; }
  constexpr T const* end() const { return items + N; }
  static constexpr std::size_t size() { return N; }
};

template <typename T>
struct FixedArray<T, 0> {
  constexpr T* data() { return nullptr; }
  constexpr T const* data() const { return nullptr; }
  constexpr T* begin() { return nullptr; }
  constexpr T const* begin() const { return nullptr; }
  constexpr T* end() { return nullptr; }
  constexpr T const* end() const { return nullptr; }
  static constexpr std::size_t size() { return 0; }
};

}  // namespace detail
}  // namespace packbin
