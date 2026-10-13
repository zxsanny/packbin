// AZ-2472 (U25): the C++ builder refuses every id outside [0, 32767] at build time. The table
// stores an id as int16, so an id above 32767 wraps: 65536 wraps to 0 and 65537 to 1, both valid
// ids that an earlier field or the field itself can hold. Every refusal case below therefore uses
// an id that wraps to a VALID id (or, for the boundary pair, to a negative id the old code let
// through as "no count"), and each has a control with the wrapped id written out that builds: only
// the range check can refuse the out-of-range spelling. A case refused first by another rule (a
// count nobody wrote, a self reference, the order rule) would pass without the check.
//
// The only id outside the range that builds is a count id of -1 (AC-4): the scheme builds, and
// every pack and unpack returns BadValue naming the field that reads from the never-written count.
// Host-only so the firmware runner and its scripts stay as they are.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstddef>
#include <cstdint>

using packbin::Array;
using packbin::Opt;
using packbin::View;
namespace pb = packbin;

namespace {

// GCC 16 at -O2 reports a false -Warray-bounds for the copy into the table of a scheme that is
// invalid on purpose and built at run time (the same scheme as a constexpr value is a compile
// error, see compile-fail/). The suppression covers the functions below.
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"

bool refused_scheme(pb::Result v, int field) {
  return v.error == pb::Error::SchemeInvalid && v.field == field;
}

// True when the shape check alone (`check_shape`, which reports a flag::Invalid entry) refuses the
// node. It runs before the order and reference rules, so it isolates the range check: a node with
// id 32768 has no earlier field to be wrong against.
template <typename Node>
bool shape_refuses(Node const& node) {
  pb::detail::Check c{};
  pb::detail::check_shape(node.f.data(), 0, Node::size, false, c);
  return c.failed;
}

struct BitsRow {
  std::uint8_t n = 0;
  Array<std::uint8_t, 4> m;
};

struct SizedRow {
  std::uint8_t n = 0;
  View payload;
};

struct TimesItem {
  Opt<std::uint8_t> v;
};

struct TimesRow {
  std::uint8_t n = 0;
  Array<TimesItem, 4> rounds;
};

// --- AC-1: count id outside [0, 32767] refused at build ---------------------------------------

void ac1_count_id_that_wraps_to_a_valid_id_is_refused_at_build() {
  // Arrange: a count id of 65536 wraps to 0, the earlier u8 `n`. The controls spell that 0.
  auto bits_control = pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, 0));
  auto packed_control =
      pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::packed<&BitsRow::m>(1, 1, 0));
  auto times_control = pb::scheme<TimesRow>(
      1, pb::u8<&TimesRow::n>(0), pb::times<&TimesRow::rounds>(1, 0, pb::u8<&TimesItem::v>(1)));
  auto sized_control =
      pb::scheme<SizedRow>(1, pb::u8<&SizedRow::n>(0), pb::sized<&SizedRow::payload>(1, 0));
  auto bits_wrap =
      pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, 65536));
  auto packed_wrap =
      pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::packed<&BitsRow::m>(1, 1, 65536));
  auto times_wrap = pb::scheme<TimesRow>(
      1, pb::u8<&TimesRow::n>(0),
      pb::times<&TimesRow::rounds>(1, 65536, pb::u8<&TimesItem::v>(1)));
  auto sized_wrap =
      pb::scheme<SizedRow>(1, pb::u8<&SizedRow::n>(0), pb::sized<&SizedRow::payload>(1, 65536));

  // Act / Assert: the count id 0 builds; 65536 is SchemeInvalid at the counted field's own id 1.
  check::expect(pb::validate(bits_control).ok(), "AC-1 control bits(1, 0) builds");
  check::expect(pb::validate(packed_control).ok(), "AC-1 control packed(1, 1, 0) builds");
  check::expect(pb::validate(times_control).ok(), "AC-1 control times(1, 0, ...) builds");
  check::expect(pb::validate(sized_control).ok(), "AC-1 control sized(1, 0) builds");
  check::expect(refused_scheme(pb::validate(bits_wrap), 1),
                "AC-1 bits(1, 65536) is SchemeInvalid at the member");
  check::expect(refused_scheme(pb::validate(packed_wrap), 1),
                "AC-1 packed(1, 1, 65536) is SchemeInvalid at the member");
  check::expect(refused_scheme(pb::validate(times_wrap), 1),
                "AC-1 times(1, 65536, ...) is SchemeInvalid at the anchor");
  check::expect(refused_scheme(pb::validate(sized_wrap), 1),
                "AC-1 sized(1, 65536) is SchemeInvalid at the member");
}

