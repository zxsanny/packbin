// AZ-2436 (G3, C++ share, tests only): the U11 no-value count rule (AZ-2410, reference_loop22.md
// row 56) below the top level. The row 56 body is `u8 mode; when(mode == 1) { u8 c }; <bit> {
// member(count c) }`, the bit a split flag byte bit or a combined `flags`, the member `bits`,
// `packed` (width 1) or `sized`. Positions, as typescript/tests/loop23-novalue-nested.test.ts:
// the body inside a group; a bit holding a group holding the member (AC-1); the body inside an
// outer holding `when`; a bit holding a holding `when` around the member (AC-2); the body as a
// `times` round and as a `repeat` round (AC-3). TypeScript refuses count 3 with no value in all
// six.
//
// Spellability in C++ (all six positions spell): "no value" is a member written unbound (no
// member pointer), which is never present, so its bit is clear. A member bound to an Array or a
// Blob is always present in a typed row (an empty one is a value with zero items), so its bit is
// set and pack refuses it at the member whenever the `when` holding its count is clear, count 0
// and a left-out count included (as at the top level, AZ-2410).
//
// Observed and reported, not changed (D3): with an unbound member, C++ packs the clear bit for
// count 3 in every position, where the other packages refuse (U11 is not applied to an unbound
// member; the same holds at the top level). Count 0, a left-out count and a holding inner `when`
// pack the TypeScript bytes (AC-4). Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time (see source_kinds_host_tests.cpp); the suppression covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

using packbin::Array;
using packbin::Blob;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct R {
  Opt<std::uint8_t> o;
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> c;
  Array<std::uint8_t, 8> list;
  Blob<8> payload;
};

struct Round {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> c;
  Array<std::uint8_t, 8> list;
  Blob<8> payload;
};

struct T {
  std::uint8_t n = 0;
  Array<Round, 4> rounds;
};

constexpr int kBits = 0;
constexpr int kPacked = 1;
constexpr int kSized = 2;

char const* kind_name(int k) { return k == kBits ? "bits" : k == kPacked ? "packed" : "sized"; }

template <int K, typename E>
auto bound(int id, int count) {
  if constexpr (K == kBits)
    return pb::bits<&E::list>(id, count);
  else if constexpr (K == kPacked)
    return pb::packed<&E::list>(1, id, count);
  else
    return pb::sized<&E::payload>(id, count);
}

template <int K>
auto unbound(int id, int count) {
  if constexpr (K == kBits)
    return pb::bits(id, count);
  else if constexpr (K == kPacked)
    return pb::packed(1, id, count);
  else
    return pb::sized(id, count);
}

// The value [1, 0, 1] (05 on the wire) or the bytes 01 02 03.
template <int K, typename E>
void give_value(E& e) {
  if constexpr (K == kSized) {
    for (std::uint8_t b : {1, 2, 3})
      e.payload.data[e.payload.len++] = b;
  } else {
    for (std::uint8_t b : {1, 0, 1})
      e.list.items[e.list.count++] = b;
  }
}

std::string set_hex(int k) { return k == kSized ? "010203" : "05"; }

template <typename E>
void fill(E& e, int mode, int c) {
  e.mode = static_cast<std::uint8_t>(mode);
  if (c >= 0)
    e.c = static_cast<std::uint8_t>(c);
}

// One `{mode, c}` per round (c < 0: left out).
struct Cell {
  int mode;
  int c;
};

R row_of(std::vector<Cell> const& cells) {
  R r;
  r.o = 1;
  fill(r, cells[0].mode, cells[0].c);
  return r;
}

T rounds_of(std::vector<Cell> const& cells, bool counted) {
  T t;
  if (counted)
    t.n = static_cast<std::uint8_t>(cells.size());
  for (auto const& cell : cells)
    fill(t.rounds.items[t.rounds.count++], cell.mode, cell.c);
  return t;
}

