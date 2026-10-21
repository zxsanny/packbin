// The loop 21 pack cases of fixtures/hostile/cases.txt (AZ-2394) for the C++ host test, and the
// rule table that says which error each refused pack case must carry (AZ-2392). Same contract
// as hostile_pack_cases.hpp: a handler packs the row its README section gives and answers
// "pack_error" or the packet as lowercase hex.

#pragma once

#include "hostile_pack_cases.hpp"

namespace hostile_pack {

namespace pb = packbin;

// repeat { u8 w; flags { u8 v } }: one entry per round, so a short list cannot be written; the
// second round leaves `v` unset.
struct ShortRound {
  std::uint8_t w = 0;
  Opt<std::uint8_t> v;
};
struct ShortRounds {
  Array<ShortRound, 4> rounds;
};

std::string pack_flags_short_list_filled() {
  auto s = pb::scheme<ShortRounds>(
      1, pb::repeat<&ShortRounds::rounds>(0, pb::u8<&ShortRound::w>(0),
                                          pb::flags(1, pb::u8<&ShortRound::v>(1))));
  ShortRounds row;
  row.rounds.count = 2;
  row.rounds.items[0].w = 1;
  row.rounds.items[0].v = 5;
  row.rounds.items[1].w = 2;
  return pack_answer(s, row);
}

// flag_byte; u8 mode after it; bit 0 { group { u8 d; when eq(mode, 1) { u8 a }; when eq(mode, 2)
// { u8 b } } }, with mode 1, d 5, a 9.
struct LateRow {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> d;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
};

std::string pack_late_when_in_bit_body() {
  auto s = pb::scheme<LateRow>(
      1, pb::flag_byte(0), pb::u8<&LateRow::mode>(0),
      pb::flag_bit(0, pb::group(1, pb::u8<&LateRow::d>(1),
                                pb::when(2, pb::eq(0, 1), pb::u8<&LateRow::a>(2)),
                                pb::when(3, pb::eq(0, 2), pb::u8<&LateRow::b>(3)))));
  LateRow row;
  row.mode = 1;
  row.d = 5;
  row.a = 9;
  return pack_answer(s, row);
}

// u8 mode; when eq(mode, 1) { u8 c }; flag_byte; bit 0 { times count = c { u8 pt } }; bit 1 {
// u16 heading }, with mode 0 (the when is clear, so c is never written), c 1, heading 90.
std::string pack_count_one_clear_when() {
  auto s = pb::scheme<SplitRow>(
      1, pb::u8<&SplitRow::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&SplitRow::n>(1)),
      pb::flag_byte(0),
      pb::flag_bit(0, pb::times<&SplitRow::rounds>(2, 1, pb::u8<&SplitItem::pt>(2))),
      pb::flag_bit(0, pb::u16<&SplitRow::heading>(3)));
  SplitRow row;
  row.mode = 0;
  row.n = 1;
  row.heading = 90;
  return pack_answer(s, row);
}

// u8 mode; when eq(mode, 1) { u8 c }; then bits, packed or sized counted by c, with mode 0 and
// c 3: the count is not written, so the three values have no count on the wire.
struct CountedRow {
  std::uint8_t mode = 0;
  Opt<std::uint8_t> c;
  Array<std::uint8_t, 4> v;
  pb::View bytes;
};

std::string pack_bits_count_clear_when() {
  auto s = pb::scheme<CountedRow>(
      1, pb::u8<&CountedRow::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&CountedRow::c>(1)),
      pb::bits<&CountedRow::v>(2, 1));
  CountedRow row;
  row.c = 3;
  row.v.count = 3;
  row.v.items[0] = 1;
  row.v.items[2] = 1;
  return pack_answer(s, row);
}

std::string pack_packed_count_clear_when() {
  auto s = pb::scheme<CountedRow>(
      1, pb::u8<&CountedRow::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&CountedRow::c>(1)),
      pb::packed<&CountedRow::v>(1, 2, 1));
  CountedRow row;
  row.c = 3;
  row.v.count = 3;
  row.v.items[0] = 1;
  row.v.items[2] = 1;
  return pack_answer(s, row);
}

