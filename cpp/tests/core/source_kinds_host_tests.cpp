// AZ-2126: what a `when` or a count may name. A bool is a source of a `when` only for `true`
// (a false bool is absent on the wire, so the test could never match on unpack); a count names
// an integer field only; a float, string or bytes source is refused. Scheme construction
// returns SchemeInvalid with the id of the `when` or the counted field. Host-only so the
// firmware runner and its scripts stay as they are.

#include "packbin/codec.hpp"

#include "check.hpp"

using check::expect;
using packbin::Error;
using packbin::Opt;

namespace {

struct Gate {
  bool on = false;
  Opt<std::uint8_t> v;
};

struct Marked {
  Opt<bool> mark;
  Opt<std::uint8_t> v;
};

struct Presence {
  bool on = false;
  Opt<std::uint8_t> x;
  Opt<std::uint8_t> v;
};

struct Counted {
  bool on = false;
  packbin::View payload;
};

struct Float {
  float f = 0;
  Opt<std::uint8_t> v;
};

bool refused_at(packbin::Result v, int field) {
  return v.error == Error::SchemeInvalid && v.field == field;
}

// AC-1
void eq_on_a_bool_other_than_true_is_refused() {
  auto zero = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::boolean<&Gate::on>(0)),
      packbin::when(1, packbin::eq(0, 0), packbin::u8<&Gate::v>(1)));
  expect(refused_at(packbin::validate(zero), 1), "AC-1 eq(bool, 0) names the when");
  auto no = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::boolean<&Gate::on>(0)),
      packbin::when(1, packbin::eq(0, false), packbin::u8<&Gate::v>(1)));
  expect(refused_at(packbin::validate(no), 1), "AC-1 eq(bool, false) names the when");
  auto two = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::boolean<&Gate::on>(0)),
      packbin::when(1, packbin::eq(0, 2), packbin::u8<&Gate::v>(1)));
  expect(refused_at(packbin::validate(two), 1), "AC-1 eq(bool, 2) names the when");
  auto minus = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::boolean<&Gate::on>(0)),
      packbin::when(1, packbin::eq(0, -1), packbin::u8<&Gate::v>(1)));
  expect(refused_at(packbin::validate(minus), 1), "AC-1 eq(bool, -1) names the when");

  Gate row;
  row.v = 5;
  std::uint8_t buf[8] = {0xaa};
  auto p = packbin::pack(zero, row, buf, sizeof(buf));
  expect(p.error == Error::SchemeInvalid && buf[0] == 0xaa, "AC-1 pack writes nothing");
}

// AC-2
void eq_on_a_bool_with_true_round_trips() {
  auto s = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::boolean<&Gate::on>(0)),
      packbin::when(1, packbin::eq(0, true), packbin::u8<&Gate::v>(1)));
  expect(packbin::validate(s).ok(), "AC-2 eq(bool, true) builds");
  Gate row;
  row.on = true;
  row.v = 5;
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "010105"), "AC-2 packs 010105");
  Gate back;
  auto u = packbin::unpack(s, buf, p.offset, back);
  expect(u.ok() && back.on && back.v.has && back.v.value == 5, "AC-2 unpacks");

  Gate off;
  off.v = 5;
  auto q = packbin::pack(s, off, buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, "0100"), "AC-2 a clear bit leaves the when out");
}

// A bool that is an Opt<bool> member behaves the same.
void eq_on_an_optional_bool() {
  auto bad = packbin::scheme<Marked>(
      1, packbin::flags(0, packbin::boolean<&Marked::mark>(0)),
      packbin::when(1, packbin::eq(0, 0), packbin::u8<&Marked::v>(1)));
  expect(refused_at(packbin::validate(bad), 1), "AC-1 Opt<bool> eq(0) refused");
  auto good = packbin::scheme<Marked>(
      1, packbin::flags(0, packbin::boolean<&Marked::mark>(0)),
      packbin::when(1, packbin::eq(0, true), packbin::u8<&Marked::v>(1)));
  expect(packbin::validate(good).ok(), "AC-1 Opt<bool> eq(true) builds");
}

