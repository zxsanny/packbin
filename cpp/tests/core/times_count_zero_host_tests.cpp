// AZ-2335: a `times` count of 0 with values given for its rounds is refused naming the member,
// outside `flags` (here), inside it and in a flag bit (flags_times_repeat_member_host_tests.cpp);
// count 0 with no values packs no round. A `times` without a bound Array holds one lone value
// per round: with count 0 it writes nothing and the value is not looked at (unchanged). AZ-2356:
// the same rules in the split form with the count written after the flag byte. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstdint>

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
  std::uint8_t n = 0;
  Array<Item, 4> rounds;

  bool same_as(Row const& o) const {
    if (n != o.n || rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i)
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt))
        return false;
    return true;
  }
};

Row row(int n, int listed) {
  Row r;
  r.n = static_cast<std::uint8_t>(n);
  for (int i = 0; i < listed; ++i)
    r.rounds.items[i].pt = static_cast<std::uint8_t>(5 + i);
  r.rounds.count = static_cast<std::uint16_t>(listed);
  return r;
}

// u8 n; times(n) { u8 pt }
auto plain() {
  return pb::scheme<Row>(1, pb::u8<&Row::n>(0),
                         pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1)));
}

void ac1_count_zero_with_a_value_is_refused() {
  auto s = plain();
  pack_refused(s, row(0, 1), 1, "AC-1 count 0, one value");
  pack_refused(s, row(0, 3), 1, "AC-1 count 0, three values");
}

void ac2_count_zero_without_values_packs() {
  auto s = plain();
  round_trip(s, row(0, 0), "0100", "AC-2 count 0, no values");
  round_trip(s, row(1, 1), "010105", "AC-2 count 1, one value (unchanged)");
}

// A lone value: the `times` binds no Array, so the body value sits in the row itself.
struct Lone {
  std::uint8_t n = 0;
  Opt<std::uint8_t> pt;
};

void a_lone_value_with_count_zero_is_unchanged() {
  auto s = pb::scheme<Lone>(1, pb::u8<&Lone::n>(0),
                            pb::times(1, 0, pb::u8<&Lone::pt>(1)));
  std::uint8_t buf[16];
  Lone zero;
  zero.pt = 5;
  auto p = pb::pack(s, zero, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100"),
                "lone value with count 0 packs the count only");
  Lone two;
  two.n = 2;
  two.pt = 5;
  pack_refused(s, two, 1, "lone value with count 2 is refused");
}

// A bit body of `group { x; times }`: `x` sets the bit by a member that is not late, so the late
// rule (the bit decided where the byte is read, before `n` exists) cannot refuse the row, and any
// refusal of it is by the count rule alone.
struct GroupRow {
  Opt<std::uint8_t> x;
  std::uint8_t n = 0;
  Array<Item, 4> rounds;

  bool same_as(GroupRow const& o) const {
    if (!same_opt(x, o.x) || n != o.n || rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i)
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt))
        return false;
    return true;
  }
};

GroupRow group_row(int n, int listed) {
  GroupRow r;
  r.x = 1;
  r.n = static_cast<std::uint8_t>(n);
  for (int i = 0; i < listed; ++i)
    r.rounds.items[i].pt = static_cast<std::uint8_t>(5 + i);
  r.rounds.count = static_cast<std::uint16_t>(listed);
  return r;
}

// AZ-2356: the split form, the count written after the flag byte. Count 0 with a list of values
// is refused naming the times; count 0 with a lone scalar packs zero rounds (the byte and the
// count only), the same bytes as with no value. The count-0 refusal is pinned with `x` given
// (GroupRow), so the count rule refuses it and not the late rule; without `x` the late rule
// refuses the same row first (late_source_host_tests.cpp).
void az2356_split_count_zero_after_the_byte() {
  auto g = pb::scheme<GroupRow>(
      1, pb::flag_byte(0), pb::u8<&GroupRow::n>(0),
      pb::flag_bit(0, pb::group(1, pb::u8<&GroupRow::x>(1),
                                pb::times<&GroupRow::rounds>(2, 0, pb::u8<&Item::pt>(2)))));
  pack_refused(g, group_row(0, 2), 2, "AZ-2356 AC-1 split count 0 after the byte, values [5, 6]");
  // The late rule does not fire in this scheme: the same shape packs once the count matches.
  round_trip(g, group_row(2, 2), "010102010506", "AZ-2356 group with x, count 2 and two values");
  round_trip(g, group_row(0, 0), "01010001", "AZ-2356 group with x, count 0, no values");

  auto s = pb::scheme<Row>(1, pb::flag_byte(0), pb::u8<&Row::n>(0),
                           pb::flag_bit(0, pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))));
  round_trip(s, row(0, 0), "010000", "AZ-2356 split count 0 after the byte, no values");

  auto lone = pb::scheme<Lone>(1, pb::flag_byte(0), pb::u8<&Lone::n>(0),
                               pb::flag_bit(0, pb::times(1, 0, pb::u8<&Lone::pt>(1))));
  std::uint8_t buf[16];
  Lone scalar;
  scalar.pt = 5;
  auto p = pb::pack(lone, scalar, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "010000"),
                "AZ-2356 AC-2 split count 0 after the byte, lone scalar: zero rounds");
  auto q = pb::pack(lone, Lone{}, buf, sizeof(buf));
  check::expect(q.ok() && check::same_hex(buf, q.offset, "010000"),
                "AZ-2356 split count 0 after the byte, no scalar: same bytes");
}

// AZ-2390: a `times` or `repeat` with no member writes nothing, so the scheme is refused at
// construction (SchemeInvalid naming the member); a one-member body is unchanged.
bool refused_at(pb::Result v, int field) {
  return v.error == pb::Error::SchemeInvalid && v.field == field;
}

void az2390_empty_round_body_is_refused_at_construction() {
  auto empty_times = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::times(1, 0));
  check::expect(refused_at(pb::validate(empty_times), 1), "AZ-2390 AC-1 empty times");
  auto empty_repeat = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::repeat(1));
  check::expect(refused_at(pb::validate(empty_repeat), 1), "AZ-2390 AC-1 empty repeat");
  auto in_when = pb::scheme<Row>(1, pb::u8<&Row::n>(0),
                                 pb::when(1, pb::eq(0, 1), pb::times(1, 0)));
  check::expect(refused_at(pb::validate(in_when), 1), "AZ-2390 AC-1 empty times inside a when");
  auto bound = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::times<&Row::rounds>(1, 0));
  check::expect(refused_at(pb::validate(bound), 1), "AZ-2390 AC-1 empty bound times");
  std::uint8_t buf[16];
  auto p = pb::pack(empty_times, row(2, 0), buf, sizeof(buf));
  check::expect(p.error == pb::Error::SchemeInvalid, "AZ-2390 AC-2 pack of an empty round fails");
  check::expect(pb::validate(plain()).ok(), "AZ-2390 AC-3 one-member body builds");
}

}  // namespace

int run_core_times_count_zero_host_tests() {
  ac1_count_zero_with_a_value_is_refused();
  ac2_count_zero_without_values_packs();
  a_lone_value_with_count_zero_is_unchanged();
  az2356_split_count_zero_after_the_byte();
  az2390_empty_round_body_is_refused_at_construction();
  return check::failures();
}
