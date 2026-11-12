// AZ-4219 (contract repeat-last.md 1.0.1): a repeat is the last thing a packet reads. It has no
// count on the wire, so unpack reads rounds until the packet ends; a scheme that writes a byte
// after a repeat, or holds a repeat inside a list or dict element or inside a repeat or times
// round, is SchemeInvalid when it is checked: at the id of the first entry after the repeat that
// can write a byte (a flag byte, list or dict has no id: -1), or at the id of the repeat inside an
// element or a round. The rules that refused a scheme before run first and keep their answer.
// The constant form of R1 to R9 is tests/compile-fail/repeat_*.cpp (a compile error naming the
// same id); the constant form of K1 to K5 is here. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time (see source_kinds_host_tests.cpp); the suppression covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

using packbin::Array;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Round {
  std::uint8_t v = 0;
};

struct Row {
  std::uint8_t k = 0;
  std::uint8_t x = 0;
  Opt<std::uint8_t> ox;
  Opt<bool> on;
  Array<Round, 4> rounds;
  Array<Round, 4> more;
};

// A round that holds rounds of its own, and the row of a list or dict bound to a member.
struct Outer {
  std::uint8_t n = 0;
  Array<Round, 4> inner;
};

struct Nested {
  std::uint8_t k = 0;
  std::uint8_t x = 0;
  Array<Outer, 4> outer;
};

struct Lists {
  Array<Round, 4> items;
  Array<pb::Entry<Round, pb::Text<4>>, 4> entries;
};

// The whole refusal: SchemeInvalid, the order id, no offset and nothing needed.
bool refused_at(pb::Result r, int field) {
  return r.error == pb::Error::SchemeInvalid && r.field == field && r.offset == 0 && r.needed == 0;
}

// The repeat of every case: one u8 a round, anchored at `id`.
constexpr auto rounds(int id) { return pb::repeat<&Row::rounds>(id, pb::u8<&Round::v>(id)); }

// The element row of R7 and R8, written unbound: mode; repeat { v }.
constexpr auto element() { return pb::group(0, pb::u8(0), pb::repeat(1, pb::u8(1))); }

// --- AC-1: R1 to R6, a field that can write a byte follows the repeat ---------------------------

void r1_to_r6_are_refused_at_the_first_field_after_the_repeat() {
  // Arrange
  auto r1 = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1));
  auto r2 = pb::scheme<Row>(1, pb::u8<&Row::k>(0), pb::when(1, pb::eq(0, 1), rounds(1)),
                            pb::u8<&Row::x>(2));
  auto r3 = pb::scheme<Row>(1, pb::flags(0, rounds(0)), pb::u8<&Row::x>(1));
  auto r4 = pb::scheme<Row>(1, pb::group(0, rounds(0)), pb::u8<&Row::x>(1));
  auto r5 = pb::scheme<Row>(1, rounds(0), pb::repeat<&Row::more>(1, pb::u8<&Round::v>(1)));
  auto r6 = pb::scheme<Row>(1, pb::u8<&Row::k>(0), pb::when(1, pb::eq(0, 1), rounds(1)),
                            pb::when(2, pb::eq(0, 2), pb::u8<&Row::x>(2)));

  // Act
  pb::Result v1 = pb::validate(r1), v2 = pb::validate(r2), v3 = pb::validate(r3);
  pb::Result v4 = pb::validate(r4), v5 = pb::validate(r5), v6 = pb::validate(r6);

  // Assert
  check::expect(refused_at(v1, 1), "AZ-4219 AC-1 R1 repeat, x: refused at x");
  check::expect(refused_at(v2, 2), "AZ-4219 AC-1 R2 when { repeat }, x: refused at x");
  check::expect(refused_at(v3, 1), "AZ-4219 AC-1 R3 flags { repeat }, x: refused at x");
  check::expect(refused_at(v4, 1), "AZ-4219 AC-1 R4 group { repeat }, x: refused at x");
  check::expect(refused_at(v5, 1), "AZ-4219 AC-1 R5 repeat, repeat: refused at the member w");
  check::expect(refused_at(v6, 2), "AZ-4219 AC-1 R6 exclusive when: refused at x");
}

