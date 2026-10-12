// The pack stage of fixtures/hostile/cases.txt, for the C++ host test (hostile_host_tests.cpp).
// Each handler packs the row its README section gives and answers "pack_error" when pack refuses
// (no bytes) or the packet as lowercase hex. A case a typed row cannot express is skipped, with
// the reason.

#pragma once

#include "packbin/packbin.hpp"

#include <cstdint>
#include <cstring>
#include <string>

namespace hostile_pack {

using packbin::Array;
using packbin::Opt;

using PackRun = std::string (*)();

// The result of the last pack_answer, so the loader can check which error a refusal carried.
inline packbin::Result last_result;

template <typename S, typename Row>
std::string pack_answer(S const& s, Row const& row) {
  std::uint8_t buf[32] = {};
  auto r = packbin::pack(s, row, buf, sizeof(buf));
  last_result = r;
  if (!r.ok())
    return "pack_error";
  static char const digits[] = "0123456789abcdef";
  std::string hex;
  for (std::size_t i = 0; i < r.offset; ++i) {
    hex += digits[buf[i] >> 4];
    hex += digits[buf[i] & 15];
  }
  return hex;
}

// u8 a; u8 b, with the row {a: 1}: the member of b is an Opt left unset.
struct TwoU8 {
  std::uint8_t a = 0;
  Opt<std::uint8_t> b;
};

std::string pack_missing_required_value() {
  auto s = packbin::scheme<TwoU8>(1, packbin::u8<&TwoU8::a>(0), packbin::u8<&TwoU8::b>(1));
  TwoU8 row;
  row.a = 1;
  return pack_answer(s, row);
}

// u8 a; times(1, 0, u8 x): `a` is the count and the Array holds the list.
struct Item {
  std::uint8_t x = 0;
};
struct Counted {
  std::uint8_t a = 0;
  Array<Item, 4> items;
};

std::string pack_times(std::uint8_t count, std::size_t listed) {
  auto s = packbin::scheme<Counted>(
      1, packbin::u8<&Counted::a>(0),
      packbin::times<&Counted::items>(1, 0, packbin::u8<&Item::x>(1)));
  Counted row;
  row.a = count;
  row.items.count = listed;
  for (std::size_t i = 0; i < listed; ++i)
    row.items.items[i].x = static_cast<std::uint8_t>(i + 1);
  return pack_answer(s, row);
}

std::string pack_times_list_too_long() { return pack_times(2, 3); }
std::string pack_times_list_too_short() { return pack_times(2, 1); }
std::string pack_times_zero_with_values() { return pack_times(0, 1); }

// repeat(flags(bool on, u8 n)) with on = [true, false, true] and n = [1, 2, 3].
struct FlagRound {
  Opt<bool> on;
  Opt<std::uint8_t> n;
};
struct FlagRounds {
  Array<FlagRound, 4> rounds;
};

std::string pack_aligned_round_row() {
  auto s = packbin::scheme<FlagRounds>(
      1, packbin::repeat<&FlagRounds::rounds>(
             0, packbin::flags(0, packbin::boolean<&FlagRound::on>(0),
                               packbin::u8<&FlagRound::n>(1))));
  FlagRounds row;
  row.rounds.count = 3;
  row.rounds.items[0].on = true;
  row.rounds.items[1].on = false;
  row.rounds.items[2].on = true;
  for (std::size_t i = 0; i < row.rounds.count; ++i)
    row.rounds.items[i].n = static_cast<std::uint8_t>(i + 1);
  return pack_answer(s, row);
}

// Split-form flag byte schemes. One row type serves all four cases: `mode` and `sel` are the
// condition sources, `n` the count, `rounds` the list, `speed` and `heading` the bodies.
struct SplitItem {
  Opt<std::uint8_t> pt;
};
struct SplitRow {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> n;
  Opt<std::uint8_t> speed;
  Opt<std::uint16_t> heading;
  Opt<std::uint8_t> x;
  Array<SplitItem, 4> rounds;
};

// flag_byte; u8 mode after it; bit 0 { when eq(mode, 1) { u8 speed } }; bit 1 { u16 heading }.
std::string pack_split_when_source_after_byte() {
  namespace pb = packbin;
  auto s = pb::scheme<SplitRow>(
      1, pb::flag_byte(0), pb::u8<&SplitRow::mode>(0),
      pb::flag_bit(0, pb::when(1, pb::eq(0, 1), pb::u8<&SplitRow::speed>(1))),
      pb::flag_bit(0, pb::u16<&SplitRow::heading>(2)));
  SplitRow row;
  row.mode = 1;
  row.speed = 7;
  return pack_answer(s, row);
}

// flag_byte; u8 n after it; bit 0 { times count = n { u8 pt } }.
std::string pack_split_times_count_after_byte() {
  namespace pb = packbin;
  auto s = pb::scheme<SplitRow>(
      1, pb::flag_byte(0), pb::u8<&SplitRow::n>(0),
      pb::flag_bit(0, pb::times<&SplitRow::rounds>(1, 0, pb::u8<&SplitItem::pt>(1))),
      pb::flag_bit(0, pb::u16<&SplitRow::heading>(2)));
  SplitRow row;
  row.n = 2;
  row.rounds.count = 2;
  row.rounds.items[0].pt = 5;
  row.rounds.items[1].pt = 6;
  return pack_answer(s, row);
}

// u8 sel; flag_byte; when eq(sel, 1) { u8 n }; bit 0 { times count = n { u8 pt } }; sel = 0, so
// `n` is never written and the one round given has no count.
std::string pack_split_times_count_skipped() {
  namespace pb = packbin;
  auto s = pb::scheme<SplitRow>(
      1, pb::u8<&SplitRow::mode>(0), pb::flag_byte(0),
      pb::when(1, pb::eq(0, 1), pb::u8<&SplitRow::n>(1)),
      pb::flag_bit(0, pb::times<&SplitRow::rounds>(2, 1, pb::u8<&SplitItem::pt>(2))),
      pb::flag_bit(0, pb::u16<&SplitRow::heading>(3)));
  SplitRow row;
  row.mode = 0;
  row.rounds.count = 1;
  row.rounds.items[0].pt = 5;
  return pack_answer(s, row);
}

// u8 mode; flag_byte; bit 0 { when eq(mode, 1) { u8 speed } }; bit 1 { u16 heading }, with mode 0
// and speed given anyway: the false condition keeps the body out and the bit clear, silently.
std::string pack_split_false_condition_silent() {
  namespace pb = packbin;
  auto s = pb::scheme<SplitRow>(
      1, pb::u8<&SplitRow::mode>(0), pb::flag_byte(0),
      pb::flag_bit(0, pb::when(1, pb::eq(0, 1), pb::u8<&SplitRow::speed>(1))),
      pb::flag_bit(0, pb::u16<&SplitRow::heading>(2)));
  SplitRow row;
  row.mode = 0;
  row.speed = 7;
  row.heading = 90;
  return pack_answer(s, row);
}

// flag_byte; u8 n after it; bit 0 { group { u8 x; times count = n { u8 pt } } }, with n = 0, x
// given and two rounds given: the list holds values for a count of 0. README gives the bit body as
// the times alone, but then the late rule refuses the row first (the bit is set only by the late
// times, AZ-2385) and the count-0 rule is never reached. With `x` set the bit is set by a member
// that is not late, so the late rule cannot fire and only the count rule can refuse.
std::string pack_split_count_zero_after_byte_list() {
  namespace pb = packbin;
  auto s = pb::scheme<SplitRow>(
      1, pb::flag_byte(0), pb::u8<&SplitRow::n>(0),
      pb::flag_bit(0, pb::group(1, pb::u8<&SplitRow::x>(1),
                                pb::times<&SplitRow::rounds>(2, 0, pb::u8<&SplitItem::pt>(2)))));
  SplitRow row;
  row.n = 0;
  row.x = 1;
  row.rounds.count = 2;
  row.rounds.items[0].pt = 5;
  row.rounds.items[1].pt = 6;
  return pack_answer(s, row);
}

// flags { u8 n; times count = n { u8 pt } }, with n skipped and two rounds given.
std::string pack_flags_skipped_count_with_values() {
  namespace pb = packbin;
  auto s = pb::scheme<SplitRow>(
      1, pb::flags(0, pb::u8<&SplitRow::n>(0),
                   pb::times<&SplitRow::rounds>(1, 0, pb::u8<&SplitItem::pt>(1))));
  SplitRow row;
  row.rounds.count = 2;
  row.rounds.items[0].pt = 5;
  row.rounds.items[1].pt = 6;
  return pack_answer(s, row);
}

struct PackHandler {
  char const* id;
  PackRun run;
};

constexpr PackHandler kPackHandlers[] = {
    {"pack_missing_required_value", pack_missing_required_value},
    {"pack_times_list_too_long", pack_times_list_too_long},
    {"pack_times_list_too_short", pack_times_list_too_short},
    {"pack_times_zero_with_values", pack_times_zero_with_values},
    {"pack_aligned_round_row", pack_aligned_round_row},
    {"pack_split_when_source_after_byte", pack_split_when_source_after_byte},
    {"pack_split_times_count_after_byte", pack_split_times_count_after_byte},
    {"pack_split_times_count_skipped", pack_split_times_count_skipped},
    {"pack_split_false_condition_silent", pack_split_false_condition_silent},
    {"pack_split_count_zero_after_byte_list", pack_split_count_zero_after_byte_list},
    {"pack_flags_skipped_count_with_values", pack_flags_skipped_count_with_values},
};

struct PackSkip {
  char const* id;
  char const* reason;
};

// A typed row binds a std::uint8_t member, so 300 cannot be written for a u8; the rounds of a
// times live in an Array of at most 65,535 items, so a count of 65,536 cannot be written; and an
// Array of Array has no lone-buffer form to broadcast.
constexpr PackSkip kPackSkips[] = {
    {"pack_out_of_range_integer", "typed rows have static types: the u8 member is a std::uint8_t"},
    {"pack_times_count_over_limit",
     "it has no round limit on pack: the rounds live in a fixed `Array` of at most 65,535 items, and a count of 65,536 is refused only as a count that differs from the array length"},
    {"pack_lone_bytes_in_round",
     "a typed row holds an Array of Array: a lone buffer cannot be written"},
    {"pack_lone_utf8_under_times_over_budget",
     "pack writes into a caller buffer and the rounds live in a fixed `Array`: there is no output budget to pass"},
    {"pack_element_times_over_budget",
     "pack writes into a caller buffer and the rounds live in a fixed `Array`: there is no output budget to pass"},
    {"pack_slots_over_limit",
     "the rounds live in a fixed `Array` and pack has no slot budget"},
    {"pack_repeat_over_limit",
     "the rounds live in a fixed `Array` of at most 65,535 items, so 65,536 entries cannot be written"},
    {"pack_split_count_zero_after_byte_scalar",
     "a typed row holds an Array, so a lone scalar cannot be written"},
};

// What the C++ test does with a pack case: `ran` with the answer (hex or "pack_error"), a skip with
// its reason, or neither (an id with no handler and no skip).
struct Outcome {
  bool ran = false;
  bool skipped = false;
  std::string text;
};

inline Outcome outcome_of(std::string const& id) {
  Outcome out;
  for (auto const& h : kPackHandlers)
    if (id == h.id) {
      out.ran = true;
      out.text = h.run();
    }
  for (auto const& k : kPackSkips)
    if (id == k.id) {
      out.skipped = true;
      out.text = k.reason;
    }
  return out;
}

}  // namespace hostile_pack
