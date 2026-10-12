// Loop 20 review fixes (C1, C2, C3) for the hold and late links in order.hpp and pack.cpp.
// C2: a `bits`, `packed` or `sized` count that is set in the row but sits behind a clear `when`
// is never written, so the member is refused naming it, as a `times` is (AZ-2357); with the
// `when` true the bytes are unchanged. C1: a late `when` or `times` nested in a `when` or `flags`
// inside a flag bit is refused like a direct one; a nested one under a `when` that does not
// match writes nothing and still packs. C3: a `times` inside the very `when` that holds its count
// needs no hold link, so the 255-entry limit does not apply to it. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstddef>
#include <cstdint>
#include <string>
#include <utility>

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time in a function this size (see source_kinds_host_tests.cpp); the suppression
// covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

using member_cases::pack_refused;
using member_cases::round_trip;
using member_cases::same_opt;
using packbin::Array;
using packbin::Blob;
using packbin::Opt;
namespace pb = packbin;

namespace {

void packs_to(pb::Result p, std::uint8_t const* buf, char const* hex, char const* name) {
  check::expect(p.ok() && check::same_hex(buf, p.offset, hex), name);
}

// C2: u8 mode; when(mode == 1) { u8 c }; <counted member>(count c).
struct Held {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> c;
  Array<std::uint8_t, 8> list;
  Blob<8> payload;

  bool same_as(Held const& o) const {
    if (!same_opt(mode, o.mode) || !same_opt(c, o.c) || list.count != o.list.count ||
        payload.len != o.payload.len)
      return false;
    for (std::size_t i = 0; i < list.count; ++i)
      if (list.items[i] != o.list.items[i])
        return false;
    for (std::size_t i = 0; i < payload.len; ++i)
      if (payload.data[i] != o.payload.data[i])
        return false;
    return true;
  }
};

Held held(int mode, int c) {
  Held h;
  h.mode = static_cast<std::uint8_t>(mode);
  h.c = static_cast<std::uint8_t>(c);
  return h;
}

Held with_list(Held h, std::initializer_list<int> values) {
  for (int v : values)
    h.list.items[h.list.count++] = static_cast<std::uint8_t>(v);
  return h;
}

Held with_payload(Held h, char const* text, std::size_t n) {
  for (std::size_t i = 0; i < n; ++i)
    h.payload.data[i] = static_cast<std::uint8_t>(text[i]);
  h.payload.len = static_cast<std::uint16_t>(n);
  return h;
}

auto bits_behind_when() {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)),
                          pb::bits<&Held::list>(2, 1));
}

auto packed_behind_when() {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)),
                          pb::packed<&Held::list>(2, 2, 1));
}

auto sized_behind_when() {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)),
                          pb::sized<&Held::payload>(2, 1));
}

void c2_count_behind_a_clear_when_is_refused() {
  pack_refused(bits_behind_when(), with_list(held(0, 3), {1, 0, 1}), 2,
               "C2 bits, count behind a clear when");
  pack_refused(packed_behind_when(), with_list(held(0, 3), {1, 2, 3}), 2,
               "C2 packed, count behind a clear when");
  pack_refused(sized_behind_when(), with_payload(held(0, 3), "uav", 3), 2,
               "C2 sized, count behind a clear when");
}

void c2_count_behind_a_true_when_is_unchanged() {
  round_trip(bits_behind_when(), with_list(held(1, 3), {1, 0, 1}), "01010305", "C2 bits, when true");
  round_trip(packed_behind_when(), with_list(held(1, 3), {1, 2, 3}), "01010339",
             "C2 packed, when true");
  round_trip(sized_behind_when(), with_payload(held(1, 3), "uav", 3), "010103756176",
             "C2 sized, when true");
  // No count at all (the field is absent) was refused before and still is.
  Held none;
  none.mode = 0;
  pack_refused(bits_behind_when(), none, 2, "C2 bits, count absent");
}

// The count sits in the same `when` as the counted member: the condition holds whenever the
// member is reached, so nothing is held back.
void c2_count_and_member_in_the_same_when_pack() {
  auto s = pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                            pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1),
                                     pb::bits<&Held::list>(2, 1)));
  round_trip(s, with_list(held(1, 3), {1, 0, 1}), "01010305", "C2 bits in the holding when");
  Held off;
  off.mode = 0;
  round_trip(s, off, "0100", "C2 holding when false, nothing written");
}

// C2: a `when` nested in a `when` that holds the count: the inner one is clear.
void c2_count_behind_a_nested_clear_when_is_refused() {
  auto s = pb::scheme<Held>(
      1, pb::u8<&Held::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1))),
      pb::bits<&Held::list>(2, 1));
  pack_refused(s, with_list(held(0, 2), {1, 1}), 2, "C2 bits, count behind two whens, clear");
  round_trip(s, with_list(held(1, 2), {1, 1}), "01010203", "C2 bits, count behind two whens, true");
}