std::string pack_sized_count_clear_when() {
  static std::uint8_t const three[] = {1, 2, 3};
  auto s = pb::scheme<CountedRow>(
      1, pb::u8<&CountedRow::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&CountedRow::c>(1)),
      pb::sized<&CountedRow::bytes>(2, 1));
  CountedRow row;
  row.c = 3;
  row.bytes = pb::View{three, 3};
  return pack_answer(s, row);
}

// AZ-2816: u8 mode; when eq(mode, 1) { u16 a; u8 k }; when eq(k, 2 or 0) { u8 b }, with mode 0 (the
// first when is clear, so k is never written and is absent): the second when is false and b is not
// written, packet `0100`. The first row holds optional members with k 2; the second plain members,
// where an unread k holds 0.
struct SkippedOpt {
  Opt<std::uint8_t> mode;
  Opt<std::uint16_t> a;
  Opt<std::uint8_t> k;
  Opt<std::uint8_t> b;
};

std::string pack_when_of_skipped_source() {
  auto s = pb::scheme<SkippedOpt>(
      1, pb::u8<&SkippedOpt::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u16<&SkippedOpt::a>(1), pb::u8<&SkippedOpt::k>(2)),
      pb::when(3, pb::eq(2, 2), pb::u8<&SkippedOpt::b>(3)));
  SkippedOpt row;
  row.mode = 0;
  row.a = 7;
  row.k = 2;
  row.b = 5;
  return pack_answer(s, row);
}

struct SkippedPlain {
  std::uint8_t mode = 0;
  std::uint16_t a = 0;
  std::uint8_t k = 0;
  std::uint8_t b = 0;
};

std::string pack_when_of_skipped_source_zero() {
  auto s = pb::scheme<SkippedPlain>(
      1, pb::u8<&SkippedPlain::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u16<&SkippedPlain::a>(1), pb::u8<&SkippedPlain::k>(2)),
      pb::when(3, pb::eq(2, 0), pb::u8<&SkippedPlain::b>(3)));
  SkippedPlain row;
  row.a = 7;
  row.b = 5;
  return pack_answer(s, row);
}

constexpr PackHandler kPackHandlers21[] = {
    {"pack_flags_short_list_filled", pack_flags_short_list_filled},
    {"pack_late_when_in_bit_body", pack_late_when_in_bit_body},
    {"pack_count_one_clear_when", pack_count_one_clear_when},
    {"pack_bits_count_clear_when", pack_bits_count_clear_when},
    {"pack_packed_count_clear_when", pack_packed_count_clear_when},
    {"pack_sized_count_clear_when", pack_sized_count_clear_when},
    {"pack_when_of_skipped_source", pack_when_of_skipped_source},
    {"pack_when_of_skipped_source_zero", pack_when_of_skipped_source_zero},
};

