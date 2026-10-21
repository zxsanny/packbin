// AZ-3133 (AC-3): an empty group is a presence bit (AZ-2334), so `eq(emptyGroup, true)` names it
// like a bool. Behind a `when` that is clear the bit is absent and the `when` that names it is
// false: u8 mode; when(mode == 1) { u8 a; flags { group } }; when(on == true) { u8 b }. The same
// three rows as the bool corpus cases (pack_when_of_*_bool_source), with `a` written before the
// flags byte: an empty group takes the order id of the field after it, so when a field follows the
// flags inside the `when` (the bool corpus order, flags then `a`) that field has the group's id and
// stays the source (AZ-2334, "a field of that id wins"): `eq(1, true)` then names `a`. The packets
// are the bool ones with `a` and the flags byte swapped. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstddef>
#include <cstdint>

#pragma GCC diagnostic ignored "-Warray-bounds"

using check::expect;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct GroupSource {
  Opt<std::uint8_t> mode;
  bool on = false;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
};

// u8 mode; when(mode == 1) { u8 a; flags { group on } }; when(on == true) { u8 b }
auto group_source_scheme() {
  return pb::scheme<GroupSource>(
      1, pb::u8<&GroupSource::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u8<&GroupSource::a>(1),
               pb::flags(2, pb::group<&GroupSource::on>(2))),
      pb::when(2, pb::eq(2, true), pb::u8<&GroupSource::b>(2)));
}

GroupSource make_row(int mode, bool on) {
  GroupSource r;
  r.mode = static_cast<std::uint8_t>(mode);
  r.on = on;
  r.a = 7;
  r.b = 5;
  return r;
}

void pack_row(char const* name, int mode, bool on, char const* hex) {
  // Arrange
  auto s = group_source_scheme();
  GroupSource row = make_row(mode, on);
  std::uint8_t buf[16];

  // Act
  auto p = pb::pack(s, row, buf, sizeof(buf));

  // Assert
  expect(pb::validate(s).ok(), name);
  expect(p.ok() && check::same_hex(buf, p.offset, hex), name);
}

void ac3_group_source_skipped() {
  pack_row("AC-3 mode 0, group source skipped, packet 0100", 0, true, "0100");

  // Arrange
  auto s = group_source_scheme();
  std::uint8_t want[2];
  std::size_t n = check::parse_hex("0100", want, sizeof(want));

  // Act
  GroupSource back;
  auto u = pb::unpack(s, want, n, back);

  // Assert
  expect(u.ok() && back.mode.has && back.mode.value == 0 && !back.on && !back.a.has && !back.b.has,
         "AC-3 mode 0 unpacks to the mode alone");
}

void ac3_group_source_held() {
  pack_row("AC-3 mode 1, group present, packet 0101070105", 1, true, "0101070105");
  pack_row("AC-3 mode 1, group absent, packet 01010700", 1, false, "01010700");

  // Arrange
  auto s = group_source_scheme();
  std::uint8_t want[8];
  std::size_t n = check::parse_hex("0101070105", want, sizeof(want));

  // Act
  GroupSource back;
  auto u = pb::unpack(s, want, n, back);

  // Assert
  expect(u.ok() && back.on && back.a.has && back.a.value == 7 && back.b.has && back.b.value == 5,
         "AC-3 held group source unpacks with b");
}

}  // namespace

int run_core_when_group_source_host_tests() {
  ac3_group_source_skipped();
  ac3_group_source_held();
  return check::failures();
}
