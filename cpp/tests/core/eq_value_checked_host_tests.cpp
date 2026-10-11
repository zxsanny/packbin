// AZ-2338: `eq(source, value)` is refused when the scheme is built if the source can never hold
// the value (the comparison could never match). A typed C++ row fixes the source type, so the
// value is the one thing left to check: an integer outside the source's range, or outside 0..3
// for a u2 slot. A valid value builds and packs as before. Host-only.

#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstdint>

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into the table of a scheme
// built at run time in a function this size (see source_kinds_host_tests.cpp); the suppression
// covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

using check::expect;
using packbin::Error;
using packbin::Opt;

namespace {

struct Row {
  Opt<std::uint8_t> a8;
  Opt<std::uint16_t> a16;
  Opt<std::uint32_t> a32;
  Opt<std::uint64_t> a64;
  Opt<std::int8_t> s8;
  Opt<std::int16_t> s16;
  Opt<std::int32_t> s32;
  Opt<std::int64_t> s64;
  Opt<std::uint8_t> slot0;
  Opt<std::uint8_t> slot1;
  Opt<std::uint8_t> v;
};

bool refused_at(packbin::Result r, int field) {
  return r.error == Error::SchemeInvalid && r.field == field;
}

// A source of the given kind, then `when(eq(0, value)) { u8 v }`.
#define SOURCE_SCHEME(NAME, FIELD)                                                       \
  auto NAME(std::int64_t value) {                                                        \
    return packbin::scheme<Row>(                                                         \
        1, FIELD, packbin::when(1, packbin::eq(0, value), packbin::u8<&Row::v>(1)));     \
  }

SOURCE_SCHEME(on_u8, packbin::u8<&Row::a8>(0))
SOURCE_SCHEME(on_u16, packbin::u16<&Row::a16>(0))
SOURCE_SCHEME(on_u32, packbin::u32<&Row::a32>(0))
SOURCE_SCHEME(on_u64, packbin::u64<&Row::a64>(0))
SOURCE_SCHEME(on_i8, packbin::i8<&Row::s8>(0))
SOURCE_SCHEME(on_i16, packbin::i16<&Row::s16>(0))
SOURCE_SCHEME(on_i32, packbin::i32<&Row::s32>(0))
SOURCE_SCHEME(on_i64, packbin::i64<&Row::s64>(0))

auto on_slot(std::int64_t value) {
  return packbin::scheme<Row>(
      1, packbin::u2(packbin::u8<&Row::slot0>(0), packbin::u8<&Row::slot1>(1)),
      packbin::when(2, packbin::eq(1, value), packbin::u8<&Row::v>(2)));
}

template <typename Make>
void edge(Make make, std::int64_t low, std::int64_t high, char const* name) {
  expect(packbin::validate(make(low)).ok(), name);
  expect(packbin::validate(make(high)).ok(), name);
  if (low > INT64_MIN)
    expect(refused_at(packbin::validate(make(low - 1)), 1), name);
  if (high < INT64_MAX)
    expect(refused_at(packbin::validate(make(high + 1)), 1), name);
}

void ac1_a_value_outside_the_source_range_is_refused() {
  edge(on_u8, 0, 255, "AC-1 u8 edges");
  edge(on_u16, 0, 65535, "AC-1 u16 edges");
  edge(on_u32, 0, 4294967295LL, "AC-1 u32 edges");
  edge(on_i8, -128, 127, "AC-1 i8 edges");
  edge(on_i16, -32768, 32767, "AC-1 i16 edges");
  edge(on_i32, -2147483647LL - 1, 2147483647LL, "AC-1 i32 edges");
  expect(packbin::validate(on_u64(0)).ok() && packbin::validate(on_u64(INT64_MAX)).ok(),
         "AC-1 u64 holds every value an int64 can name above 0");
  expect(refused_at(packbin::validate(on_u64(-1)), 1), "AC-1 u64 refuses -1");
  expect(packbin::validate(on_i64(INT64_MIN)).ok() && packbin::validate(on_i64(INT64_MAX)).ok(),
         "AC-1 i64 takes every int64");
  expect(refused_at(packbin::validate(on_u8(300)), 1), "AC-1 eq(u8, 300) names the when");
  expect(refused_at(packbin::validate(on_u8(-1)), 1), "AC-1 eq(u8, -1) names the when");
}

void ac1_a_u2_slot_holds_0_to_3() {
  expect(packbin::validate(on_slot(0)).ok() && packbin::validate(on_slot(3)).ok(),
         "AC-1 u2 slot edges build");
  expect(refused_at(packbin::validate(on_slot(4)), 2), "AC-1 eq(u2 slot, 4) names the when");
  expect(refused_at(packbin::validate(on_slot(-1)), 2), "AC-1 eq(u2 slot, -1) names the when");
}

void ac1_a_refused_scheme_writes_nothing() {
  auto s = on_u8(300);
  Row row;
  row.a8 = 44;
  row.v = 9;
  std::uint8_t buf[8] = {0xaa};
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.error == Error::SchemeInvalid && buf[0] == 0xaa, "AC-1 pack of a refused scheme writes nothing");
}

void ac4_a_valid_value_builds_and_packs_as_before() {
  auto s = on_u8(5);
  Row row;
  row.a8 = 5;
  row.v = 9;
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "010509"), "AC-4 eq(u8, 5) packs 010509");
  Row back;
  auto u = packbin::unpack(s, buf, p.offset, back);
  expect(u.ok() && back.a8.has && back.a8.value == 5 && back.v.has && back.v.value == 9,
         "AC-4 eq(u8, 5) unpacks");
  row.a8 = 4;
  auto q = packbin::pack(s, row, buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, "0104"), "AC-4 a source that differs leaves the body out");
}

}  // namespace

int run_core_eq_value_checked_host_tests() {
  ac1_a_value_outside_the_source_range_is_refused();
  ac1_a_u2_slot_holds_0_to_3();
  ac1_a_refused_scheme_writes_nothing();
  ac4_a_valid_value_builds_and_packs_as_before();
  return check::failures();
}
