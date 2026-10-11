// AZ-2331: a split `flag_byte` decides the bit of a `when` or `times` where the byte is written.
// A body whose condition holds or whose count is written after the byte, or whose count is not in
// the row, would be dropped without a word; pack refuses it with BadValue naming the member (the
// order id of the `when` or `times`, which is the id of its first body value). A source written
// before the byte packs as before. A false condition with a body given (AC-3) is undecided and
// is not pinned here. Also AZ-2357 (a count set in the row behind a clear `when`) and AZ-2360
// (combined `flags`, count skipped, values given). Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstdint>

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
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> speed;
  Opt<std::uint8_t> c;
  Opt<std::uint16_t> heading;
  Array<Item, 4> rounds;

  bool same_as(Row const& o) const {
    if (!same_opt(mode, o.mode) || !same_opt(speed, o.speed) || !same_opt(c, o.c) ||
        !same_opt(heading, o.heading) || rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i)
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt))
        return false;
    return true;
  }
};

Row row(int mode, int speed, int heading) {
  Row r;
  if (mode >= 0)
    r.mode = static_cast<std::uint8_t>(mode);
  if (speed >= 0)
    r.speed = static_cast<std::uint8_t>(speed);
  if (heading >= 0)
    r.heading = static_cast<std::uint16_t>(heading);
  return r;
}

// `count` is the c member (-1 leaves it unset); `rounds` entries are pt = 5, 6, ...
Row counted(int count, int rounds, int heading) {
  Row r;
  if (count >= 0)
    r.c = static_cast<std::uint8_t>(count);
  for (int i = 0; i < rounds; ++i)
    r.rounds.items[i].pt = static_cast<std::uint8_t>(5 + i);
  r.rounds.count = static_cast<std::uint16_t>(rounds);
  if (heading >= 0)
    r.heading = static_cast<std::uint16_t>(heading);
  return r;
}

constexpr int kNone = -1;

// The `when` names `mode`, written between the flag byte and the bit.
auto when_after_byte() {
  return pb::scheme<Row>(1, pb::flag_byte(0), pb::u8<&Row::mode>(0),
                         pb::flag_bit(0, pb::when(1, pb::eq(0, 1), pb::u8<&Row::speed>(1))),
                         pb::flag_bit(0, pb::u16<&Row::heading>(2)));
}

auto when_before_byte() {
  return pb::scheme<Row>(1, pb::u8<&Row::mode>(0), pb::flag_byte(0),
                         pb::flag_bit(0, pb::when(1, pb::eq(0, 1), pb::u8<&Row::speed>(1))),
                         pb::flag_bit(0, pb::u16<&Row::heading>(2)));
}

auto group_when_after_byte() {
  return pb::scheme<Row>(
      1, pb::flag_byte(0), pb::u8<&Row::mode>(0),
      pb::flag_bit(0, pb::group(1, pb::when(1, pb::eq(0, 1), pb::u8<&Row::speed>(1)))),
      pb::flag_bit(0, pb::u16<&Row::heading>(2)));
}

auto times_after_byte() {
  return pb::scheme<Row>(
      1, pb::flag_byte(0), pb::u8<&Row::c>(0),
      pb::flag_bit(0, pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))),
      pb::flag_bit(0, pb::u16<&Row::heading>(2)));
}

auto times_before_byte() {
  return pb::scheme<Row>(
      1, pb::u8<&Row::c>(0), pb::flag_byte(0),
      pb::flag_bit(0, pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))),
      pb::flag_bit(0, pb::u16<&Row::heading>(2)));
}

// The count sits behind a `when` before the byte, so a row with mode 0 never writes it.
auto count_behind_a_when() {
  return pb::scheme<Row>(
      1, pb::u8<&Row::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&Row::c>(1)),
      pb::flag_byte(0),
      pb::flag_bit(0, pb::times<&Row::rounds>(2, 1, pb::u8<&Item::pt>(2))),
      pb::flag_bit(0, pb::u16<&Row::heading>(3)));
}

void ac1_when_source_after_the_byte() {
  auto s = when_after_byte();
  pack_refused(s, row(1, 7, 90), 1, "AC-1 when source after the byte, condition true");
  round_trip(s, row(1, kNone, 90), "0102015a00", "AC-1 when source after the byte, no body");
  auto g = group_when_after_byte();
  Row r = row(1, 7, kNone);
  pack_refused(g, r, 1, "AC-1 when in a group bit, source after the byte");
}

void ac1_times_count_after_the_byte() {
  auto s = times_after_byte();
  pack_refused(s, counted(2, 2, 90), 1, "AC-1 times count after the byte");
  round_trip(s, counted(0, 0, 90), "0102005a00", "AC-1 times count after the byte, none");
}

void ac2_count_never_written() {
  auto s = count_behind_a_when();
  Row skipped = counted(kNone, 1, 90);
  skipped.mode = 0;
  pack_refused(s, skipped, 2, "AC-2 count behind a clear when, rounds given");
  Row none = counted(kNone, 0, 90);
  none.mode = 0;
  std::uint8_t buf[16];
  auto p = pb::pack(s, none, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100025a00"),
                "AC-2 count never written, no rounds: packs");
  Row written = counted(1, 1, 90);
  written.mode = 1;
  round_trip(s, written, "01010103055a00", "AC-2 count behind a holding when");

  // In combined `flags` the count is a member whose bit is clear when the row skips it.
  auto in_flags = pb::scheme<Row>(
      1, pb::flags(0, pb::u8<&Row::c>(0),
                   pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))));
  pack_refused(in_flags, counted(kNone, 1, kNone), 1, "AC-2 flags member count skipped, rounds");
  std::uint8_t big[16];
  auto q = pb::pack(in_flags, counted(kNone, 0, kNone), big, sizeof(big));
  check::expect(q.ok() && check::same_hex(big, q.offset, "0100"),
                "AC-2 flags member count skipped, no rounds: packs");
}