// The packet as hex, or BadValue@<id> when pack refuses; `!unpack` when it does not unpack.
template <typename S, typename Row>
std::string outcome(S const& s, Row const& row) {
  std::uint8_t buf[64];
  auto p = pb::pack(s, row, buf, sizeof(buf));
  char text[40];
  if (!p.ok()) {
    std::snprintf(text, sizeof(text), "%s@%d",
                  p.error == pb::Error::BadValue ? "BadValue" : "other", p.field);
    return text;
  }
  std::string out;
  for (std::size_t i = 0; i < p.offset; ++i) {
    std::snprintf(text, sizeof(text), "%02x", buf[i]);
    out += text;
  }
  Row back;
  if (!pb::unpack(s, buf, p.offset, back).ok())
    out += "!unpack";
  return out;
}

// Each position: `scheme<Split>(member)`, the member and count ids, the count-3 rows with the
// hex an unbound member packs, and the unchanged no-value rows (count 0, left out, holding inner
// when) with their hex; the value row is the last no-value row with a value given.
struct InGroup {
  using Row = R;
  using E = R;
  static constexpr int kMember = 2, kCount = 1;
  template <bool Split, typename M>
  static auto scheme(M const& m) {
    if constexpr (Split)
      return pb::scheme<R>(1, pb::group(0, pb::u8<&R::mode>(0),
                                        pb::when(1, pb::eq(0, 1), pb::u8<&R::c>(1)),
                                        pb::flag_byte(0), pb::flag_bit(0, m)));
    else
      return pb::scheme<R>(1, pb::group(0, pb::u8<&R::mode>(0),
                                        pb::when(1, pb::eq(0, 1), pb::u8<&R::c>(1)),
                                        pb::flags(2, m)));
  }
  static Row make(std::vector<Cell> const& cells) { return row_of(cells); }
  static E& last(Row& r) { return r; }
};

struct BitHoldsGroup : InGroup {
  template <bool Split, typename M>
  static auto scheme(M const& m) {
    if constexpr (Split)
      return pb::scheme<R>(1, pb::u8<&R::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&R::c>(1)),
                           pb::flag_byte(0), pb::flag_bit(0, pb::group(2, m)));
    else
      return pb::scheme<R>(1, pb::u8<&R::mode>(0), pb::when(1, pb::eq(0, 1), pb::u8<&R::c>(1)),
                           pb::flags(2, pb::group(2, m)));
  }
};

struct OuterWhen : InGroup {
  static constexpr int kMember = 3, kCount = 2;
  template <bool Split, typename M>
  static auto scheme(M const& m) {
    if constexpr (Split)
      return pb::scheme<R>(1, pb::u8<&R::o>(0),
                           pb::when(1, pb::eq(0, 1), pb::u8<&R::mode>(1),
                                    pb::when(2, pb::eq(1, 1), pb::u8<&R::c>(2)), pb::flag_byte(0),
                                    pb::flag_bit(0, m)));
    else
      return pb::scheme<R>(1, pb::u8<&R::o>(0),
                           pb::when(1, pb::eq(0, 1), pb::u8<&R::mode>(1),
                                    pb::when(2, pb::eq(1, 1), pb::u8<&R::c>(2)), pb::flags(3, m)));
  }
};

struct BitHoldsWhen : OuterWhen {
  template <bool Split, typename M>
  static auto scheme(M const& m) {
    if constexpr (Split)
      return pb::scheme<R>(1, pb::u8<&R::o>(0), pb::u8<&R::mode>(1),
                           pb::when(2, pb::eq(1, 1), pb::u8<&R::c>(2)), pb::flag_byte(0),
                           pb::flag_bit(0, pb::when(3, pb::eq(0, 1), m)));
    else
      return pb::scheme<R>(1, pb::u8<&R::o>(0), pb::u8<&R::mode>(1),
                           pb::when(2, pb::eq(1, 1), pb::u8<&R::c>(2)),
                           pb::flags(3, pb::when(3, pb::eq(0, 1), m)));
  }
};

