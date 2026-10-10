// AZ-2304: a flag byte read inside a `flags` member or a flag-bit child is a conditional scope,
// as a closed `when` is: a later bit outside it is refused. Host-only so the firmware runner
// and its scripts stay as they are; the unpack change it checks is in the core.

#include "packbin/codec.hpp"

#include "check.hpp"

using check::expect;
using packbin::Error;
using packbin::Opt;

namespace {

struct Scoped {
  Opt<std::uint8_t> v;
  Opt<std::uint8_t> x;
  Opt<std::uint8_t> b;
};

// AC-1: the only byte 0 sits in a flags member.
void byte_inside_a_flags_member_is_not_seen_after_it() {
  auto s = packbin::scheme<Scoped>(
      1, packbin::flags(0, packbin::group(0, packbin::u8<&Scoped::v>(0), packbin::flag_byte(0),
                                          packbin::flag_bit(0, packbin::u8<&Scoped::x>(1)))),
      packbin::flag_bit(0, packbin::u8<&Scoped::b>(2)));
  auto v = packbin::validate(s);
  expect(v.error == Error::SchemeInvalid && v.field == 2, "AC-1 names b");
  Scoped row;
  row.b = 7;
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.error == Error::SchemeInvalid && p.field == 2, "AC-1 pack returns the status");
}

// AC-2: the only byte 1 sits in a flag-bit child.
void byte_inside_a_flag_bit_child_is_not_seen_after_it() {
  auto s = packbin::scheme<Scoped>(
      1, packbin::flag_byte(0),
      packbin::flag_bit(0, packbin::group(0, packbin::u8<&Scoped::v>(0), packbin::flag_byte(1),
                                          packbin::flag_bit(1, packbin::u8<&Scoped::x>(1)))),
      packbin::flag_bit(1, packbin::u8<&Scoped::b>(2)));
  auto v = packbin::validate(s);
  expect(v.error == Error::SchemeInvalid && v.field == 2, "AC-2 names b");
}

// A byte in one member of `flags` is not seen by a bit in the next member, as in TypeScript and
// Java (Rust lets the members of one `flags` share it).
void byte_in_one_flags_member_is_not_seen_by_the_next() {
  auto s = packbin::scheme<Scoped>(
      1, packbin::flags(0, packbin::group(0, packbin::u8<&Scoped::v>(0), packbin::flag_byte(0)),
                        packbin::group(1, packbin::flag_bit(0, packbin::u8<&Scoped::x>(1)))));
  auto v = packbin::validate(s);
  expect(v.error == Error::SchemeInvalid && v.field == 1, "AC-1 sibling member names x");
}

// A byte inside a flags member is still seen by a bit in the same member.
void byte_in_a_flags_member_serves_its_own_bits() {
  auto s = packbin::scheme<Scoped>(
      1, packbin::flags(0, packbin::group(0, packbin::u8<&Scoped::v>(0), packbin::flag_byte(0),
                                          packbin::flag_bit(0, packbin::u8<&Scoped::x>(1)))));
  expect(packbin::validate(s).ok(), "own bit finds the byte of its member");
}

struct Case {
  char const* hex;
  bool v, x, b;
};

// The hex strings are the bytes the Rust, TypeScript twins give for the same scheme and row.
template <typename S>
void round_trips(S const& s, Case const* cases, std::size_t n, char const* what) {
  for (std::size_t i = 0; i < n; ++i) {
    Scoped row;
    if (cases[i].v)
      row.v = 3;
    if (cases[i].x)
      row.x = 5;
    if (cases[i].b)
      row.b = 7;
    std::uint8_t buf[16];
    auto p = packbin::pack(s, row, buf, sizeof(buf));
    expect(p.ok() && check::same_hex(buf, p.offset, cases[i].hex), what);
    Scoped back;
    back.v = 9;
    back.x = 9;
    back.b = 9;
    auto u = packbin::unpack(s, buf, p.offset, back);
    expect(u.ok() && back.v.has == cases[i].v && back.x.has == cases[i].x &&
               back.b.has == cases[i].b && (!cases[i].v || back.v.value == 3) &&
               (!cases[i].x || back.x.value == 5) && (!cases[i].b || back.b.value == 7),
           what);
    std::uint8_t again[16];
    auto r = packbin::pack(s, back, again, sizeof(again));
    expect(r.ok() && r.offset == p.offset && std::memcmp(again, buf, p.offset) == 0, what);
  }
}

// AC-3: the outer byte 0 is read before the flags member that holds its own byte 0.
constexpr auto outer_then_member = packbin::scheme<Scoped>(
    1, packbin::flag_byte(0),
    packbin::flags(0, packbin::group(0, packbin::u8<&Scoped::v>(0), packbin::flag_byte(0),
                                     packbin::flag_bit(0, packbin::u8<&Scoped::x>(1)))),
    packbin::flag_bit(0, packbin::u8<&Scoped::b>(2)));

void outer_byte_serves_a_bit_after_a_flags_member() {
  Case cases[] = {
      {"01010007", false, false, true},       {"010101030007", true, false, true},
      {"01010103010507", true, true, true},   {"010001030105", true, true, false},
      {"0100010300", true, false, false},     {"010000", false, false, false},
  };
  round_trips(outer_then_member, cases, sizeof(cases) / sizeof(cases[0]),
              "AC-3 flags member rows");
}

// AC-3 with a flag-bit child: byte 0 read at the top, byte 1 guarding the child that holds a
// byte 0 of its own.
constexpr auto outer_then_child = packbin::scheme<Scoped>(
    1, packbin::flag_byte(0), packbin::flag_byte(1),
    packbin::flag_bit(1, packbin::group(0, packbin::u8<&Scoped::v>(0), packbin::flag_byte(0),
                                        packbin::flag_bit(0, packbin::u8<&Scoped::x>(1)))),
    packbin::flag_bit(0, packbin::u8<&Scoped::b>(2)));

void outer_byte_serves_a_bit_after_a_flag_bit_child() {
  Case cases[] = {
      {"01010007", false, false, true},       {"01010103010507", true, true, true},
      {"010001030105", true, true, false},    {"0100010300", true, false, false},
      {"010000", false, false, false},
  };
  round_trips(outer_then_child, cases, sizeof(cases) / sizeof(cases[0]),
              "AC-3 flag-bit child rows");
}

}  // namespace

int run_core_flag_scope_host_tests() {
  byte_inside_a_flags_member_is_not_seen_after_it();
  byte_inside_a_flag_bit_child_is_not_seen_after_it();
  byte_in_one_flags_member_is_not_seen_by_the_next();
  byte_in_a_flags_member_serves_its_own_bits();
  outer_byte_serves_a_bit_after_a_flags_member();
  outer_byte_serves_a_bit_after_a_flag_bit_child();
  return check::failures();
}