void refused_scheme_packs_and_unpacks_nothing() {
  // Arrange: R1 with the row and the packet it packed before the rule (01 05 06 09).
  auto s = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1));
  Row row;
  row.x = 9;
  row.rounds.count = 2;
  row.rounds.items[0].v = 5;
  row.rounds.items[1].v = 6;
  std::uint8_t out[8];
  std::memset(out, 0xEE, sizeof(out));
  std::uint8_t const packet[] = {0x01, 0x05, 0x06, 0x09};
  Row back;
  back.x = 77;

  // Act
  pb::Result p = pb::pack(s, row, out, sizeof(out));
  pb::Result u = pb::unpack(s, packet, sizeof(packet), back);

  // Assert
  bool untouched = true;
  for (std::uint8_t b : out)
    untouched = untouched && b == 0xEE;
  check::expect(refused_at(p, 1) && untouched, "AZ-4219 AC-1 pack refuses and writes no byte");
  check::expect(refused_at(u, 1) && back.x == 77 && back.rounds.count == 0,
                "AZ-4219 AC-1 unpack refuses and reads nothing");
}

// `node` (order id 2) after `k` (id 0, a count and `when` source) and a repeat (id 1).
template <typename Node>
pb::Result after_repeat(Node const& node) {
  return pb::validate(pb::scheme<Row>(1, pb::u8<&Row::k>(0), rounds(1), node));
}

void every_kind_that_writes_a_byte_is_refused_after_a_repeat() {
  // Arrange / Act
  pb::Result const with_id[] = {
      after_repeat(pb::u8(2)), after_repeat(pb::u16(2)), after_repeat(pb::u32(2)),
      after_repeat(pb::u64(2)), after_repeat(pb::i8(2)), after_repeat(pb::i16(2)),
      after_repeat(pb::i32(2)), after_repeat(pb::i64(2)), after_repeat(pb::f32(2)),
      after_repeat(pb::f64(2)), after_repeat(pb::bytes(2, 1)), after_repeat(pb::utf8(2)),
      after_repeat(pb::sized(2, 0)), after_repeat(pb::bits(2, 0)),
      after_repeat(pb::packed(1, 2, 0)), after_repeat(pb::u2(pb::u8(2))),
      after_repeat(pb::flags(2, pb::u8(2))), after_repeat(pb::times(2, 0, pb::u8(2))),
      after_repeat(pb::group(2, pb::when(2, pb::eq(0, 1), pb::u8(2)))),
      // A bit of a flag byte that stands before the repeat, on a field after it.
      pb::validate(pb::scheme<Row>(1, pb::flag_byte(0), pb::u8<&Row::k>(0), rounds(1),
                                   pb::flag_bit(0, pb::u8<&Row::ox>(2))))};
  pb::Result const without_id[] = {after_repeat(pb::flag_byte(0)),
                                   after_repeat(pb::list(pb::u8(0))),
                                   after_repeat(pb::dict(pb::u8(0)))};

  // Assert
  bool named = true;
  for (pb::Result const& r : with_id)
    named = named && refused_at(r, 2);
  bool unnamed = true;
  for (pb::Result const& r : without_id)
    unnamed = unnamed && refused_at(r, -1);
  check::expect(named, "AZ-4219 AC-1 a field after a repeat is refused at its id, of any kind");
  check::expect(unnamed, "AZ-4219 AC-1 a flag byte, list or dict after a repeat is refused at -1");
}

void field_that_writes_no_byte_may_follow_a_repeat() {
  // Arrange / Act: a zero-width bytes, alone and under a group, a when, a times and a repeat.
  pb::Result const built[] = {
      after_repeat(pb::bytes(2, 0)), after_repeat(pb::group(2, pb::bytes(2, 0))),
      after_repeat(pb::when(2, pb::eq(0, 1), pb::bytes(2, 0))),
      after_repeat(pb::times(2, 0, pb::bytes(2, 0))), after_repeat(pb::repeat(2, pb::bytes(2, 0)))};

  // Assert
  bool ok = true;
  for (pb::Result const& r : built)
    ok = ok && r.ok();
  check::expect(ok, "AZ-4219 AC-1 a zero-width bytes after a repeat builds");
}

void first_writer_in_the_nearest_place_is_named() {
  // Arrange
  auto same_place = pb::scheme<Row>(1, pb::flags(0, rounds(0), pb::u8<&Row::ox>(1)),
                                    pb::u8<&Row::x>(2));
  auto past_silent = pb::scheme<Row>(1, rounds(0), pb::bytes(1, 0), pb::u8<&Row::x>(2),
                                     pb::u8<&Row::k>(3));
  auto in_element_too = pb::scheme<Row>(
      1, pb::list(pb::group(0, pb::u8(0), pb::repeat(1, pb::u8(1)), pb::u8(2))), pb::u8(0));

  // Act
  pb::Result a = pb::validate(same_place), b = pb::validate(past_silent);
  pb::Result c = pb::validate(in_element_too);

  // Assert
  check::expect(refused_at(a, 1), "AZ-4219 AC-1 the nearest: the member after the repeat in flags");
  check::expect(refused_at(b, 2), "AZ-4219 AC-1 the first field that writes, past a 0-width bytes");
  check::expect(refused_at(c, 1), "AZ-4219 AC-5 a repeat in an element, a field after it: repeat");
}

