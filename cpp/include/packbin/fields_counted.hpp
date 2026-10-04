#pragma once

#include "packbin/table.hpp"

#include <cstdint>
#include <type_traits>

// Strings, counted bytes, small-number packs and the counted containers. Every variable size
// lands in caller storage with a fixed maximum: a borrowed View, a Text<N>/Blob<N>, or an
// Array<T, N>.

namespace packbin {

namespace detail {

template <auto M>
using MemberClass = typename Member<decltype(M)>::Class;

template <auto M>
using MemberType = typename Member<decltype(M)>::Type;

template <Kind K, auto M>
constexpr Node<MemberClass<M>, 1> bind_text(int id) {
  Field f = leaf(K, id);
  f.access = &access<M>;
  bind_storage<MemberType<M>>(f);
  return Node<MemberClass<M>, 1>{{f}};
}

template <Kind K>
constexpr Field counted_leaf(int id, int count_id) {
  Field f = leaf(K, id);
  f.ref_id = static_cast<std::int16_t>(count_id);
  return f;
}

template <auto M, typename T>
constexpr void bind_small_numbers(Field& f) {
  using Type = MemberType<M>;
  static_assert(IsArray<Type>::value &&
                    std::is_same<typename Type::value_type, std::uint8_t>::value,
                "packbin: bits and packed bind an Array<std::uint8_t, N> member");
  f.access = &access<M>;
  bind_array<Type>(f);
}

// A counted container bound to an Array<E, N> member; its children bind members of E.
template <auto M, typename... Ns>
constexpr auto container(Field head, Ns const&... children) {
  using Type = MemberType<M>;
  static_assert(IsArray<Type>::value, "packbin: repeat and times bind an Array<E, N> member");
  using Element = typename Type::value_type;
  static_assert(((std::is_void<typename Ns::Class>::value ||
                  std::is_same<typename Ns::Class, Element>::value) &&
                 ...),
                "packbin: repeat and times children bind members of the Array element type");
  head.access = &access<M>;
  bind_array<Type>(head);
  auto out = nest(head, children...);
  return Node<MemberClass<M>, decltype(out)::size>{out.f};
}

}  // namespace detail

// u16 byte length, then UTF-8 bytes. A bound member is a View (borrowed) or a Text<N>.
constexpr Node<void, 1> utf8(int id) { return detail::unbound(Kind::Utf8, id); }

template <auto M>
constexpr Node<detail::MemberClass<M>, 1> utf8(int id) {
  return detail::bind_text<Kind::Utf8, M>(id);
}

// Fixed-length bytes borrowed into a View member; the View length must equal `n` on pack.
template <auto M>
constexpr Node<detail::MemberClass<M>, 1> bytes(int id, int n) {
  static_assert(std::is_same<detail::MemberType<M>, View>::value,
                "packbin: bytes(id, n) binds a View member; use bytes<&Row::m>(id) for "
                "std::uint8_t[n]");
  Field f = detail::leaf(Kind::Bytes, id);
  f.size = static_cast<std::uint16_t>(n);
  f.access = &detail::access<M>;
  f.flags = static_cast<std::uint8_t>(f.flags | flag::Borrowed);
  return Node<detail::MemberClass<M>, 1>{{f}};
}

// Bytes whose length is the value of the earlier field `count_id`. A bound member is a View
// or a Blob<N>.
constexpr Node<void, 1> sized(int id, int count_id) {
  return Node<void, 1>{{detail::counted_leaf<Kind::Sized>(id, count_id)}};
}

template <auto M>
constexpr Node<detail::MemberClass<M>, 1> sized(int id, int count_id) {
  Field f = detail::counted_leaf<Kind::Sized>(id, count_id);
  f.access = &detail::access<M>;
  detail::bind_storage<detail::MemberType<M>>(f);
  return Node<detail::MemberClass<M>, 1>{{f}};
}

// Two-bit values (0..3) packed four to a byte, low bits first. Children are u8 fields.
template <typename... Ns>
constexpr auto u2(Ns const&... children) {
  static_assert(sizeof...(Ns) > 0, "packbin: u2 needs at least one field");
  Field head = detail::leaf(Kind::U2, 0);
  auto out = detail::nest(head, children...);
  out.f[0].id = out.f[1].id;
  for (std::size_t i = 1; i < out.size; ++i) {
    if (out.f[i].kind != Kind::U8 || out.f[i].span != 1)
      detail::mark_invalid(out.f[0]);
  }
  return out;
}

// `count_id` bits (0 or 1), eight to a byte, low bit first.
constexpr Node<void, 1> bits(int id, int count_id) {
  return Node<void, 1>{{detail::counted_leaf<Kind::Bits>(id, count_id)}};
}

template <auto M>
constexpr Node<detail::MemberClass<M>, 1> bits(int id, int count_id) {
  Field f = detail::counted_leaf<Kind::Bits>(id, count_id);
  detail::bind_small_numbers<M, std::uint8_t>(f);
  return Node<detail::MemberClass<M>, 1>{{f}};
}

// (value of `count_id` + bias) numbers of `width` bits (1 or 2), low bits first.
constexpr Node<void, 1> packed(int width, int id, int count_id, int bias = 0) {
  Field f = detail::counted_leaf<Kind::Packed>(id, count_id);
  f.width = static_cast<std::uint8_t>(width);
  f.bias = static_cast<std::int8_t>(bias);
  if ((width != 1 && width != 2) || (bias != 0 && bias != -1))
    detail::mark_invalid(f);
  return Node<void, 1>{{f}};
}

template <auto M>
constexpr Node<detail::MemberClass<M>, 1> packed(int width, int id, int count_id,
                                                 int bias = 0) {
  Field f = packed(width, id, count_id, bias).f[0];
  detail::bind_small_numbers<M, std::uint8_t>(f);
  return Node<detail::MemberClass<M>, 1>{{f}};
}

// Groups of the children until the packet ends. The repeat id is the anchor.
template <typename... Ns>
constexpr auto repeat(int id, Ns const&... children) {
  return detail::nest(detail::leaf(Kind::Repeat, id), children...);
}

template <auto M, typename... Ns>
constexpr auto repeat(int id, Ns const&... children) {
  return detail::container<M>(detail::leaf(Kind::Repeat, id), children...);
}

// (value of `count_id`) groups of the children. The times id is the anchor.
template <typename... Ns>
constexpr auto times(int id, int count_id, Ns const&... children) {
  return detail::nest(detail::counted_leaf<Kind::Times>(id, count_id), children...);
}

template <auto M, typename... Ns>
constexpr auto times(int id, int count_id, Ns const&... children) {
  return detail::container<M>(detail::counted_leaf<Kind::Times>(id, count_id), children...);
}

// u16 item count, then the items. The element is one unbound field (its ids start at 0); it
// is bound to each Array item. A list takes no order id.
template <typename C, std::size_t N>
constexpr Node<void, N + 1> list(Node<C, N> const& element) {
  static_assert(std::is_void<C>::value, "packbin: a list element is written unbound");
  return detail::nest(detail::leaf(Kind::List, -1), element);
}

template <auto M, typename C, std::size_t N>
constexpr Node<detail::MemberClass<M>, N + 1> list(Node<C, N> const& element) {
  static_assert(std::is_void<C>::value, "packbin: a list element is written unbound");
  static_assert(detail::IsArray<detail::MemberType<M>>::value,
                "packbin: list binds an Array<T, N> member");
  auto out = detail::nest(detail::leaf(Kind::List, -1), element);
  out.f[0].access = &detail::access<M>;
  detail::bind_element<detail::MemberType<M>>(out.f.data());
  return Node<detail::MemberClass<M>, N + 1>{out.f};
}

// u16 entry count, then per entry a u16-length UTF-8 key and the element. A dict takes no
// order id. A bound member is Array<Entry<V, Key>, N>; keys keep the caller's order on pack.
template <typename C, std::size_t N>
constexpr Node<void, N + 2> dict(Node<C, N> const& element) {
  static_assert(std::is_void<C>::value, "packbin: a dict element is written unbound");
  return detail::nest(detail::leaf(Kind::Dict, -1), Node<void, 1>{{detail::leaf(Kind::Utf8, -1)}},
                      element);
}

template <auto M, typename C, std::size_t N>
constexpr Node<detail::MemberClass<M>, N + 2> dict(Node<C, N> const& element) {
  auto out = dict(element);
  out.f[0].access = &detail::access<M>;
  detail::bind_element<detail::MemberType<M>>(out.f.data());
  return Node<detail::MemberClass<M>, N + 2>{out.f};
}

}  // namespace packbin
