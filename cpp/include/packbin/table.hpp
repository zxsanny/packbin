#pragma once

#include "packbin/core.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <type_traits>

namespace packbin {

enum class Kind : std::uint8_t {
  U8,
  U16,
  U32,
  U64,
  I8,
  I16,
  I32,
  I64,
  F32,
  F64,
  Bytes,
  Bool,
  Flags,
  FlagByte,
  FlagBit,
  When,
  Repeat,
  Group,
  Sized,
  U2,
  Bits,
  Packed,
  Times,
  Utf8,
  List,
  Dict,
};

// A row member the packet may leave out: presence decides flag bits and `when` matches.
template <typename T>
struct Opt {
  T value{};
  bool has = false;

  constexpr Opt() = default;
  constexpr Opt(T v) : value(v), has(true) {}
  Opt& operator=(T v) {
    value = v;
    has = true;
    return *this;
  }
  void reset() {
    value = T{};
    has = false;
  }
};

namespace flag {
constexpr std::uint8_t BigEndian = 1;
constexpr std::uint8_t Optional = 2;
}  // namespace flag

// Returns the bound member inside one row or element object.
using Access = void* (*)(void* obj);

// One entry of a scheme table. Children follow their parent in preorder; `span` counts the
// entry and all of its descendants, so the next sibling is at `index + span`.
struct Field {
  Kind kind = Kind::U8;
  std::uint8_t flags = 0;
  std::int16_t id = -1;
  std::uint16_t span = 1;
  // Order id named by `eq()` or a count, and its table index once the scheme resolves it.
  std::int16_t ref_id = -1;
  std::int16_t ref = -1;
  // `bytes(n)` length.
  std::uint16_t size = 0;
  std::int64_t eq = 0;
  Access access = nullptr;

  constexpr bool be() const { return (flags & flag::BigEndian) != 0; }
  constexpr bool optional() const { return (flags & flag::Optional) != 0; }
};

// A built piece of a scheme: N table entries whose accessors apply to objects of type C
// (void when nothing in it is bound).
template <typename C, std::size_t N>
struct Node {
  using Class = C;
  static constexpr std::size_t size = N;
  std::array<Field, N> f{};
};

struct Eq {
  int field_id;
  std::int64_t value;
};

constexpr Eq eq(int field_id, std::int64_t value) { return Eq{field_id, value}; }

namespace detail {

template <typename M>
struct Member;

template <typename C, typename T>
struct Member<T C::*> {
  using Class = C;
  using Type = T;
};

template <auto M>
void* access(void* obj) {
  using C = typename Member<decltype(M)>::Class;
  return &(static_cast<C*>(obj)->*M);
}

template <typename T>
struct IsOpt : std::false_type {};
template <typename T>
struct IsOpt<Opt<T>> : std::true_type {};

template <typename A, typename B>
struct Join {
  static_assert(std::is_void<A>::value || std::is_void<B>::value || std::is_same<A, B>::value,
                "packbin: fields of one scope bind members of one row type");
  using type = std::conditional_t<std::is_void<A>::value, B, A>;
};

template <typename... Cs>
struct JoinAll {
  using type = void;
};
template <typename C, typename... Rest>
struct JoinAll<C, Rest...> {
  using type = typename Join<C, typename JoinAll<Rest...>::type>::type;
};

template <typename... Ns>
constexpr std::size_t total() {
  return (std::size_t{0} + ... + Ns::size);
}

template <std::size_t M, typename Src>
constexpr int copy_fields(std::array<Field, M>& dst, std::size_t& at, Src const& src) {
  for (std::size_t i = 0; i < Src::size; ++i)
    dst[at + i] = src.f[i];
  at += Src::size;
  return 0;
}

// A parent entry followed by its children's entries.
template <typename... Ns>
constexpr Node<typename JoinAll<typename Ns::Class...>::type, 1 + total<Ns...>()> nest(
    Field head, Ns const&... children) {
  Node<typename JoinAll<typename Ns::Class...>::type, 1 + total<Ns...>()> out{};
  head.span = static_cast<std::uint16_t>(1 + total<Ns...>());
  out.f[0] = head;
  std::size_t at = 1;
  ((void)copy_fields(out.f, at, children), ...);
  return out;
}

constexpr Field leaf(Kind kind, int id) {
  Field f{};
  f.kind = kind;
  f.id = static_cast<std::int16_t>(id);
  return f;
}

}  // namespace detail

}  // namespace packbin