void rules_that_refused_before_keep_their_answer() {
  // Arrange: each scheme also has `x` (id 1) after the repeat, which this rule would name.
  auto order = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1), pb::u8<&Row::k>(3));
  auto shape = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1), pb::boolean<&Row::on>(2));
  auto reference = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1),
                                   pb::when(2, pb::eq(5, 1), pb::u8<&Row::k>(2)));
  auto empty_round = pb::scheme<Row>(1, rounds(0), pb::u8<&Row::x>(1), pb::repeat(2));

  // Act
  pb::Result a = pb::validate(order), b = pb::validate(shape);
  pb::Result c = pb::validate(reference), d = pb::validate(empty_round);

  // Assert
  check::expect(refused_at(a, 3), "AZ-4219 AC-1 a skipped id is refused first, at its id");
  check::expect(refused_at(b, 2), "AZ-4219 AC-1 a bool outside flags is refused first, at its id");
  check::expect(refused_at(c, 2), "AZ-4219 AC-1 a when with no source is refused first, at its id");
  check::expect(refused_at(d, 2), "AZ-4219 AC-1 an empty round is refused first, at its id");
}

// --- AC-2: K1 to K5 build and pack the bytes of the contract, as a constant and at run time -----

constexpr auto k1() { return pb::scheme<Row>(1, pb::u8<&Row::x>(0), rounds(1)); }
constexpr auto k2() {
  return pb::scheme<Row>(1, pb::u8<&Row::k>(0), pb::when(1, pb::eq(0, 1), rounds(1)));
}
constexpr auto k3() { return pb::scheme<Row>(1, pb::flags(0, pb::u8<&Row::ox>(0), rounds(1))); }
constexpr auto k4() {
  return pb::scheme<Row>(1, pb::u8<&Row::k>(0),
                         pb::times<&Row::rounds>(1, 0, pb::u8<&Round::v>(1)), pb::u8<&Row::x>(2));
}
constexpr auto k5() {
  return pb::scheme<Row>(1, pb::flag_byte(0), pb::flag_bit(0, pb::u8<&Row::ox>(0)), rounds(1),
                         pb::flag_bit(0, pb::boolean<&Row::on>(2)));
}
// Not in the contract: a bool member of `flags` after the repeat is a bit of the byte before it.
constexpr auto bool_after() {
  return pb::scheme<Row>(1, pb::flags(0, pb::u8<&Row::ox>(0), rounds(1), pb::boolean<&Row::on>(2)));
}

constexpr auto kK1 = k1();
constexpr auto kK2 = k2();
constexpr auto kK3 = k3();
constexpr auto kK4 = k4();
constexpr auto kK5 = k5();
constexpr auto kBoolAfter = bool_after();
static_assert(pb::validate(kK1).ok() && pb::validate(kK2).ok() && pb::validate(kK3).ok() &&
                  pb::validate(kK4).ok() && pb::validate(kK5).ok() && pb::validate(kBoolAfter).ok(),
              "AZ-4219 AC-2: K1 to K5 build as constants");

// The rounds 5 and 6 beside the values a case gives.
Row values(int k, int x, bool optional_x, bool on) {
  Row row;
  row.k = static_cast<std::uint8_t>(k);
  if (optional_x)
    row.ox = static_cast<std::uint8_t>(x);
  else
    row.x = static_cast<std::uint8_t>(x);
  if (on)
    row.on = true;
  row.rounds.count = 2;
  row.rounds.items[0].v = 5;
  row.rounds.items[1].v = 6;
  return row;
}

bool same(Row const& a, Row const& b) {
  bool rounds_same = a.rounds.count == b.rounds.count && a.more.count == b.more.count;
  for (std::size_t i = 0; rounds_same && i < a.rounds.count; ++i)
    rounds_same = a.rounds.items[i].v == b.rounds.items[i].v;
  return rounds_same && a.k == b.k && a.x == b.x && a.ox.has == b.ox.has &&
         a.ox.value == b.ox.value && a.on.has == b.on.has && a.on.value == b.on.value;
}

