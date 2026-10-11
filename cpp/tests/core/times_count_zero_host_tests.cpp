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

// AZ-2356: the split form, the count written after the flag byte. Count 0 with a list of values
// is refused naming the times; count 0 with a lone scalar packs zero rounds (the byte and the
// count only), the same bytes as with no value.
void az2356_split_count_zero_after_the_byte() {
  auto s = pb::scheme<Row>(1, pb::flag_byte(0), pb::u8<&Row::n>(0),
                           pb::flag_bit(0, pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))));
  pack_refused(s, row(0, 2), 1, "AZ-2356 AC-1 split count 0 after the byte, values [5, 6]");
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

}  // namespace

int run_core_times_count_zero_host_tests() {
  ac1_count_zero_with_a_value_is_refused();
  ac2_count_zero_without_values_packs();
  a_lone_value_with_count_zero_is_unchanged();
  az2356_split_count_zero_after_the_byte();
  return check::failures();
}