// GCC 16 at -O2 reports a false -Warray-bounds for the copy into the table of a scheme that is invalid on
// purpose and built at run time (the same scheme as a constexpr value is a compile error, see
// compile-fail/). The suppression covers the functions from here to the pop below.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"

// AZ-2334: an empty group is a presence bit, so `eq(emptyGroup, true)` names it like a bool (as
// Rust does). The empty group takes the id of the field after it; a field of that id wins.
void eq_on_an_empty_group_builds_and_round_trips() {
  auto s = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::group<&Gate::on>(0)),
      packbin::when(0, packbin::eq(0, true), packbin::u8<&Gate::v>(0)));
  expect(packbin::validate(s).ok(), "AZ-2334 eq(emptyGroup, true) builds");
  Gate row;
  row.on = true;
  row.v = 7;
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "010107"), "AZ-2334 packs 010107 (Rust bytes)");
  Gate back;
  auto u = packbin::unpack(s, buf, p.offset, back);
  expect(u.ok() && back.on && back.v.has && back.v.value == 7, "AZ-2334 unpacks");
  Gate off;
  off.v = 7;
  auto q = packbin::pack(s, off, buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, "0100"), "AZ-2334 a clear bit leaves the when out");
  Gate clear;
  auto r = packbin::unpack(s, buf, q.offset, clear);
  expect(r.ok() && !clear.on && !clear.v.has, "AZ-2334 clear bit unpacks to nothing");
}

void eq_on_an_empty_group_other_than_true_is_refused() {
  auto s = packbin::scheme<Gate>(
      1, packbin::flags(0, packbin::group<&Gate::on>(0)),
      packbin::when(0, packbin::eq(0, 0), packbin::u8<&Gate::v>(0)));
  expect(refused_at(packbin::validate(s), 0), "AZ-2334 eq(emptyGroup, 0) names the when");
}

void a_field_with_the_id_of_an_empty_group_stays_the_source() {
  auto s = packbin::scheme<Presence>(
      1, packbin::flags(0, packbin::group<&Presence::on>(0), packbin::u8<&Presence::x>(0)),
      packbin::when(1, packbin::eq(0, 5), packbin::u8<&Presence::v>(1)));
  expect(packbin::validate(s).ok(), "AZ-2334 a field of the same id builds");
  Presence row;
  row.x = 5;
  row.v = 9;
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01020509"),
         "AZ-2334 eq(0, 5) still names the u8 after the empty group");
}

// A `when` names an integer or a bool; anything else is refused.
void when_on_other_kinds_is_refused() {
  auto flt = packbin::scheme<Float>(
      1, packbin::f32<&Float::f>(0),
      packbin::when(1, packbin::eq(0, 1), packbin::u8<&Float::v>(1)));
  expect(refused_at(packbin::validate(flt), 1), "when on a float source refused");
}

// A count names an integer field; a bool count is refused.
void a_bool_count_is_refused() {
  auto sized = packbin::scheme<Counted>(
      1, packbin::flags(0, packbin::boolean<&Counted::on>(0)),
      packbin::sized<&Counted::payload>(1, 0));
  expect(refused_at(packbin::validate(sized), 1), "sized on a bool count names the field");
}
#pragma GCC diagnostic pop

}  // namespace

int run_core_source_kinds_host_tests() {
  eq_on_a_bool_other_than_true_is_refused();
  eq_on_a_bool_with_true_round_trips();
  eq_on_an_optional_bool();
  eq_on_an_empty_group_builds_and_round_trips();
  eq_on_an_empty_group_other_than_true_is_refused();
  a_field_with_the_id_of_an_empty_group_stays_the_source();
  when_on_other_kinds_is_refused();
  a_bool_count_is_refused();
  return check::failures();
}