void ac1_refused_scheme_packs_and_unpacks_nothing() {
  // Arrange
  auto s = pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, 65536));
  BitsRow row;
  row.n = 1;
  row.m.items[0] = 0;
  row.m.count = 1;
  std::uint8_t buf[16];
  for (auto& b : buf)
    b = 0xaa;
  std::uint8_t const packet[] = {0x01, 0x01, 0x00};
  BitsRow back;

  // Act
  auto p = pb::pack(s, row, buf, sizeof(buf));
  auto u = pb::unpack(s, packet, sizeof(packet), back);

  // Assert: the status is returned, no byte is written, no value is read.
  check::expect(p.error == pb::Error::SchemeInvalid && buf[0] == 0xaa,
                "AC-1 pack of a refused scheme writes nothing");
  check::expect(u.error == pb::Error::SchemeInvalid && back.n == 0 && back.m.count == 0,
                "AC-1 unpack of a refused scheme reads nothing");
}

// The old code accepted these as "no count": a negative int16 skips the reference rule, so the
// scheme built and every pack and unpack then failed with BadValue. 32768 wraps to -32768, 65535
// to -1 (the sentinel spelled by accident) and -2 is a plain negative id.
void ac1_count_id_that_wraps_negative_is_refused_at_build() {
  // Arrange
  auto at_32768 =
      pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, 32768));
  auto at_65535 =
      pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, 65535));
  auto at_minus_two =
      pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, -2));
  auto sentinel = pb::scheme<BitsRow>(1, pb::u8<&BitsRow::n>(0), pb::bits<&BitsRow::m>(1, -1));

  // Act / Assert
  check::expect(refused_scheme(pb::validate(at_32768), 1), "AC-1 bits(1, 32768) is refused");
  check::expect(refused_scheme(pb::validate(at_65535), 1),
                "AC-1 bits(1, 65535) is refused: it wraps to the sentinel -1");
  check::expect(refused_scheme(pb::validate(at_minus_two), 1), "AC-1 bits(1, -2) is refused");
  check::expect(pb::validate(sentinel).ok(), "AC-1 bits(1, -1) is the one id outside that builds");
}

// The boundary pair on the shape check alone. A full scheme with count id 32767 would need 32 768
// fields before it to find a source, so the pair is pinned on the node: 32767 passes, 32768 does
// not, for each of the four counted shapes.
void ac1_count_id_boundary_32767_passes_32768_is_refused() {
  // Act / Assert
  check::expect(!shape_refuses(pb::bits(1, 32767)), "AC-1 bits count 32767 passes");
  check::expect(shape_refuses(pb::bits(1, 32768)), "AC-1 bits count 32768 is refused");
  check::expect(!shape_refuses(pb::packed(1, 1, 32767)), "AC-1 packed count 32767 passes");
  check::expect(shape_refuses(pb::packed(1, 1, 32768)), "AC-1 packed count 32768 is refused");
  check::expect(!shape_refuses(pb::sized(1, 32767)), "AC-1 sized count 32767 passes");
  check::expect(shape_refuses(pb::sized(1, 32768)), "AC-1 sized count 32768 is refused");
  check::expect(!shape_refuses(pb::times(1, 32767, pb::u8(1))), "AC-1 times count 32767 passes");
  check::expect(shape_refuses(pb::times(1, 32768, pb::u8(1))),
                "AC-1 times count 32768 is refused");
}

// --- AC-2: field id outside [0, 32767] refused at build -----------------------------------------

struct OneRow {
  std::uint8_t x = 0;
};

struct TwoRow {
  std::uint8_t a = 0;
  std::uint16_t b = 0;
};

void ac2_field_id_that_wraps_to_a_valid_id_is_refused_at_build() {
  // Arrange: u8(65536) as the only field wraps to 0, the first id; u16(65537) after u8(0) wraps
  // to 1, the next id. The controls spell the wrapped ids.
  auto only_control = pb::scheme<OneRow>(1, pb::u8<&OneRow::x>(0));
  auto second_control =
      pb::scheme<TwoRow>(1, pb::u8<&TwoRow::a>(0), pb::u16<&TwoRow::b>(1));
  auto only_wrap = pb::scheme<OneRow>(1, pb::u8<&OneRow::x>(65536));
  auto second_wrap =
      pb::scheme<TwoRow>(1, pb::u8<&TwoRow::a>(0), pb::u16<&TwoRow::b>(65537));

  // Act / Assert: refused at the wrapped id of the out-of-range field.
  check::expect(pb::validate(only_control).ok(), "AC-2 control u8(0) builds");
  check::expect(pb::validate(second_control).ok(), "AC-2 control u8(0), u16(1) builds");
  check::expect(refused_scheme(pb::validate(only_wrap), 0), "AC-2 u8(65536) is SchemeInvalid");
  check::expect(refused_scheme(pb::validate(second_wrap), 1),
                "AC-2 u16(65537) after u8(0) is SchemeInvalid");

  // The refused scheme packs nothing.
  OneRow row;
  std::uint8_t buf[8];
  for (auto& b : buf)
    b = 0xaa;
  auto p = pb::pack(only_wrap, row, buf, sizeof(buf));
  check::expect(p.error == pb::Error::SchemeInvalid && buf[0] == 0xaa,
                "AC-2 pack of a refused scheme writes nothing");
}