struct TimesRound {
  using Row = T;
  using E = Round;
  static constexpr int kMember = 3, kCount = 2;
  template <bool Split, typename M>
  static auto scheme(M const& m) {
    if constexpr (Split)
      return pb::scheme<T>(1, pb::u8<&T::n>(0),
                           pb::times<&T::rounds>(1, 0, pb::u8<&Round::mode>(1),
                                                 pb::when(2, pb::eq(1, 1), pb::u8<&Round::c>(2)),
                                                 pb::flag_byte(0), pb::flag_bit(0, m)));
    else
      return pb::scheme<T>(1, pb::u8<&T::n>(0),
                           pb::times<&T::rounds>(1, 0, pb::u8<&Round::mode>(1),
                                                 pb::when(2, pb::eq(1, 1), pb::u8<&Round::c>(2)),
                                                 pb::flags(3, m)));
  }
  static Row make(std::vector<Cell> const& cells) { return rounds_of(cells, true); }
  static E& last(Row& t) { return t.rounds.items[t.rounds.count - 1]; }
};

struct RepeatRound : TimesRound {
  static constexpr int kMember = 2, kCount = 1;
  template <bool Split, typename M>
  static auto scheme(M const& m) {
    if constexpr (Split)
      return pb::scheme<T>(1, pb::repeat<&T::rounds>(0, pb::u8<&Round::mode>(0),
                                                     pb::when(1, pb::eq(0, 1), pb::u8<&Round::c>(1)),
                                                     pb::flag_byte(0), pb::flag_bit(0, m)));
    else
      return pb::scheme<T>(1, pb::repeat<&T::rounds>(0, pb::u8<&Round::mode>(0),
                                                     pb::when(1, pb::eq(0, 1), pb::u8<&Round::c>(1)),
                                                     pb::flags(2, m)));
  }
  static Row make(std::vector<Cell> const& cells) { return rounds_of(cells, false); }
};

struct Rows {
  std::vector<std::vector<Cell>> refused;
  std::vector<char const*> refused_hex;
  std::vector<std::vector<Cell>> unchanged;
  std::vector<char const*> unchanged_hex;
  char const* value_prefix;
};

template <typename P, int K, bool Split>
void run_one(Rows const& rows, std::string const& name) {
  // Arrange
  auto ub = P::template scheme<Split>(unbound<K>(P::kMember, P::kCount));
  auto b = P::template scheme<Split>(bound<K, typename P::E>(P::kMember, P::kCount));
  std::string at = name + " " + kind_name(K) + (Split ? " split" : " flags");
  std::string refused = "BadValue@" + std::to_string(P::kMember);

  // Act / Assert: count 3, no value (unbound): packs the clear bit, observed (the others refuse).
  for (std::size_t i = 0; i < rows.refused.size(); ++i)
    check::expect(outcome(ub, P::make(rows.refused[i])) == rows.refused_hex[i],
                  (at + " count 3, no value: packs the clear bit (observed, D3)").c_str());
  // AC-4: count 0, left out, holding inner when, no value: the TypeScript bytes.
  for (std::size_t i = 0; i < rows.unchanged.size(); ++i)
    check::expect(outcome(ub, P::make(rows.unchanged[i])) == rows.unchanged_hex[i],
                  (at + " unchanged no-value row " + std::to_string(i)).c_str());
  // AC-4: holding inner when with the value (bound member).
  auto with = P::make(rows.unchanged.back());
  give_value<K>(P::last(with));
  check::expect(outcome(b, with) == std::string(rows.value_prefix) + set_hex(K),
                (at + " holding inner when, value").c_str());
  // A bound member with no item (the typed-row analog of no value) is refused at the member.
  for (auto const& cells : rows.refused)
    check::expect(outcome(b, P::make(cells)) == refused, (at + " bound, empty, count 3").c_str());
  for (auto const& cells : rows.unchanged)
    check::expect(outcome(b, P::make(cells)) == refused, (at + " bound, empty").c_str());
}

