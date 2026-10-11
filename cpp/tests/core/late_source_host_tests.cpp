// Loop 19 review fixes (C1, C8, C9) for the flag bit and `when` source rules in order.hpp.
// C1: a source written INSIDE the flag bit's own body is read where the body is read, so it is
// not "late" and the row packs and round-trips as before loop 19; only a source between the
// flag byte and the flag bit is late. C8: the empty-group fallback of a `when` source does not
// bind when a field of the same id exists that is not the group. C9: the "distance over 255"
// refusal of a late flag bit. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstddef>
#include <cstdint>
#include <utility>

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time in a function this size (see source_kinds_host_tests.cpp); the suppression
// covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

using member_cases::pack_refused;
using member_cases::round_trip;
using member_cases::same_opt;
using packbin::Array;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Item {
  Opt<std::uint8_t> pt;
};

struct Row {
  Opt<std::uint8_t> n;
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> x;
  Array<Item, 4> rounds;

  bool same_as(Row const& o) const {
    if (!same_opt(n, o.n) || !same_opt(mode, o.mode) || !same_opt(x, o.x) ||
        rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i)
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt))
        return false;
    return true;
  }
};

struct Presence {
  bool g = false;
  Opt<std::uint8_t> v;
};

bool refused_at(pb::Result v, int field) {
  return v.error == pb::Error::SchemeInvalid && v.field == field;
}

// C1: the count `n` and the `times` are both inside the body of the one flag bit.
void c1_count_inside_the_bit_body_packs_as_before() {
  auto s = pb::scheme<Row>(
      1, pb::flag_byte(0),
      pb::flag_bit(0, pb::group(0, pb::u8<&Row::n>(0),
                                pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1)))));
  Row r;
  r.n = 2;
  r.rounds.items[0].pt = 5;
  r.rounds.items[1].pt = 6;
  r.rounds.count = 2;
  round_trip(s, r, "0101020506", "C1 count inside the bit body, two rounds");
  Row none;
  round_trip(s, none, "0100", "C1 count inside the bit body, row empty");
  Row zero;
  zero.n = 0;
  round_trip(s, zero, "010100", "C1 count inside the bit body, count 0");
  // Hostile: the count says 2 but one round is given (differential: a mismatch is still loud).
  Row short_rounds = r;
  short_rounds.rounds.count = 1;
  pack_refused(s, short_rounds, 1, "C1 count 2 with one round is refused");
}

// C1: the `when` source `mode` is inside the body of the one flag bit.
void c1_when_source_inside_the_bit_body_packs_as_before() {
  auto s = pb::scheme<Row>(
      1, pb::flag_byte(0),
      pb::flag_bit(0, pb::group(0, pb::u8<&Row::mode>(0),
                                pb::when(1, pb::eq(0, 1), pb::u8<&Row::x>(1)))));
  Row r;
  r.mode = 1;
  r.x = 7;
  round_trip(s, r, "01010107", "C1 when source inside the bit body, true");
  Row off;
  off.mode = 0;
  round_trip(s, off, "010100", "C1 when source inside the bit body, false");
}

// The same rows with the source between the flag byte and the bit stay loud (C1 must not
// weaken the AZ-2331 rule).
void c1_source_between_byte_and_bit_stays_late() {
  auto s = pb::scheme<Row>(
      1, pb::flag_byte(0), pb::u8<&Row::n>(0),
      pb::flag_bit(0, pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))));
  Row r;
  r.n = 2;
  r.rounds.items[0].pt = 5;
  r.rounds.items[1].pt = 6;
  r.rounds.count = 2;
  pack_refused(s, r, 1, "C1 count between byte and bit stays loud");
}

// C8: the id 0 is held by an unbound u8, which is not a source; the empty group of the same id
// is not a fallback when another field has the id.
void c8_same_id_field_blocks_the_empty_group_fallback() {
  auto s = pb::scheme<Presence>(
      1, pb::flags(0, pb::group<&Presence::g>(0)), pb::u8(0),
      pb::when(1, pb::eq(0, 1), pb::u8<&Presence::v>(1)));
  check::expect(refused_at(pb::validate(s), 1), "C8 empty group is not the source of a when");
}

// C8: without the other field the empty group is still the source (AZ-2334).
void c8_empty_group_alone_is_still_the_source() {
  auto s = pb::scheme<Presence>(
      1, pb::flags(0, pb::group<&Presence::g>(0)),
      pb::when(0, pb::eq(0, true), pb::u8<&Presence::v>(0)));
  check::expect(pb::validate(s).ok(), "C8 empty group alone is still the source");
}

// C9: the bit body is `group(filler u8 x K, when)`; the `when` sits `K + 2` entries after the
// flag bit. Its source `mode` is written after the flag byte, so the bit is late.
template <std::size_t... Is>
auto long_bit(std::index_sequence<Is...>) {
  constexpr int k = static_cast<int>(sizeof...(Is));
  return pb::scheme<Row>(
      1, pb::flag_byte(0), pb::u8<&Row::mode>(0),
      pb::flag_bit(0, pb::group(1, pb::u8(1 + static_cast<int>(Is))...,
                                pb::when(1 + k, pb::eq(0, 1), pb::u8<&Row::x>(1 + k)))));
}

void c9_distance_over_255_is_refused_at_construction() {
  auto at_limit = long_bit(std::make_index_sequence<253>());
  check::expect(pb::validate(at_limit).ok(), "C9 distance 255 builds");
  Row r;
  r.mode = 1;
  r.x = 7;
  pack_refused(at_limit, r, 254, "C9 distance 255 still marks the bit late (pack refuses)");
  Row quiet;
  quiet.mode = 1;
  std::uint8_t buf[32];
  auto p = pb::pack(at_limit, quiet, buf, sizeof(buf));
  check::expect(p.ok(), "C9 distance 255, no body, packs");

  auto over = long_bit(std::make_index_sequence<254>());
  check::expect(refused_at(pb::validate(over), 255), "C9 distance 256 is SchemeInvalid at the when");
  std::uint8_t out[32] = {0xaa};
  auto q = pb::pack(over, r, out, sizeof(out));
  check::expect(q.error == pb::Error::SchemeInvalid && out[0] == 0xaa,
                "C9 distance 256, pack writes nothing");
}

}  // namespace

int run_core_late_source_host_tests() {
  c1_count_inside_the_bit_body_packs_as_before();
  c1_when_source_inside_the_bit_body_packs_as_before();
  c1_source_between_byte_and_bit_stays_late();
  c8_same_id_field_blocks_the_empty_group_fallback();
  c8_empty_group_alone_is_still_the_source();
  c9_distance_over_255_is_refused_at_construction();
  return check::failures();
}
