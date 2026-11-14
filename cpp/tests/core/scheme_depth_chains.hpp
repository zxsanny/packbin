// Chains of nested containers for the scheme depth limit (contract scheme-depth.md, AZ-4303).
// A run-time chain is a table of `Field` entries filled by a loop (a C++ scheme nests by template
// arguments, so 257 or 50,000 levels cannot be written in source) and checked by `check_table`, the
// call `scheme()` makes for its status. A typed chain is a `constexpr` scheme of exactly 256
// levels written with a recursive builder, packed and unpacked in scheme_depth_host_tests.cpp.

#pragma once

#include "packbin/codec.hpp"

#include <cstddef>
#include <cstdint>

namespace depth_chain {

namespace pb = packbin;

struct Row {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

enum class Shape { When, Group, List, Dict };

// The entries one level of `shape` takes, and the entries around the chain: when has `u8 a` before
// and `u8 b` inside, group, list and dict hold only the innermost `u8`; a dict level is the dict
// and its key.
constexpr std::size_t per_level(Shape s) { return s == Shape::Dict ? 2 : 1; }
constexpr std::size_t extra(Shape s) { return s == Shape::When ? 2 : 1; }
template <Shape S, std::size_t Depth>
constexpr std::size_t entries = Depth * per_level(S) + extra(S);

// The table of `depth` nested containers (storage is static, so the stack the package meets is its
// own). The caller has chosen N = entries<S, depth>; the status is what `check_table` says.
template <Shape S, std::size_t N>
pb::Scheme<Row, N>& build(std::size_t depth) {
  static pb::Scheme<Row, N> s;
  s.type_number = 1;  // every entry is written below, so the static table needs no reset
  std::size_t at = 0;
  if (S == Shape::When)
    s.fields[at++] = pb::u8<&Row::a>(0).f[0];
  for (std::size_t i = 0; i < depth; ++i) {
    pb::Field head;
    switch (S) {
      case Shape::When:
        head = pb::when(1, pb::eq(0, 1), pb::u8<&Row::b>(1)).f[0];
        break;
      case Shape::Group:
        head = pb::group(0, pb::u8<&Row::b>(0)).f[0];
        break;
      case Shape::List:
        head = pb::list(pb::u8(0)).f[0];
        break;
      case Shape::Dict:
        head = pb::dict(pb::u8(0)).f[0];
        break;
    }
    head.span = static_cast<std::uint16_t>(N - at);
    s.fields[at++] = head;
    if (S == Shape::Dict)
      s.fields[at++] = pb::dict(pb::u8(0)).f[1];
  }
  if (S == Shape::When)
    s.fields[at++] = pb::u8<&Row::b>(1).f[0];
  else if (S == Shape::Group)
    s.fields[at++] = pb::u8<&Row::b>(0).f[0];
  else
    s.fields[at++] = pb::u8(0).f[0];
  s.status = pb::check_table(s.fields.data(), s.fields.size());
  return s;
}

// The same table, answered as the status of `check_table`.
template <Shape S, std::size_t Depth>
pb::Result status_at() {
  return build<S, entries<S, Depth>>(Depth).status;
}

// Typed chains of exactly D levels, written by recursion (D calls): the leaf is the innermost field.
template <int D, typename Leaf>
constexpr auto whens(Leaf const& leaf) {
  if constexpr (D == 0)
    return leaf;
  else
    return pb::when(1, pb::eq(0, 1), whens<D - 1>(leaf));
}

template <int D, typename Leaf>
constexpr auto groups(Leaf const& leaf) {
  if constexpr (D == 0)
    return leaf;
  else
    return pb::group(0, groups<D - 1>(leaf));
}

// A list or dict level is an Array layer of the row: Layers<D> is D Arrays inside each other.
template <int D>
struct ListLayers {
  using type = pb::Array<typename ListLayers<D - 1>::type, 1>;
};
template <>
struct ListLayers<0> {
  using type = std::uint8_t;
};

// The unbound inner levels of a list (or dict) chain: D levels around the u8.
template <int D>
constexpr auto inner_lists() {
  if constexpr (D == 0)
    return pb::u8(0);
  else
    return pb::list(inner_lists<D - 1>());
}

// A typed dict chain of 256 levels does not compile (the types Array<Entry<Array<...>>> nest, and
// clang runs out of stack in their default member initializers at 64 levels), so the dict chain that
// is packed and unpacked is a table whose every level reads and writes one shared array: the walk of
// the table is 256 levels deep, the storage is one level.
struct Level {
  pb::Array<pb::Entry<std::uint8_t, pb::Text<1>>, 1> m;
};

inline Level& shared_level() {
  static Level l;
  return l;
}

inline void* shared_array(void*) { return &shared_level().m; }

// The dict chain of `depth` levels (N = 2 * depth + 1: a dict and its key per level, then the u8).
template <std::size_t N>
pb::Scheme<Level, N>& shared_dict_chain(std::size_t depth) {
  static pb::Scheme<Level, N> s;
  s.type_number = 1;
  auto one = pb::dict<&Level::m>(pb::u8(0));
  std::size_t at = 0;
  for (std::size_t i = 0; i < depth; ++i) {
    pb::Field head = one.f[0];
    head.span = static_cast<std::uint16_t>(N - at);
    head.access = &shared_array;
    s.fields[at++] = head;
    s.fields[at++] = one.f[1];
  }
  s.fields[at++] = one.f[2];
  s.status = pb::check_table(s.fields.data(), s.fields.size());
  return s;
}

}  // namespace depth_chain