// The slot cases need a round budget and a short list needs a list: C++ has neither.
constexpr PackSkip kPackSkips21[] = {
    // Loop 22 (AZ-2417): the reasons are the README's "Not run by" lines.
    {"pack_novalue_count_clear_when_bits",
     "a bits member bound to an `Array` is always present, so pack refuses the row with `BadValue` at the member because the count's `when` is clear (loop 23 trace, U20); written unbound it packs the clear bit where this case expects `pack_error` (open row U24)"},
    {"pack_novalue_count_clear_when_packed",
     "a packed member bound to an `Array` is always present, so pack refuses the row with `BadValue` at the member because the count's `when` is clear (loop 23 trace, U20); written unbound it packs the clear bit where this case expects `pack_error` (open row U24)"},
    {"pack_novalue_count_clear_when_sized",
     "a sized member bound to an `Array` is always present, so pack refuses the row with `BadValue` at the member because the count's `when` is clear (loop 23 trace, U20); written unbound it packs the clear bit where this case expects `pack_error` (open row U24)"},
    {"pack_repeat_unequal_lists_lone",
     "a typed row holds an `Array` of round items, so a lone value for one round member cannot be written"},
    {"pack_repeat_unequal_lists_when",
     "a typed row holds an `Array` of round items, so a shorter list for one round member cannot be written"},
    {"pack_times_short_list_flags",
     "a typed row holds an `Array` with one item per round, so a list shorter than the count cannot be written"},
    {"pack_element_times_over_bytes_budget",
     "a fixed array of rounds and a caller buffer: there is no output budget to pass"},
    {"pack_round_slots_at_limit",
     "the rounds live in a fixed `Array` and pack has no slot budget to set"},
    {"pack_round_slots_over_limit",
     "the rounds live in a fixed `Array` and pack has no slot budget to set"},
    {"pack_round_slots_flags_at_limit",
     "the rounds live in a fixed `Array` and pack has no slot budget to set"},
    {"pack_round_slots_flags_over_limit",
     "the rounds live in a fixed `Array` and pack has no slot budget to set"},
    // C++ answers BadValue naming the times (id 1) for flag_byte, n after it, bit 0 { times },
    // bit 1 { heading }, n = 2, heading 90, an empty Array: a count of 2 with an Array of 0 items
    // is a count mismatch, not an absent body, and the late rule (AZ-2385) refuses it. TypeScript
    // packs 0102025a00; AZ-2384 excludes C++ and the fixtures README lists it under "Not run by".
    {"pack_split_times_absent_body",
     "AZ-2384 excludes C++: a count above 0 with an empty Array is a count mismatch (late rule)"},
    {"pack_flags_short_list",
     "a fixed `Array` of round items whose length is the round count: a short list cannot be written"},
};

// The error a refused pack case must carry: BadValue naming this order id. A refusal by another
// rule names another member or another kind, and fails. Field ids are the C++ order ids of the
// schemes above and in hostile_pack_cases.hpp.
struct Refusal {
  char const* id;
  pb::Error error;
  int field;
};

constexpr Refusal kRefusals[] = {
    // The member of `b` is an Opt left unset.
    {"pack_missing_required_value", pb::Error::BadValue, 1},
    // The Array length differs from the count in `a`: the refusal names the times.
    {"pack_times_list_too_long", pb::Error::BadValue, 1},
    {"pack_times_list_too_short", pb::Error::BadValue, 1},
    {"pack_times_zero_with_values", pb::Error::BadValue, 1},
    // The body of the bit, named by its first member, is refused: the source is written after
    // the byte (AZ-2331).
    {"pack_split_when_source_after_byte", pb::Error::BadValue, 1},
    {"pack_split_times_count_after_byte", pb::Error::BadValue, 1},
    // The `when` is clear, so `n` is never written and the times (id 2) has no count.
    {"pack_split_times_count_skipped", pb::Error::BadValue, 2},
    // Count 0 against a list that holds two values: the times (id 2, inside the group of the
    // bit) is refused by the count rule; `x` sets the bit, so the late rule cannot be the one.
    {"pack_split_count_zero_after_byte_list", pb::Error::BadValue, 2},
    {"pack_flags_skipped_count_with_values", pb::Error::BadValue, 1},
    // The count's `when` is clear: the times (id 2) or the counted member (id 2) is refused.
    {"pack_count_one_clear_when", pb::Error::BadValue, 2},
    {"pack_bits_count_clear_when", pb::Error::BadValue, 2},
    {"pack_packed_count_clear_when", pb::Error::BadValue, 2},
    {"pack_sized_count_clear_when", pb::Error::BadValue, 2},
};

inline Refusal const* refusal_of(std::string const& id) {
  for (auto const& r : kRefusals)
    if (id == r.id)
      return &r;
  return nullptr;
}

// Like outcome_of, over both tables.
inline Outcome outcome_of_all(std::string const& id) {
  Outcome out = outcome_of(id);
  for (auto const& h : kPackHandlers21)
    if (id == h.id) {
      out.ran = true;
      out.text = h.run();
    }
  for (auto const& k : kPackSkips21)
    if (id == k.id) {
      out.skipped = true;
      out.text = k.reason;
    }
  return out;
}

}  // namespace hostile_pack