// True when `s` packs `row` to `hex` and reads the same values back from those bytes.
template <typename S, typename R>
bool round_trips(S const& s, R const& row, char const* hex, bool (*equal)(R const&, R const&)) {
  std::uint8_t out[16] = {};
  pb::Result p = pb::pack(s, row, out, sizeof(out));
  R back;
  return p.ok() && check::same_hex(out, p.offset, hex) && pb::unpack(s, out, p.offset, back).ok() &&
         equal(back, row);
}

void k1_to_k5_pack_the_bytes_of_the_contract() {
  // Arrange
  Row r1 = values(0, 9, false, false), r2 = values(1, 0, false, false);
  Row r3 = values(0, 9, true, false), r4 = values(2, 9, false, false);
  Row r5 = values(0, 9, true, true);
  auto run1 = k1();
  auto run2 = k2();
  auto run3 = k3();
  auto run4 = k4();
  auto run5 = k5();
  auto run6 = bool_after();

  // Act
  bool constant = round_trips(kK1, r1, "01090506", same) &&
                  round_trips(kK2, r2, "01010506", same) &&
                  round_trips(kK3, r3, "0103090506", same) &&
                  round_trips(kK4, r4, "0102050609", same) &&
                  round_trips(kK5, r5, "0103090506", same);
  bool run_time = round_trips(run1, r1, "01090506", same) &&
                  round_trips(run2, r2, "01010506", same) &&
                  round_trips(run3, r3, "0103090506", same) &&
                  round_trips(run4, r4, "0102050609", same) &&
                  round_trips(run5, r5, "0103090506", same);
  bool bit_after = round_trips(kBoolAfter, r5, "0107090506", same) &&
                   round_trips(run6, r5, "0107090506", same);

  // Assert
  check::expect(constant, "AZ-4219 AC-2 K1 to K5 as constants: the contract's packets, read back");
  check::expect(run_time, "AZ-4219 AC-2 K1 to K5 at run time: the contract's packets, read back");
  check::expect(bit_after, "AZ-4219 AC-1 a bool bit after a repeat builds and reads back");
}

// --- AC-5: a repeat inside an element or a round; a times inside a round ------------------------

void r7_r8_repeat_in_an_unbound_element_is_refused_at_the_repeat() {
  // Arrange
  auto r7 = pb::scheme<Row>(1, pb::list(element()));
  auto r8 = pb::scheme<Row>(1, pb::dict(element()));
  auto deeper = pb::scheme<Row>(
      1, pb::list(pb::dict(pb::group(0, pb::u8(0), pb::flags(1, pb::repeat(1, pb::u8(1)))))));

  // Act
  pb::Result a = pb::validate(r7), b = pb::validate(r8), c = pb::validate(deeper);

  // Assert
  check::expect(refused_at(a, 1), "AZ-4219 AC-5 R7 list(element) with a repeat: at the repeat");
  check::expect(refused_at(b, 1), "AZ-4219 AC-5 R8 dict(element) with a repeat: at the repeat");
  check::expect(refused_at(c, 1), "AZ-4219 AC-5 a repeat under flags in a dict in a list");
}

void bound_list_and_dict_keep_their_refusal_of_a_row_element() {
  // Arrange: R7 and R8 cannot be written bound; a row element is refused with or without a repeat.
  auto plain = pb::group(0, pb::u8(0), pb::u8(1));
  auto list_row = pb::scheme<Lists>(1, pb::list<&Lists::items>(plain));
  auto list_repeat = pb::scheme<Lists>(1, pb::list<&Lists::items>(element()));
  auto dict_row = pb::scheme<Lists>(1, pb::dict<&Lists::entries>(plain));
  auto dict_repeat = pb::scheme<Lists>(1, pb::dict<&Lists::entries>(element()));

  // Act
  pb::Result a = pb::validate(list_row), b = pb::validate(list_repeat);
  pb::Result c = pb::validate(dict_row), d = pb::validate(dict_repeat);

  // Assert: the element row (id 0) is named, not the repeat (id 1).
  check::expect(refused_at(a, 0) && refused_at(b, 0),
                "AZ-4219 AC-5 a bound list refuses a row element");
  check::expect(refused_at(c, 0) && refused_at(d, 0),
                "AZ-4219 AC-5 a bound dict refuses a row element");
}

