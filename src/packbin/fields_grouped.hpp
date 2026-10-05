#pragma once

#include "packbin/table.hpp"

#include <cstdint>
#include <type_traits>

// Flags, flag byte bits and groups.

namespace packbin {

// One byte of presence bits, then the present children in order. Child k is bit k (up to 8).
// The flags id is the anchor: the id of its first child.
template <typename... Ns>
constexpr auto flags(int id, Ns const&... children) {
  return detail::nest(detail::leaf(Kind::Flags, id), children...);
}

// Fields written one after another. The group id is the anchor. Under `flags` the group is
// present when any of its direct children is present. With no children and no member its bit
// could never be set, so the scheme is invalid wherever it stands.
template <typename... Ns>
constexpr auto group(int id, Ns const&... children) {
  auto out = detail::nest(detail::leaf(Kind::Group, id), children...);
  if constexpr (sizeof...(Ns) == 0)
    detail::mark_invalid(out.f[0]);
  return out;
}

// A group with no fields under `flags`: only its bit is on the wire, bound to a bool member.
template <auto M>
constexpr Node<typename detail::Member<decltype(M)>::Class, 1> group(int id) {
  using Type = typename detail::Member<decltype(M)>::Type;
  static_assert(std::is_same<Type, bool>::value || std::is_same<Type, Opt<bool>>::value,
                "packbin: an empty group binds a bool member");
  Field f = detail::leaf(Kind::Group, id);
  f.access = &detail::access<M>;
  if (detail::IsOpt<Type>::value)
    f.flags = static_cast<std::uint8_t>(f.flags | flag::Optional);
  return Node<typename detail::Member<decltype(M)>::Class, 1>{{f}};
}

// A presence byte whose bits belong to fields placed later in the same scope with
// `flag_bit(byte_number, field)`. `byte_number` (0..7) pairs a byte with its bits. Not named
// `bit`: Arduino.h defines a `bit(b)` macro.
constexpr Node<void, 1> flag_byte(int byte_number) {
  Field f = detail::leaf(Kind::FlagByte, -1);
  f.size = static_cast<std::uint16_t>(byte_number);
  if (byte_number < 0 || byte_number > 7)
    detail::mark_invalid(f);
  return Node<void, 1>{{f}};
}

template <typename C, std::size_t N>
constexpr Node<C, N + 1> flag_bit(int byte_number, Node<C, N> const& child) {
  Field head = detail::leaf(Kind::FlagBit, -1);
  head.size = static_cast<std::uint16_t>(byte_number);
  if (byte_number < 0 || byte_number > 7)
    detail::mark_invalid(head);
  return detail::nest(head, child);
}

}  // namespace packbin