void ac2_field_id_boundary_32767_passes_32768_is_refused() {
  // Act / Assert: on the shape check alone (a field with id 32767 needs 32 767 fields before it).
  check::expect(!shape_refuses(pb::u8(32767)), "AC-2 field id 32767 passes");
  check::expect(shape_refuses(pb::u8(32768)), "AC-2 field id 32768 is refused");
  check::expect(shape_refuses(pb::u16(-2)), "AC-2 field id -2 is refused");
}

// --- AC-3: when anchor outside [0, 32767] refused at build --------------------------------------

struct WhenRow {
  std::uint8_t n = 0;
  Opt<std::uint8_t> x;
};

void ac3_when_anchor_that_wraps_to_a_valid_id_is_refused_at_build() {
  // Arrange: the anchor 65537 wraps to 1, the id of its first child; the condition names the
  // valid source 0. The control spells the anchor 1.
  auto control = pb::scheme<WhenRow>(1, pb::u8<&WhenRow::n>(0),
                                     pb::when(1, pb::eq(0, 1), pb::u8<&WhenRow::x>(1)));
  auto wrap = pb::scheme<WhenRow>(1, pb::u8<&WhenRow::n>(0),
                                  pb::when(65537, pb::eq(0, 1), pb::u8<&WhenRow::x>(1)));

  // Act / Assert
  check::expect(pb::validate(control).ok(), "AC-3 control when(1, ...) builds");
  check::expect(refused_scheme(pb::validate(wrap), 1),
                "AC-3 when(65537, ...) is SchemeInvalid at the anchor");

  // The refused scheme packs nothing.
  WhenRow row;
  row.n = 1;
  std::uint8_t buf[8];
  for (auto& b : buf)
    b = 0xaa;
  auto p = pb::pack(wrap, row, buf, sizeof(buf));
  check::expect(p.error == pb::Error::SchemeInvalid && buf[0] == 0xaa,
                "AC-3 pack of a refused scheme writes nothing");
}

void ac3_when_anchor_boundary_32767_passes_32768_is_refused() {
  // Act / Assert: the shape check alone, so the anchor-equals-first-child rule is not reached.
  check::expect(!shape_refuses(pb::when(32767, pb::eq(0, 1), pb::u8(1))),
                "AC-3 when anchor 32767 passes");
  check::expect(shape_refuses(pb::when(32768, pb::eq(0, 1), pb::u8(1))),
                "AC-3 when anchor 32768 is refused");
}

// --- AC-4: count id -1 builds; pack and unpack return BadValue naming the member ----------------

struct SentinelRow {
  Array<std::uint8_t, 4> m;
};

void ac4_count_id_minus_one_builds_and_pack_and_unpack_return_badvalue() {
  // Arrange: bits<&SentinelRow::m>(0, -1); the count id -1 is the sentinel for "never written".
  auto s = pb::scheme<SentinelRow>(1, pb::bits<&SentinelRow::m>(0, -1));
  SentinelRow row;
  row.m.items[0] = 1;
  row.m.count = 1;
  std::uint8_t buf[8];
  for (auto& b : buf)
    b = 0xaa;
  std::uint8_t const packet[] = {0x01};
  SentinelRow back;

  // Act
  auto p = pb::pack(s, row, buf, sizeof(buf));
  auto u = pb::unpack(s, packet, sizeof(packet), back);

  // Assert: the scheme builds; pack and unpack return BadValue naming the counted member.
  check::expect(pb::validate(s).ok(), "AC-4 bits(0, -1) builds");
  check::expect(p.error == pb::Error::BadValue && p.field == 0,
                "AC-4 pack returns BadValue naming the member");
  check::expect(buf[0] == 0x01 && buf[1] == 0xaa,
                "AC-4 pack wrote the type number only, no count-driven byte");
  check::expect(u.error == pb::Error::BadValue && u.field == 0,
                "AC-4 unpack returns BadValue naming the member");
  check::expect(back.m.count == 0, "AC-4 unpack parsed no value");
}

#pragma GCC diagnostic pop

}  // namespace

int run_core_builder_id_range_host_tests() {
  ac1_count_id_that_wraps_to_a_valid_id_is_refused_at_build();
  ac1_refused_scheme_packs_and_unpacks_nothing();
  ac1_count_id_that_wraps_negative_is_refused_at_build();
  ac1_count_id_boundary_32767_passes_32768_is_refused();
  ac2_field_id_that_wraps_to_a_valid_id_is_refused_at_build();
  ac2_field_id_boundary_32767_passes_32768_is_refused();
  ac3_when_anchor_that_wraps_to_a_valid_id_is_refused_at_build();
  ac3_when_anchor_boundary_32767_passes_32768_is_refused();
  ac4_count_id_minus_one_builds_and_pack_and_unpack_return_badvalue();
  return check::failures();
}
