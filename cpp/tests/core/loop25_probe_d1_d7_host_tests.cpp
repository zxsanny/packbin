// Loop 25 probes D1 (AZ-2476) and D7 (AZ-2478): rows the Go port found, run in C++ and pinned to
// the bytes TypeScript gives (measured with the TypeScript package on the same schemes).
//
// D1, an empty group that takes no id. In Go `Group(0, "mark")` has no members; in C++ the same
// scheme is a `bool` member bound with `group<&Row::mark>(0)`. The group's anchor 0 is the id of
// the field after it (it takes none), so `u8(0)` after it has id 0 too. Pack, unpack and repack
// give TypeScript's bytes. One row differs: a `when` that names the empty group as its source
// builds in C++ (README, loop 19 notes) where TypeScript and Go refuse it at construction.
//
// D7, a split flag bit inside a `when` whose condition is false with the member given. The bit of
// the unwritten member is set and its byte is not written, as in TypeScript and Go; unpack reads
// no such member, so the repack clears the bit. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstdint>

using member_cases::pack_refused;
using member_cases::round_trip;
using member_cases::same_opt;
using member_cases::unpack_only;
using packbin::Opt;
namespace pb = packbin;

namespace {

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time (see builder_id_range_host_tests.cpp). The suppression covers the functions
// below.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"

struct Mark {
  bool mark = false;

  bool same_as(Mark const& o) const { return mark == o.mark; }
};

struct MarkN {
  bool mark = false;
  std::uint8_t n = 0;

  bool same_as(MarkN const& o) const { return mark == o.mark && n == o.n; }
};

struct MarkOptN {
  bool mark = false;
  Opt<std::uint8_t> n;

  bool same_as(MarkOptN const& o) const { return mark == o.mark && same_opt(n, o.n); }
};

struct Gate {
  bool mark = false;
  Opt<std::uint8_t> v;

  bool same_as(Gate const& o) const { return mark == o.mark && same_opt(v, o.v); }
};

struct SplitWhen {
  Opt<std::uint8_t> k;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;