template <typename P>
void run_position(Rows const& rows, char const* name) {
  run_one<P, kBits, true>(rows, name);
  run_one<P, kBits, false>(rows, name);
  run_one<P, kPacked, true>(rows, name);
  run_one<P, kPacked, false>(rows, name);
  run_one<P, kSized, true>(rows, name);
  run_one<P, kSized, false>(rows, name);
}

Rows const kTop{{{{0, 3}}},
                {"010000"},
                {{{0, 0}}, {{0, -1}}, {{1, 3}}},
                {"010000", "010000", "01010300"},
                "01010301"};

Rows const kOuter{{{{0, 3}}},
                  {"01010000"},
                  {{{0, 0}}, {{0, -1}}, {{1, 3}}},
                  {"01010000", "01010000", "0101010300"},
                  "0101010301"};

Rows const kTimes{{{{0, 3}}, {{1, 0}, {0, 3}}},
                  {"01010000", "01020100000000"},
                  {{{1, 0}, {0, 0}}, {{0, -1}}, {{1, 3}}},
                  {"01020100000000", "01010000", "0101010300"},
                  "0101010301"};

Rows const kRepeat{{{{0, 3}}, {{1, 0}, {0, 3}}},
                   {"010000", "010100000000"},
                   {{{1, 0}, {0, 0}}, {{0, -1}}, {{1, 3}}},
                   {"010100000000", "010000", "01010300"},
                   "01010301"};

void az2436_no_value_count_below_the_top_level() {
  run_position<InGroup>(kTop, "AZ-2436 AC-1 body in a group");
  run_position<BitHoldsGroup>(kTop, "AZ-2436 AC-1 bit holds a group");
  run_position<OuterWhen>(kOuter, "AZ-2436 AC-2 body in an outer holding when");
  run_position<BitHoldsWhen>(kOuter, "AZ-2436 AC-2 bit holds a holding when");
  run_position<TimesRound>(kTimes, "AZ-2436 AC-3 times round");
  run_position<RepeatRound>(kRepeat, "AZ-2436 AC-3 repeat round");
}

// `when(o holds) { u8 mode; when(mode clear) { u8 c; <bit> { member } } }`: the member sits in
// the clear `when`, so nothing of it is written or looked at (the existing silent skip, not the
// U11 rule). Observed at b8b2809, as in TypeScript: 010100 for every kind and bit.
template <int K, bool Split>
void silent_skip_one() {
  // Arrange
  auto scheme = [](auto const& m) {
    if constexpr (Split)
      return pb::scheme<R>(1, pb::u8<&R::o>(0),
                           pb::when(1, pb::eq(0, 1), pb::u8<&R::mode>(1),
                                    pb::when(2, pb::eq(1, 1), pb::u8<&R::c>(2), pb::flag_byte(0),
                                             pb::flag_bit(0, m))));
    else
      return pb::scheme<R>(1, pb::u8<&R::o>(0),
                           pb::when(1, pb::eq(0, 1), pb::u8<&R::mode>(1),
                                    pb::when(2, pb::eq(1, 1), pb::u8<&R::c>(2), pb::flags(3, m))));
  };
  R with = row_of({{0, 3}});
  give_value<K>(with);
  std::string at = std::string("AZ-2436 silent skip ") + kind_name(K) + (Split ? " split" : " flags");

  // Act / Assert
  check::expect(outcome(scheme(unbound<K>(3, 2)), row_of({{0, 3}})) == "010100",
                (at + ", no value").c_str());
  check::expect(outcome(scheme(bound<K, R>(3, 2)), with) == "010100", (at + ", value").c_str());
}

void az2436_member_inside_the_clear_when_is_a_silent_skip() {
  silent_skip_one<kBits, true>();
  silent_skip_one<kBits, false>();
  silent_skip_one<kPacked, true>();
  silent_skip_one<kPacked, false>();
  silent_skip_one<kSized, true>();
  silent_skip_one<kSized, false>();
}

}  // namespace

int run_core_novalue_nested_host_tests() {
  az2436_no_value_count_below_the_top_level();
  az2436_member_inside_the_clear_when_is_a_silent_skip();
  return check::failures();
}
