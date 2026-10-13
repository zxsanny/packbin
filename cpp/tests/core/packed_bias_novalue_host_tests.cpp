// AZ-2432 (U20): `packed` with bias -1 in the U11 grid (reference_loop22.md rows 56 to 56d):
// `u8 mode; when(mode == 1) { u8 c }; <bit> { packed(width 1, count c, bias -1) }`, the bit a split
// flag byte bit or a combined `flags`.
//
// Trace. A member bound to an Array is always present in a typed row (`present`, values.cpp: the
// default case is `m != nullptr`), so its bit is set and pack reaches `pack_small` (pack.cpp).
// There `ref_value` fails when the `when` holding the count is clear (`count_skipped`), and pack
// returns BadValue at the member's id (pack.cpp:141-142) before the bias is added (:144-145).
// The bias plays no part: bias 0 and -1 refuse the same cells, as `bits` and `sized` do
// (held_count_nested_late_host_tests.cpp, AZ-2410). That is the typed row, not a divergence on
// this cell: an empty Array is a value with zero items, which the other five refuse too (row 53).
//
// C++ does spell "no value": a member written unbound (`packed(1, 2, 1, -1)`, no member pointer)
// is never present, so its bit is clear. That spelling packs 010000 for count 1 with bias -1, as
// the other five do (row 56d), and for count 0, a left-out count and a holding `when`. It also
// packs 010000 for count 3, which the other five refuse (U11 is not applied to an unbound member):
// pinned below as observed and reported, not changed (AZ-2432 excludes byte changes to rows C++
// packs at HEAD). Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <string>

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time (see source_kinds_host_tests.cpp); the suppression covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

using packbin::Array;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Held {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> c;
  Array<std::uint8_t, 8> list;
};

Held held(int mode, int c, int items) {
  Held h;
  h.mode = static_cast<std::uint8_t>(mode);
  if (c >= 0)
    h.c = static_cast<std::uint8_t>(c);
  for (int i = 0; i < items; ++i)
    h.list.items[h.list.count++] = 1;
  return h;
}

// The packet as hex, or `BadValue@<id>+<offset>` when pack refuses; `!unpack` is appended when
// the packet does not unpack.
template <typename S>
std::string outcome(S const& s, Held const& row) {
  std::uint8_t buf[32];
  auto p = pb::pack(s, row, buf, sizeof(buf));
  char text[80];
  if (!p.ok()) {
    std::snprintf(text, sizeof(text), "%s@%d+%zu",
                  p.error == pb::Error::BadValue ? "BadValue" : "other", p.field, p.offset);
    return text;
  }
  std::string out;
  for (std::size_t i = 0; i < p.offset; ++i) {
    std::snprintf(text, sizeof(text), "%02x", buf[i]);
    out += text;
  }
  Held back;
  if (!pb::unpack(s, buf, p.offset, back).ok())
    out += "!unpack";
  return out;
}

template <typename M>
auto split(M const& member) {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)), pb::flag_byte(0),
                          pb::flag_bit(0, member));
}

template <typename M>
auto combined(M const& member) {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::c>(1)), pb::flags(2, member));
}

template <typename S>
void bound_cells(S const& s, std::string const& at) {
  // Act / Assert: clear when, no value (an empty Array, the nearest analog), count 0, 1, 3, absent.
  for (int c : {0, 1, 3, -1})
    check::expect(outcome(s, held(0, c, 0)) == "BadValue@2+3",
                  (at + " clear, empty, count " + std::to_string(c)).c_str());
  // Clear when with a value (count 1 minus 1 is 0 items, then count 3 with 2 items): row 53.
  check::expect(outcome(s, held(0, 3, 2)) == "BadValue@2+3", (at + " clear, value").c_str());
  // Holding when: the bias applies (count 1 is 0 items, count 3 is 2 items, count 0 is -1).
  check::expect(outcome(s, held(1, 1, 0)) == "01010101", (at + " holding, count 1").c_str());
  check::expect(outcome(s, held(1, 3, 2)) == "0101030103", (at + " holding, count 3").c_str());
  check::expect(outcome(s, held(1, 0, 0)) == "BadValue@2+4", (at + " holding, count 0").c_str());
  check::expect(outcome(s, held(1, 3, 0)) == "BadValue@2+4",
                (at + " holding, count 3, empty").c_str());
}

void u20_bound_packed_bias_minus_one_is_the_typed_row() {
  // Arrange
  auto s = split(pb::packed<&Held::list>(1, 2, 1, -1));
  auto f = combined(pb::packed<&Held::list>(1, 2, 1, -1));
  auto s0 = split(pb::packed<&Held::list>(1, 2, 1));

  // Act / Assert
  bound_cells(s, "U20 bound bias -1 split");
  bound_cells(f, "U20 bound bias -1 flags");
  // Bias 0 refuses the same clear cells: the refusal comes before the bias.
  for (int c : {0, 1, 3, -1})
    check::expect(outcome(s0, held(0, c, 0)) == "BadValue@2+3",
                  ("U20 bound bias 0 split clear, count " + std::to_string(c)).c_str());
}

template <typename S>
void unbound_cells(S const& s, std::string const& at) {
  // Act / Assert: row 56d count 1 (as the five), 56a count 0, 56b left out, 56c holding.
  check::expect(outcome(s, held(0, 1, 0)) == "010000", (at + " clear, count 1 (56d)").c_str());
  check::expect(outcome(s, held(0, 0, 0)) == "010000", (at + " clear, count 0 (56a)").c_str());
  check::expect(outcome(s, held(0, -1, 0)) == "010000", (at + " clear, left out (56b)").c_str());
  check::expect(outcome(s, held(1, 3, 0)) == "01010300", (at + " holding, count 3 (56c)").c_str());
  check::expect(outcome(s, held(1, 1, 0)) == "01010100", (at + " holding, count 1").c_str());
  // Observed, reported: row 56d count 3 (and row 56) are refused by the other five.
  check::expect(outcome(s, held(0, 3, 0)) == "010000",
                (at + " clear, count 3: packs (the five refuse)").c_str());
}

void u20_unbound_packed_bias_minus_one_is_no_value() {
  // Arrange
  auto s = split(pb::packed(1, 2, 1, -1));
  auto f = combined(pb::packed(1, 2, 1, -1));

  // Act / Assert
  unbound_cells(s, "U20 unbound bias -1 split");
  unbound_cells(f, "U20 unbound bias -1 flags");
}

}  // namespace

int run_core_packed_bias_novalue_host_tests() {
  u20_bound_packed_bias_minus_one_is_the_typed_row();
  u20_unbound_packed_bias_minus_one_is_no_value();
  return check::failures();
}