void r9_repeat_in_a_round_is_refused_at_the_repeat() {
  // Arrange
  auto inner = pb::repeat<&Outer::inner>(1, pb::u8<&Round::v>(1));
  auto r9 = pb::scheme<Nested>(1, pb::u8<&Nested::k>(0), pb::times<&Nested::outer>(1, 0, inner));
  auto unbound = pb::scheme<Nested>(1, pb::u8<&Nested::k>(0),
                                    pb::times(1, 0, pb::repeat(1, pb::u8(1))));
  auto in_repeat = pb::scheme<Nested>(
      1, pb::repeat<&Nested::outer>(0, pb::repeat<&Outer::inner>(0, pb::u8<&Round::v>(0))));
  auto under_when = pb::scheme<Nested>(
      1, pb::repeat<&Nested::outer>(0, pb::u8<&Outer::n>(0), pb::when(1, pb::eq(0, 1), inner)));
  auto under_flags = pb::scheme<Nested>(1, pb::u8<&Nested::k>(0),
                                        pb::times<&Nested::outer>(1, 0, pb::flags(1, inner)));

  // Act
  pb::Result a = pb::validate(r9), b = pb::validate(unbound), c = pb::validate(in_repeat);
  pb::Result d = pb::validate(under_when), e = pb::validate(under_flags);

  // Assert
  check::expect(refused_at(a, 1), "AZ-4219 AC-5 R9 times { repeat }: refused at the repeat");
  check::expect(refused_at(b, 1), "AZ-4219 AC-5 R9 unbound: refused at the repeat");
  check::expect(refused_at(c, 0), "AZ-4219 AC-5 repeat { repeat }: refused at the inner repeat");
  check::expect(refused_at(d, 1), "AZ-4219 AC-5 a repeat under a when in a round");
  check::expect(refused_at(e, 1), "AZ-4219 AC-5 a repeat under flags in a round");
}

// A group does not hide a repeat from the round around it: the next round still follows it.
void repeat_in_a_group_in_a_round_is_refused_at_the_repeat() {
  // Arrange
  auto inner = pb::repeat<&Outer::inner>(1, pb::u8<&Round::v>(1));
  auto in_repeat = pb::scheme<Nested>(
      1, pb::repeat<&Nested::outer>(
             0, pb::group(0, pb::repeat<&Outer::inner>(0, pb::u8<&Round::v>(0)))));
  auto after_member = pb::scheme<Nested>(
      1, pb::repeat<&Nested::outer>(0, pb::u8<&Outer::n>(0), pb::group(1, inner)));
  auto in_times = pb::scheme<Nested>(1, pb::u8<&Nested::k>(0),
                                     pb::times<&Nested::outer>(1, 0, pb::group(1, inner)));
  auto unbound_repeat =
      pb::scheme<Nested>(1, pb::repeat(0, pb::group(0, pb::repeat(0, pb::u8(0)))));
  auto unbound_times = pb::scheme<Nested>(
      1, pb::u8<&Nested::k>(0), pb::times(1, 0, pb::group(1, pb::repeat(1, pb::u8(1)))));
  auto under_flags = pb::scheme<Nested>(
      1, pb::u8<&Nested::k>(0), pb::times<&Nested::outer>(1, 0, pb::flags(1, pb::group(1, inner))));
  auto group_in_group = pb::scheme<Nested>(
      1, pb::u8<&Nested::k>(0),
      pb::times<&Nested::outer>(1, 0, pb::group(1, pb::group(1, inner))));

  // Act
  pb::Result a = pb::validate(in_repeat), b = pb::validate(after_member);
  pb::Result c = pb::validate(in_times), d = pb::validate(unbound_repeat);
  pb::Result e = pb::validate(unbound_times), f = pb::validate(under_flags);
  pb::Result g = pb::validate(group_in_group);

  // Assert
  check::expect(refused_at(a, 0), "AZ-4219 AC-5 repeat { group { repeat } }: at the inner repeat");
  check::expect(refused_at(b, 1), "AZ-4219 AC-5 repeat { n, group { repeat } }: at the inner one");
  check::expect(refused_at(c, 1), "AZ-4219 AC-5 times { group { repeat } }: at the repeat");
  check::expect(refused_at(d, 0) && refused_at(e, 1), "AZ-4219 AC-5 the same two, unbound");
  check::expect(refused_at(f, 1), "AZ-4219 AC-5 times { flags { group { repeat } } }");
  check::expect(refused_at(g, 1), "AZ-4219 AC-5 times { group { group { repeat } } }");
}

