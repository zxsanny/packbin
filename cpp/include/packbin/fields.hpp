#pragma once

#include "packbin/table.hpp"

#include <cstddef>
#include <cstdint>
#include <type_traits>

// Field builders. An unbound builder (`u16(4)`) reads and skips its bytes on unpack and is
// absent on pack. A bound builder (`u16<&Row::sid>(0)`) reads and writes that member; an
// `Opt<T>` member may be absent.

namespace packbin {

namespace detail {

template <Kind K, typename T, auto M>
constexpr Node<typename Member<decltype(M)>::Class, 1> bind(int id) {
  using Type = typename Member<decltype(M)>::Type;
  static_assert(std::is_same<Type, T>::value || std::is_same<Type, Opt<T>>::value,
                "packbin: the member type does not match the field kind");
  Field f = leaf(K, id);
  f.access = &access<M>;
  if (IsOpt<Type>::value)
    f.flags = static_cast<std::uint8_t>(f.flags | flag::Optional);
  return Node<typename Member<decltype(M)>::Class, 1>{{f}};
}

constexpr Node<void, 1> unbound(Kind kind, int id) { return Node<void, 1>{{leaf(kind, id)}}; }

}  // namespace detail

#define PACKBIN_SCALAR(name, KIND, TYPE)                                          \
  constexpr Node<void, 1> name(int id) { return detail::unbound(Kind::KIND, id); } \
  template <auto M>                                                               \
  constexpr Node<typename detail::Member<decltype(M)>::Class, 1> name(int id) {   \
    return detail::bind<Kind::KIND, TYPE, M>(id);                                 \
  }

PACKBIN_SCALAR(u8, U8, std::uint8_t)
PACKBIN_SCALAR(u16, U16, std::uint16_t)
PACKBIN_SCALAR(u32, U32, std::uint32_t)
PACKBIN_SCALAR(u64, U64, std::uint64_t)
PACKBIN_SCALAR(i8, I8, std::int8_t)
PACKBIN_SCALAR(i16, I16, std::int16_t)
PACKBIN_SCALAR(i32, I32, std::int32_t)
PACKBIN_SCALAR(i64, I64, std::int64_t)
PACKBIN_SCALAR(f32, F32, float)
PACKBIN_SCALAR(boolean, Bool, bool)

#undef PACKBIN_SCALAR

template <typename D = double>
constexpr Node<void, 1> f64(int id) {
  static_assert(f64_supported<D>, "packbin: f64 needs an 8-byte double on this target");
  return detail::unbound(Kind::F64, id);
}

template <auto M>
constexpr Node<typename detail::Member<decltype(M)>::Class, 1> f64(int id) {
  static_assert(f64_supported<double>, "packbin: f64 needs an 8-byte double on this target");
  return detail::bind<Kind::F64, double, M>(id);
}

// Fixed-length bytes; a bound member is `std::uint8_t[n]`.
constexpr Node<void, 1> bytes(int id, int n) {
  Field f = detail::leaf(Kind::Bytes, id);
  f.size = static_cast<std::uint16_t>(n);
  return Node<void, 1>{{f}};
}

template <auto M>
constexpr Node<typename detail::Member<decltype(M)>::Class, 1> bytes(int id) {
  using Type = typename detail::Member<decltype(M)>::Type;
  static_assert(std::is_array<Type>::value &&
                    std::is_same<std::remove_extent_t<Type>, std::uint8_t>::value,
                "packbin: bytes binds a std::uint8_t[n] member");
  Field f = detail::leaf(Kind::Bytes, id);
  f.size = static_cast<std::uint16_t>(std::extent<Type>::value);
  f.access = &detail::access<M>;
  return Node<typename detail::Member<decltype(M)>::Class, 1>{{f}};
}

template <typename C>
constexpr Node<C, 1> be(Node<C, 1> node) {
  node.f[0].flags = static_cast<std::uint8_t>(node.f[0].flags | flag::BigEndian);
  return node;
}

// The children are on the wire only when the earlier field `condition.field_id` equals
// `condition.value`. The `when` id is the anchor: the id of its first child.
template <typename... Ns>
constexpr auto when(int id, Eq condition, Ns const&... children) {
  Field head = detail::leaf(Kind::When, id);
  head.ref_id = static_cast<std::int16_t>(condition.field_id);
  head.eq = condition.value;
  return detail::nest(head, children...);
}

}  // namespace packbin

#include "packbin/fields_grouped.hpp"
#include "packbin/fields_counted.hpp"