  bool same_as(SplitWhen const& o) const {
    return same_opt(k, o.k) && same_opt(a, o.a) && same_opt(b, o.b);
  }
};

SplitWhen split_row(int k, int a, int b) {
  SplitWhen r;
  if (k >= 0)
    r.k = static_cast<std::uint8_t>(k);
  if (a >= 0)
    r.a = static_cast<std::uint8_t>(a);
  if (b >= 0)
    r.b = static_cast<std::uint8_t>(b);
  return r;
}

// -1 leaves the member unset.
constexpr int kNone = -1;

// --- D1: an empty group that takes no id ------------------------------------------------------

// TypeScript: flags(0, group(0, mark)): {mark: true} -> 0101, {mark: false} -> 0100.
void d1_empty_group_in_flags_packs_as_typescript() {
  // Arrange
  auto s = pb::scheme<Mark>(1, pb::flags(0, pb::group<&Mark::mark>(0)));
  Mark on;
  on.mark = true;
  Mark off;

  // Act / Assert
  check::expect(pb::validate(s).ok(), "D1 empty group in flags builds");
  round_trip(s, on, "0101", "D1 empty group mark set");
  round_trip(s, off, "0100", "D1 empty group mark false");
}

// TypeScript: m = flagByte; m, m.bit(group(0, mark)), m.bit(u8(0, n)): {mark: true, n: 3} -> 010303.
void d1_empty_group_in_a_split_bit_packs_as_typescript() {
  // Arrange
  auto s = pb::scheme<MarkN>(1, pb::flag_byte(0), pb::flag_bit(0, pb::group<&MarkN::mark>(0)),
                             pb::flag_bit(0, pb::u8<&MarkN::n>(0)));
  MarkN row;
  row.mark = true;
  row.n = 3;

  // Act / Assert
  check::expect(pb::validate(s).ok(), "D1 split empty group builds");
  round_trip(s, row, "010303", "D1 empty group mark split");
}

// TypeScript: flags(0, group(0, mark)), u8(0, n): the group's anchor 0 is the next id but it
// takes none, so the u8 has id 0 as well. {mark: true, n: 3} -> 010103, {mark: false, n: 3} ->
// 010003, {n: 1} -> 010001, {} -> RangeError "missing n".
void d1_anchor_group_with_no_takers_packs_as_typescript() {
  // Arrange
  auto s = pb::scheme<MarkN>(1, pb::flags(0, pb::group<&MarkN::mark>(0)), pb::u8<&MarkN::n>(0));
  auto given = pb::scheme<MarkOptN>(1, pb::flags(0, pb::group<&MarkOptN::mark>(0)),
                                    pb::u8<&MarkOptN::n>(0));
  MarkN on;
  on.mark = true;
  on.n = 3;
  MarkN off;
  off.n = 3;
  MarkOptN only_n;
  only_n.n = 1;
  MarkOptN empty;

  // Act / Assert
  check::expect(pb::validate(s).ok(), "D1 anchor group with no takers builds");
  round_trip(s, on, "010103", "D1 handoff mark set, n 3");
  round_trip(s, off, "010003", "D1 handoff mark false, n 3");
  round_trip(given, only_n, "010001", "D1 handoff n only");
  pack_refused(given, empty, 0, "D1 handoff empty row, n missing");
}

// TypeScript and Go refuse `flags(0, group(0, mark)), when(0, eq(0, true), u8(0, v))` at
// construction: `when 0: eq names field id 0, which is not declared earlier in the same scope`.
// C++ builds it: an empty group is the source of an `eq(id, true)` and takes the id of the field
// after it (README, loop 19 notes and "Limits to keep in mind"). Owner decision A: keep and
// document.
void d1_empty_group_as_when_source_differs_from_typescript() {
  // Arrange
  auto s = pb::scheme<Gate>(1, pb::flags(0, pb::group<&Gate::mark>(0)),
                            pb::when(0, pb::eq(0, true), pb::u8<&Gate::v>(0)));
  Gate on;
  on.mark = true;
  on.v = 7;
  Gate off;
  off.v = 7;
  Gate off_clear;
  Gate on_no_body;
  on_no_body.mark = true;

  // Act / Assert: builds and round-trips where TypeScript throws at construction.
  check::expect(pb::validate(s).ok(), "D1 empty group as when source builds in C++");
  round_trip(s, on, "010107", "D1 empty group as when source, mark set");
  round_trip(s, off_clear, "0100", "D1 empty group as when source, mark false");
  pack_refused(s, on_no_body, 0, "D1 empty group as when source, mark set, v missing");
  std::uint8_t buf[16];
  auto p = pb::pack(s, off, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100"),
                "D1 empty group as when source, mark false drops v given");
}

// --- D7: a split flag bit inside a false `when`, the member given ----------------------------

// TypeScript: u8 k; m = flagByte; when(k == 1) { m.bit(u8 a) }; m.bit(u8 b):
// k=1,a=5,b=6 -> 0101030506; k=0,a=5,b=6 -> 01000306 (a's bit set, no a byte); 01000306 unpacks
// to {k: 0, b: 6}, which packs to 01000206.
void d7_split_bit_in_false_when_packs_unpacks_and_repacks_as_typescript() {
  // Arrange
  auto s = pb::scheme<SplitWhen>(
      1, pb::u8<&SplitWhen::k>(0), pb::flag_byte(0),
      pb::when(1, pb::eq(0, 1), pb::flag_bit(0, pb::u8<&SplitWhen::a>(1))),
      pb::flag_bit(0, pb::u8<&SplitWhen::b>(2)));
  std::uint8_t buf[16];
  std::uint8_t again[16];

  // Act
  auto held = pb::pack(s, split_row(1, 5, 6), buf, sizeof(buf));
  bool held_ok = held.ok() && check::same_hex(buf, held.offset, "0101030506");
  auto skipped = pb::pack(s, split_row(0, 5, 6), buf, sizeof(buf));
  bool skipped_ok = skipped.ok() && check::same_hex(buf, skipped.offset, "01000306");
  SplitWhen back;
  auto u = pb::unpack(s, buf, skipped.offset, back);
  auto r = pb::pack(s, back, again, sizeof(again));

  // Assert
  check::expect(pb::validate(s).ok(), "D7 scheme builds");
  check::expect(held_ok, "D7 when holds, pack bytes");
  check::expect(skipped_ok, "D7 when false, a given, pack bytes keep a's bit and no a byte");
  check::expect(u.ok() && back.same_as(split_row(0, kNone, 6)),
                "D7 unpack of 01000306 gives k 0, b 6 and no a");
  check::expect(r.ok() && check::same_hex(again, r.offset, "01000206"),
                "D7 repack of the unpacked row clears a's bit");
}

void d7_split_bit_rows_round_trip_as_typescript() {
  // Arrange
  auto s = pb::scheme<SplitWhen>(
      1, pb::u8<&SplitWhen::k>(0), pb::flag_byte(0),
      pb::when(1, pb::eq(0, 1), pb::flag_bit(0, pb::u8<&SplitWhen::a>(1))),
      pb::flag_bit(0, pb::u8<&SplitWhen::b>(2)));

  // Act / Assert
  round_trip(s, split_row(1, 5, 6), "0101030506", "D7 when holds, a given");
  round_trip(s, split_row(0, kNone, 6), "01000206", "D7 when false, a not given");
  unpack_only(s, "0101030506", split_row(1, 5, 6), "D7 unpack of the full packet");
  unpack_only(s, "01000306", split_row(0, kNone, 6), "D7 unpack of the packet with a's bit set");
}

#pragma GCC diagnostic pop

}  // namespace

int run_core_loop25_probe_d1_d7_host_tests() {
  d1_empty_group_in_flags_packs_as_typescript();
  d1_empty_group_in_a_split_bit_packs_as_typescript();
  d1_anchor_group_with_no_takers_packs_as_typescript();
  d1_empty_group_as_when_source_differs_from_typescript();
  d7_split_bit_in_false_when_packs_unpacks_and_repacks_as_typescript();
  d7_split_bit_rows_round_trip_as_typescript();
  return check::failures();
}