bool same_nested(Nested const& a, Nested const& b) {
  bool ok = a.k == b.k && a.x == b.x && a.outer.count == b.outer.count;
  for (std::size_t i = 0; ok && i < a.outer.count; ++i) {
    Outer const& p = a.outer.items[i];
    Outer const& q = b.outer.items[i];
    ok = p.n == q.n && p.inner.count == q.inner.count;
    for (std::size_t j = 0; ok && j < p.inner.count; ++j)
      ok = p.inner.items[j].v == q.inner.items[j].v;
  }
  return ok;
}

constexpr auto counted() { return pb::times<&Outer::inner>(2, 1, pb::u8<&Round::v>(2)); }
constexpr auto kTimesInTimes = pb::scheme<Nested>(
    1, pb::u8<&Nested::k>(0), pb::times<&Nested::outer>(1, 0, pb::u8<&Outer::n>(1), counted()),
    pb::u8<&Nested::x>(3));
static_assert(pb::validate(kTimesInTimes).ok(), "AZ-4219 AC-5: a times in a times round builds");

// k; times count = k { group { c; times count = c { v } } }: the group shares the ids of the round.
constexpr auto times_in_group() {
  return pb::scheme<Nested>(
      1, pb::u8<&Nested::k>(0),
      pb::times<&Nested::outer>(
          1, 0, pb::group(1, pb::u8<&Outer::n>(1),
                          pb::times<&Outer::inner>(2, 1, pb::u8<&Round::v>(2)))));
}
constexpr auto kTimesInGroup = times_in_group();
static_assert(pb::validate(kTimesInGroup).ok(),
              "AZ-4219 AC-5: a times in a group in a times round builds");

void times_in_a_round_still_builds_and_reads_back() {
  // Arrange: two outer rounds, of two inner rounds (5, 6) and of one (7).
  auto in_repeat = pb::scheme<Nested>(
      1, pb::repeat<&Nested::outer>(
             0, pb::u8<&Outer::n>(0), pb::times<&Outer::inner>(1, 0, pb::u8<&Round::v>(1))));
  Nested row;
  row.outer.count = 2;
  row.outer.items[0].n = 2;
  row.outer.items[0].inner.count = 2;
  row.outer.items[0].inner.items[0].v = 5;
  row.outer.items[0].inner.items[1].v = 6;
  row.outer.items[1].n = 1;
  row.outer.items[1].inner.count = 1;
  row.outer.items[1].inner.items[0].v = 7;
  auto group_in_repeat = pb::scheme<Nested>(
      1, pb::repeat<&Nested::outer>(
             0, pb::group(0, pb::u8<&Outer::n>(0),
                          pb::times<&Outer::inner>(1, 0, pb::u8<&Round::v>(1)))));
  auto group_in_times = times_in_group();
  Nested counted_row = row;
  counted_row.k = 2;
  Nested with_x = counted_row;
  with_x.x = 9;

  // Act
  bool repeat_of_times = round_trips(in_repeat, row, "010205060107", same_nested);
  bool times_of_times = round_trips(kTimesInTimes, with_x, "0102020506010709", same_nested);
  bool in_group = round_trips(kTimesInGroup, counted_row, "01020205060107", same_nested) &&
                  round_trips(group_in_times, counted_row, "01020205060107", same_nested) &&
                  round_trips(group_in_repeat, row, "010205060107", same_nested);

  // Assert
  check::expect(pb::validate(in_repeat).ok() && repeat_of_times,
                "AZ-4219 AC-5 a times in a repeat round builds and reads back");
  check::expect(times_of_times, "AZ-4219 AC-5 a times in a times round, then a field, reads back");
  check::expect(in_group, "AZ-4219 AC-5 a times in a group in a round builds and reads back");
}

}  // namespace

int run_core_repeat_last_host_tests() {
  r1_to_r6_are_refused_at_the_first_field_after_the_repeat();
  refused_scheme_packs_and_unpacks_nothing();
  every_kind_that_writes_a_byte_is_refused_after_a_repeat();
  field_that_writes_no_byte_may_follow_a_repeat();
  first_writer_in_the_nearest_place_is_named();
  rules_that_refused_before_keep_their_answer();
  k1_to_k5_pack_the_bytes_of_the_contract();
  r7_r8_repeat_in_an_unbound_element_is_refused_at_the_repeat();
  bound_list_and_dict_keep_their_refusal_of_a_row_element();
  r9_repeat_in_a_round_is_refused_at_the_repeat();
  repeat_in_a_group_in_a_round_is_refused_at_the_repeat();
  times_in_a_round_still_builds_and_reads_back();
  return check::failures();
}
