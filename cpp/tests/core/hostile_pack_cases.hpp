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

template <typename S, typename Row>
std::string pack_answer(S const& s, Row const& row) {
  std::uint8_t buf[32] = {};
  auto r = packbin::pack(s, row, buf, sizeof(buf));
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

struct PackHandler {
  char const* id;
  PackRun run;
};

constexpr PackHandler kPackHandlers[] = {
    {"pack_missing_required_value", pack_missing_required_value},
    {"pack_times_list_too_long", pack_times_list_too_long},
    {"pack_times_list_too_short", pack_times_list_too_short},
    {"pack_aligned_round_row", pack_aligned_round_row},
};

struct PackSkip {
  char const* id;
  char const* reason;
};

// A typed row binds a std::uint8_t member, so 300 cannot be written for a u8.
constexpr PackSkip kPackSkips[] = {
    {"pack_out_of_range_integer", "typed rows have static types: the u8 member is a std::uint8_t"},
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