// AZ-2410 (U11): TypeScript refuses a bits, packed or sized member with NO value whose count is
// set in the row but never written (the `when` is clear) in a split bit and in a combined
// `flags`, and packs a clear bit for count 0 and for a left-out count. A typed C++ row cannot
// say "no value": the Array and the Blob are always there, so the bit is always set and the
// walk reaches the member, whose count is not written. C++ therefore refuses every such row
// (an empty member here, so the nearest analog of "no value"), including count 0 and a left-out
// count, which TypeScript packs as 010000. Pinned as observed; nothing to align in the
// source.
template <typename Member>
auto split_bit_scheme(Member const& m) {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)), pb::flag_byte(0),
                          pb::flag_bit(0, m));
}

template <typename Member>
auto combined_flags_scheme(Member const& m) {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)), pb::flags(2, m));
}

template <typename S>
void no_value_rows_are_refused(S const& s, char const* name) {
  std::string at = name;
  for (int c : {3, 4, 1, 0})
    pack_refused(s, held(0, c), 2, (at + " no value, count " + std::to_string(c)).c_str());
  Held none;
  none.mode = 0;
  pack_refused(s, none, 2, (at + " no value, count absent").c_str());
}

void az2410_no_value_count_behind_a_clear_when() {
  no_value_rows_are_refused(split_bit_scheme(pb::bits<&Held::list>(2, 1)), "AZ-2410 bits split");
  no_value_rows_are_refused(split_bit_scheme(pb::packed<&Held::list>(1, 2, 1)),
                            "AZ-2410 packed split");
  no_value_rows_are_refused(split_bit_scheme(pb::sized<&Held::payload>(2, 1)),
                            "AZ-2410 sized split");
  no_value_rows_are_refused(combined_flags_scheme(pb::bits<&Held::list>(2, 1)),
                            "AZ-2410 bits flags");
  no_value_rows_are_refused(combined_flags_scheme(pb::packed<&Held::list>(1, 2, 1)),
                            "AZ-2410 packed flags");
  no_value_rows_are_refused(combined_flags_scheme(pb::sized<&Held::payload>(2, 1)),
                            "AZ-2410 sized flags");
}

// Rows 53 to 55: a value with the count behind a clear `when` is refused; with the `when` true
// the bytes are those of loop 21.
void az2410_value_rows_are_unchanged() {
  auto sb = split_bit_scheme(pb::bits<&Held::list>(2, 1));
  pack_refused(sb, with_list(held(0, 3), {1, 0, 1}), 2, "AZ-2410 row 53 bits split");
  round_trip(sb, with_list(held(1, 3), {1, 0, 1}), "0101030105", "AZ-2410 row 54 bits split");
  auto sp = combined_flags_scheme(pb::packed<&Held::list>(1, 2, 1));
  pack_refused(sp, with_list(held(0, 3), {1, 0, 1}), 2, "AZ-2410 row 53 packed flags");
  round_trip(sp, with_list(held(1, 3), {1, 0, 1}), "0101030105", "AZ-2410 row 54 packed flags");
  auto ss = split_bit_scheme(pb::sized<&Held::payload>(2, 1));
  pack_refused(ss, with_payload(held(0, 3), "\1\2\3", 3), 2, "AZ-2410 row 53 sized split");
  round_trip(ss, with_payload(held(1, 3), "\1\2\3", 3), "01010301010203",
             "AZ-2410 row 55 sized split");
}

// C1: the nested late bodies. `a` sits before the flag byte, `b` and `n` after it.
struct Nested {
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
  Opt<std::uint8_t> x;

  bool same_as(Nested const& o) const {
    return same_opt(a, o.a) && same_opt(b, o.b) && same_opt(x, o.x);
  }
};

Nested nested(int a, int b, int x) {
  Nested r;
  r.a = static_cast<std::uint8_t>(a);
  r.b = static_cast<std::uint8_t>(b);
  if (x >= 0)
    r.x = static_cast<std::uint8_t>(x);
  return r;
}

// u8 a; flag_byte; u8 b; bit(when(a == 1) { when(b == 1) { u8 x } }): `b` is written after the
// byte, so the inner `when` is decided after the bit was.
auto when_in_when() {
  return pb::scheme<Nested>(1, pb::u8<&Nested::a>(0), pb::flag_byte(0), pb::u8<&Nested::b>(1),
                            pb::flag_bit(0, pb::when(2, pb::eq(0, 1),
                                                     pb::when(2, pb::eq(1, 1),
                                                              pb::u8<&Nested::x>(2)))));
}

void c1_late_when_in_a_when_is_refused() {
  auto s = when_in_when();
  pack_refused(s, nested(1, 1, 9), 2, "C1 nested late when, body given");
  std::uint8_t buf[16];
  packs_to(pb::pack(s, nested(1, 1, -1), buf, sizeof(buf)), buf, "01010001",
           "C1 nested late when, no body, packs");
  packs_to(pb::pack(s, nested(1, 0, 9), buf, sizeof(buf)), buf, "01010000",
           "C1 nested late when, inner condition false, packs");
  // The outer condition is false: the body is never written, the late source is no reason to
  // refuse (the row packed before and TypeScript accepts it).
  packs_to(pb::pack(s, nested(0, 1, 9), buf, sizeof(buf)), buf, "01000001",
           "C1 nested late when, outer condition false, packs");
  round_trip(s, nested(0, 1, -1), "01000001", "C1 nested late when, nothing given");
}