// AZ-2357 (loop 19 assessment U4): the count is set in the row but sits behind a clear `when`, so
// it is never written; the rounds are refused naming the times (they packed `010003055a00`).
void count_set_behind_a_clear_when() {
  auto s = count_behind_a_when();
  Row one = counted(1, 1, 90);
  one.mode = 0;
  pack_refused(s, one, 2, "AZ-2357 AC-1 count 1 behind a clear when, one round");
  Row two = counted(2, 2, 90);
  two.mode = 0;
  pack_refused(s, two, 2, "AZ-2357 AC-1 count 2 behind a clear when, two rounds");
  Row zero = counted(0, 0, 90);
  zero.mode = 0;
  std::uint8_t buf[16];
  auto p = pb::pack(s, zero, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100025a00"),
                "AZ-2357 count 0 behind a clear when, no rounds: packs as before");

  // Nested: the outer `when` reads mode, the inner one speed; either false skips the count.
  auto nested = pb::scheme<Row>(
      1, pb::u8<&Row::mode>(0), pb::u8<&Row::speed>(1),
      pb::when(2, pb::eq(0, 1), pb::when(2, pb::eq(1, 1), pb::u8<&Row::c>(2))),
      pb::flag_byte(0),
      pb::flag_bit(0, pb::times<&Row::rounds>(3, 2, pb::u8<&Item::pt>(3))),
      pb::flag_bit(0, pb::u16<&Row::heading>(4)));
  Row outer_off = counted(1, 1, 90);
  outer_off.mode = 0;
  outer_off.speed = 1;
  pack_refused(nested, outer_off, 3, "AZ-2357 outer when false, inner true");
  Row inner_off = counted(1, 1, 90);
  inner_off.mode = 1;
  inner_off.speed = 0;
  pack_refused(nested, inner_off, 3, "AZ-2357 outer when true, inner false");
  Row both = counted(1, 1, 90);
  both.mode = 1;
  both.speed = 1;
  round_trip(nested, both, "0101010103055a00", "AZ-2357 both whens true");

  // Without a flag byte: the same rule, and a `when` that holds the times too is no obstacle.
  auto plain = pb::scheme<Row>(1, pb::u8<&Row::mode>(0),
                               pb::when(1, pb::eq(0, 1), pb::u8<&Row::c>(1)),
                               pb::times<&Row::rounds>(2, 1, pb::u8<&Item::pt>(2)));
  Row off = counted(1, 1, kNone);
  off.mode = 0;
  pack_refused(plain, off, 2, "AZ-2357 plain times, count behind a clear when");
  Row on = counted(1, 1, kNone);
  on.mode = 1;
  round_trip(plain, on, "01010105", "AZ-2357 plain times, count behind a holding when");
  auto holding = pb::scheme<Row>(
      1, pb::u8<&Row::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u8<&Row::c>(1),
               pb::times<&Row::rounds>(2, 1, pb::u8<&Item::pt>(2))));
  round_trip(holding, on, "01010105", "AZ-2357 when holds the count and the times");
}

// AZ-2360: combined `flags`, the count skipped and two values given: refused naming the times
// (the order id of pt); no values packs the clear byte as before.
void flags_skipped_count_with_values() {
  auto in_flags = pb::scheme<Row>(
      1, pb::flags(0, pb::u8<&Row::c>(0),
                   pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1))));
  pack_refused(in_flags, counted(kNone, 2, kNone), 1, "AZ-2360 AC-1 skipped count, pt [5, 6]");
  std::uint8_t buf[16];
  auto q = pb::pack(in_flags, counted(kNone, 0, kNone), buf, sizeof(buf));
  check::expect(q.ok() && check::same_hex(buf, q.offset, "0100"),
                "AZ-2360 AC-2 skipped count, no values: packs 0100");
}

void ac4_source_before_the_byte_packs_as_before() {
  auto w = when_before_byte();
  round_trip(w, row(1, 7, 90), "010103075a00", "AC-4 when source before the byte, true");
  round_trip(w, row(0, kNone, 90), "0100025a00", "AC-4 when source before the byte, false");
  round_trip(w, row(1, kNone, 90), "0101025a00", "AC-4 when source before the byte, no body");
  auto t = times_before_byte();
  round_trip(t, counted(0, 0, 90), "0100025a00", "AC-4 times count before the byte, 0");
  round_trip(t, counted(1, 1, 90), "010103055a00", "AC-4 times count before the byte, 1");
  round_trip(t, counted(2, 2, 90), "01020305065a00", "AC-4 times count before the byte, 2");
}

}  // namespace

int run_core_split_form_loud_host_tests() {
  ac1_when_source_after_the_byte();
  ac1_times_count_after_the_byte();
  ac2_count_never_written();
  ac4_source_before_the_byte_packs_as_before();
  count_set_behind_a_clear_when();
  flags_skipped_count_with_values();
  return check::failures();
}
