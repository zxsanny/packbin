// The loop 113 construct cases of fixtures/hostile/cases.txt (AZ-4219, contract repeat-last.md) for
// the C++ host test (hostile_host_tests.cpp): a repeat that is not the last thing a packet reads.
// Each scheme is written by hand from its README section. A handler answers "scheme_error" only
// when the scheme is refused with SchemeInvalid at the order id its section names (the first field
// after the repeat, or the repeat itself inside an element or a round), so a refusal by another
// rule or at another field fails the case. The four pack cases of the loop are in
// hostile_pack_loop21.hpp.

#pragma once

#include "packbin/packbin.hpp"

#include "hostile_rule_check.hpp"

#include <cstddef>
#include <cstdint>
#include <cstdio>

namespace hostile_repeat_last {

namespace pb = packbin;

struct Round {
  std::uint8_t v = 0;
};

struct Row {
  std::uint8_t k = 0;
  std::uint8_t x = 0;
  pb::Array<Round, 4> rounds;
  pb::Array<Round, 4> more;
};

template <typename S>
char const* refused_at(S const& s, int field) {
  pb::Result r = pb::validate(s);
  if (r.ok())
    return "ok";
  if (r.error != pb::Error::SchemeInvalid)
    return "another_error";
  return r.field == field ? "scheme_error" : "scheme_error_at_another_field";
}

// The repeat of every case: one u8 a round, anchored at `id`.
constexpr auto rounds(int id) { return pb::repeat<&Row::rounds>(id, pb::u8<&Round::v>(id)); }

// R1: repeat { v }; x.
inline char const* repeat_then_field(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1));
  return refused_at(s, 1);
}

// R2: k; when eq(k, 1) { repeat { v } }; x.
inline char const* repeat_in_when_then_field(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, pb::u8<&Row::k>(0), pb::when(1, pb::eq(0, 1), rounds(1)),
                           pb::u8<&Row::x>(2));
  return refused_at(s, 2);
}

// R3: flags { repeat { v } }; x.
inline char const* repeat_in_flags_then_field(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, pb::flags(0, rounds(0)), pb::u8<&Row::x>(1));
  return refused_at(s, 1);
}

// R4: group { repeat { v } }; x. A C++ group has an anchor and shares the ids of the row around
// it, so `x` is id 1.
inline char const* repeat_in_group_then_field(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, pb::group(0, rounds(0)), pb::u8<&Row::x>(1));
  return refused_at(s, 1);
}

// R5: repeat { v }; repeat { w }. What follows is the member of the second repeat, id 1.
inline char const* repeat_then_repeat(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, rounds(0), pb::repeat<&Row::more>(1, pb::u8<&Round::v>(1)));
  return refused_at(s, 1);
}

// R6: k; when eq(k, 1) { repeat { v } }; when eq(k, 2) { x }. The two conditions are not compared.
inline char const* repeat_then_exclusive_when(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, pb::u8<&Row::k>(0), pb::when(1, pb::eq(0, 1), rounds(1)),
                           pb::when(2, pb::eq(0, 2), pb::u8<&Row::x>(2)));
  return refused_at(s, 2);
}

// The element row of R7 and R8: mode; repeat { v }. An element is written unbound; the only field
// that holds several fields is a group.
constexpr auto element() { return pb::group(0, pb::u8(0), pb::repeat(1, pb::u8(1))); }

// R7 and R8 in the unbound form `list(element)` / `dict(element)`, refused at the repeat (id 1). A
// list or dict bound to a member cannot take a row element, with or without a repeat, and keeps
// that refusal (repeat_last_host_tests.cpp pins it); the test output says which form ran.
inline char const* repeat_in_list_element(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, pb::list(element()));
  std::printf("hostile construct_repeat_in_list_element runs as list(element): a list bound to a "
              "member cannot take a row element\n");
  return refused_at(s, 1);
}

inline char const* repeat_in_dict_element(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Row>(1, pb::dict(element()));
  std::printf("hostile construct_repeat_in_dict_element runs as dict(element): a dict bound to a "
              "member cannot take a row element\n");
  return refused_at(s, 1);
}

// R9: k; times count = k { repeat { v } }, refused at the repeat (id 1).
struct Outer {
  pb::Array<Round, 4> inner;
};

struct Nested {
  std::uint8_t k = 0;
  pb::Array<Outer, 4> outer;
};

inline char const* repeat_in_times_round(std::uint8_t const*, std::size_t) {
  auto s = pb::scheme<Nested>(
      1, pb::u8<&Nested::k>(0),
      pb::times<&Nested::outer>(1, 0, pb::repeat<&Outer::inner>(1, pb::u8<&Round::v>(1))));
  return refused_at(s, 1);
}

constexpr Handler kHandlers[] = {
    {"construct_repeat_then_field", repeat_then_field},
    {"construct_repeat_in_when_then_field", repeat_in_when_then_field},
    {"construct_repeat_in_flags_then_field", repeat_in_flags_then_field},
    {"construct_repeat_in_group_then_field", repeat_in_group_then_field},
    {"construct_repeat_then_repeat", repeat_then_repeat},
    {"construct_repeat_then_exclusive_when", repeat_then_exclusive_when},
    {"construct_repeat_in_list_element", repeat_in_list_element},
    {"construct_repeat_in_dict_element", repeat_in_dict_element},
    {"construct_repeat_in_times_round", repeat_in_times_round},
};

}  // namespace hostile_repeat_last