struct Modal {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> a;

  bool same_as(Modal const& o) const { return same_opt(mode, o.mode) && same_opt(a, o.a); }
};

// flag_byte; u8 mode; bit(flags(when(mode == 1) { u8 a })).
auto flags_in_bit() {
  return pb::scheme<Modal>(1, pb::flag_byte(0), pb::u8<&Modal::mode>(0),
                           pb::flag_bit(0, pb::flags(1, pb::when(1, pb::eq(0, 1),
                                                                 pb::u8<&Modal::a>(1)))));
}

void c1_late_when_in_flags_is_refused() {
  auto s = flags_in_bit();
  Modal on;
  on.mode = 1;
  on.a = 9;
  pack_refused(s, on, 1, "C1 late when in flags in a bit, body given");
  Modal bare;
  bare.mode = 1;
  std::uint8_t buf[16];
  packs_to(pb::pack(s, bare, buf, sizeof(buf)), buf, "010001", "C1 late when in flags, no body");
  Modal off;
  off.mode = 0;
  off.a = 9;
  packs_to(pb::pack(s, off, buf, sizeof(buf)), buf, "010000",
           "C1 late when in flags, condition false, packs");
}

struct Item {
  Opt<std::uint8_t> pt;
};

struct Rounds {
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> n;
  Array<Item, 4> rounds;

  bool same_as(Rounds const& o) const {
    if (!same_opt(a, o.a) || !same_opt(n, o.n) || rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i)
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt))
        return false;
    return true;
  }
};

Rounds rounds(int a, int n, std::initializer_list<int> pts) {
  Rounds r;
  r.a = static_cast<std::uint8_t>(a);
  r.n = static_cast<std::uint8_t>(n);
  for (int p : pts)
    r.rounds.items[r.rounds.count++].pt = static_cast<std::uint8_t>(p);
  return r;
}

// u8 a; flag_byte; u8 n; bit(when(a == 1) { times(n) { u8 pt } }).
auto times_in_when() {
  return pb::scheme<Rounds>(
      1, pb::u8<&Rounds::a>(0), pb::flag_byte(0), pb::u8<&Rounds::n>(1),
      pb::flag_bit(0, pb::when(2, pb::eq(0, 1),
                               pb::times<&Rounds::rounds>(2, 1, pb::u8<&Item::pt>(2)))));
}

void c1_late_times_in_a_when_is_refused() {
  auto s = times_in_when();
  pack_refused(s, rounds(1, 2, {5, 6}), 2, "C1 late times in a when, rounds given");
  round_trip(s, rounds(1, 0, {}), "01010000", "C1 late times in a when, count 0, no rounds");
  std::uint8_t buf[16];
  packs_to(pb::pack(s, rounds(0, 2, {5, 6}), buf, sizeof(buf)), buf, "01000002",
           "C1 late times under a false when, packs");
}

// C3: when(mode == 1) { K fillers; u8 n; times(n) { u8 pt } }: the times sits inside the `when`
// that holds its count, so there is no entry limit.
struct Inside {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> n;
  Array<Item, 4> rounds;
};

template <std::size_t... Is>
auto times_in_holding_when(std::index_sequence<Is...>) {
  constexpr int k = static_cast<int>(sizeof...(Is));
  return pb::scheme<Inside>(
      1, pb::u8<&Inside::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u8(1 + static_cast<int>(Is))..., pb::u8<&Inside::n>(1 + k),
               pb::times<&Inside::rounds>(2 + k, 1 + k, pb::u8<&Item::pt>(2 + k))));
}

void c3_times_inside_the_holding_when_has_no_limit() {
  auto s = times_in_holding_when(std::make_index_sequence<300>());
  check::expect(pb::validate(s).ok(), "C3 300 entries between the when and the count builds");
  Inside off;
  off.mode = 0;
  std::uint8_t buf[16];
  packs_to(pb::pack(s, off, buf, sizeof(buf)), buf, "0100", "C3 holding when false packs");
  // The same shape with no fillers: the count and its round pack with the `when` true.
  auto small = times_in_holding_when(std::make_index_sequence<0>());
  Inside on;
  on.mode = 1;
  on.n = 1;
  on.rounds.items[0].pt = 5;
  on.rounds.count = 1;
  packs_to(pb::pack(small, on, buf, sizeof(buf)), buf, "01010105", "C3 holding when true, one round");
}

}  // namespace

int run_core_held_count_nested_late_host_tests() {
  c2_count_behind_a_clear_when_is_refused();
  c2_count_behind_a_true_when_is_unchanged();
  c2_count_and_member_in_the_same_when_pack();
  c2_count_behind_a_nested_clear_when_is_refused();
  az2410_no_value_count_behind_a_clear_when();
  az2410_value_rows_are_unchanged();
  c1_late_when_in_a_when_is_refused();
  c1_late_when_in_flags_is_refused();
  c1_late_times_in_a_when_is_refused();
  c3_times_inside_the_holding_when_has_no_limit();
  return check::failures();
}
