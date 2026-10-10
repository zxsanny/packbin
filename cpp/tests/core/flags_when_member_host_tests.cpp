// AZ-2120 AC-3, AC-5 and AZ-2128: a `when` that is a member of `flags` (or sits in a group or a
// flag bit under it) is written like any other value: its bit is on exactly when the condition
// holds and its body holds a value. The hex strings are the bytes the C# package gives for the
// same schemes and rows (loop 18 reference table). Host-only.

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

struct W {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> speed;
  Opt<std::uint8_t> extra;
  Opt<std::uint16_t> heading;

  bool same_as(W const& o) const {
    return same_opt(mode, o.mode) && same_opt(speed, o.speed) && same_opt(extra, o.extra) &&
           same_opt(heading, o.heading);
  }
};

W row(int mode, int speed, int extra, int heading) {
  W w;
  if (mode >= 0)
    w.mode = static_cast<std::uint8_t>(mode);
  if (speed >= 0)
    w.speed = static_cast<std::uint8_t>(speed);
  if (extra >= 0)
    w.extra = static_cast<std::uint8_t>(extra);
  if (heading >= 0)
    w.heading = static_cast<std::uint16_t>(heading);
  return w;
}

// -1 leaves the member unset.
constexpr int kNone = -1;

// WA: u8 mode; flags { when(mode == 1) { u8 speed }, u16 heading }.
auto wa() {
  return pb::scheme<W>(1, pb::u8<&W::mode>(0),
                       pb::flags(1, pb::when(1, pb::eq(0, 1), pb::u8<&W::speed>(1)),
                                 pb::u16<&W::heading>(2)));
}

void when_member_of_flags() {
  auto s = wa();
  round_trip(s, row(1, 7, kNone, 90), "010103075a00", "AC-3 W-true");
  round_trip(s, row(0, kNone, kNone, 90), "0100025a00", "AC-3 W-false");
  round_trip(s, row(1, kNone, kNone, 90), "0101025a00", "AC-3 W-true-no-body");
  round_trip(s, row(1, 7, kNone, kNone), "01010107", "AC-3 W-only-when");
  round_trip(s, row(0, kNone, kNone, kNone), "010000", "AC-3 W-only-mode");
}

void when_member_condition_false_drops_the_body_without_an_error() {
  auto s = wa();
  std::uint8_t buf[16];
  auto p = pb::pack(s, row(0, 7, kNone, 90), buf, sizeof(buf));
  unpack_only(s, "0100025a00", row(0, kNone, kNone, 90), "AC-3 W-false-body-given");
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100025a00"),
                "AC-3 W-false-body-given pack bytes");
}

void old_and_new_packets_unpack() {
  auto s = wa();
  unpack_only(s, "0101025a00", row(1, kNone, kNone, 90), "AC-5 W-old-packet");
  unpack_only(s, "010103075a00", row(1, 7, kNone, 90), "AC-5 W-new-packet");
}

// WS: the split form, a flag byte with a bit for the `when` and a bit for `heading`.
auto ws() {
  return pb::scheme<W>(1, pb::u8<&W::mode>(0), pb::flag_byte(0),
                       pb::flag_bit(0, pb::when(1, pb::eq(0, 1), pb::u8<&W::speed>(1))),
                       pb::flag_bit(0, pb::u16<&W::heading>(2)));
}

void when_in_a_flag_bit() {
  auto s = ws();
  round_trip(s, row(1, 7, kNone, 90), "010103075a00", "AC-3 W-split-true");
  round_trip(s, row(0, kNone, kNone, 90), "0100025a00", "AC-3 W-split-false");
  round_trip(s, row(1, kNone, kNone, 90), "0101025a00", "AC-3 W-split-no-body");
  unpack_only(s, "0100025a00", row(0, kNone, kNone, 90), "AC-3 W-split-false-body-given unpack");
  std::uint8_t buf[16];
  auto p = pb::pack(s, row(0, 7, kNone, 90), buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100025a00"),
                "AC-3 W-split-false-body-given pack bytes");
}

// WG: flags { group { when(mode == 1) { u8 speed } }, u16 heading }.
auto wg() {
  return pb::scheme<W>(
      1, pb::u8<&W::mode>(0),
      pb::flags(1, pb::group(1, pb::when(1, pb::eq(0, 1), pb::u8<&W::speed>(1))),
                pb::u16<&W::heading>(2)));
}

void when_in_a_group() {
  auto s = wg();
  round_trip(s, row(1, 7, kNone, 90), "010103075a00", "AC-3 W-group-true");
  round_trip(s, row(0, kNone, kNone, 90), "0100025a00", "AC-3 W-group-false");
  round_trip(s, row(1, kNone, kNone, 90), "0101025a00", "AC-3 W-group-no-body");
  round_trip(s, row(1, 7, kNone, kNone), "01010107", "AC-3 W-group-only-when");
  unpack_only(s, "0101025a00", row(1, kNone, kNone, 90), "AC-5 W-group-old-packet");
  std::uint8_t buf[16];
  auto p = pb::pack(s, row(0, 7, kNone, 90), buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100025a00"),
                "AC-3 W-group-false-body-given pack bytes");
}

// W2: the `when` body holds two values.
auto w2() {
  return pb::scheme<W>(
      1, pb::u8<&W::mode>(0),
      pb::flags(1, pb::when(1, pb::eq(0, 1), pb::u8<&W::speed>(1), pb::u8<&W::extra>(2)),
                pb::u16<&W::heading>(3)));
}

void when_with_two_values() {
  auto s = w2();
  round_trip(s, row(1, 7, 8, 90), "01010307085a00", "AC-3 W-two-values");
  pack_refused(s, row(1, 7, kNone, 90), 2, "AC-3 W-missing-body-value");
}

// GS: flags { group { u8 extra, when(mode == 1) { u8 speed } }, u16 heading }.
auto gs() {
  return pb::scheme<W>(
      1, pb::u8<&W::mode>(0),
      pb::flags(1,
                pb::group(1, pb::u8<&W::extra>(1),
                          pb::when(2, pb::eq(0, 1), pb::u8<&W::speed>(2))),
                pb::u16<&W::heading>(3)));
}

void group_with_a_sibling_and_a_when() {
  auto s = gs();
  round_trip(s, row(1, 7, 4, 90), "01010304075a00", "AC-3 W-group-sibling-true");
  round_trip(s, row(0, kNone, 4, 90), "010003045a00", "AC-3 W-group-sibling-false");
  round_trip(s, row(1, kNone, kNone, 90), "0101025a00", "AC-3 W-group-nothing");
  pack_refused(s, row(1, kNone, 4, 90), 2, "AC-3 W-group-sibling-missing-when-body");
  pack_refused(s, row(1, 7, kNone, 90), 1, "AC-3 W-group-sibling-missing-sibling");
}

// WE: flags { u8 mode, when(mode == 1) { u8 speed } }: the `when` names an earlier member of
// its own `flags`.
auto we() {
  return pb::scheme<W>(
      1, pb::flags(0, pb::u8<&W::mode>(0),
                   pb::when(1, pb::eq(0, 1), pb::u8<&W::speed>(1))));
}

void when_names_an_earlier_member_of_the_same_flags() {
  auto s = we();
  round_trip(s, row(1, 7, kNone, kNone), "01030107", "AC-3 W-same-flags-true");
  round_trip(s, row(1, kNone, kNone, kNone), "010101", "AC-3 W-same-flags-no-body");
  round_trip(s, row(0, kNone, kNone, kNone), "010100", "AC-3 W-same-flags-false-bytes");
  std::uint8_t buf[16];
  auto p = pb::pack(s, row(0, 7, kNone, kNone), buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "010100"),
                "AC-3 W-same-flags-false: speed is not written");
  auto q = pb::pack(s, row(kNone, 7, kNone, kNone), buf, sizeof(buf));
  check::expect(q.ok() && check::same_hex(buf, q.offset, "0100"),
                "AC-3 W-same-flags-no-mode: its bit is clear and the when cannot hold");
  unpack_only(s, "01030107", row(1, 7, kNone, kNone), "AC-5 W-same-flags-unpack");
}

// A `when` whose body is a u2 or a nested group still turns its bit on (the body value at any
// depth counts).
struct Deep {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
  Opt<std::uint8_t> c;

  bool same_as(Deep const& o) const {
    return same_opt(mode, o.mode) && same_opt(a, o.a) && same_opt(b, o.b) &&
           same_opt(c, o.c);
  }
};

void when_body_value_at_any_depth() {
  auto s = pb::scheme<Deep>(
      1, pb::u8<&Deep::mode>(0),
      pb::flags(1, pb::when(1, pb::eq(0, 1),
                            pb::group(1, pb::u8<&Deep::a>(1), pb::u8<&Deep::b>(2)))));
  Deep d;
  d.mode = 1;
  d.b = 6;
  pack_refused(s, d, 1, "AC-3 deep body: group bit on through b, a missing");
  d.a = 5;
  round_trip(s, d, "0101010506", "AC-3 deep body group");
  auto u2s = pb::scheme<Deep>(
      1, pb::u8<&Deep::mode>(0),
      pb::flags(1, pb::when(1, pb::eq(0, 1), pb::u2(pb::u8<&Deep::a>(1), pb::u8<&Deep::b>(2)))));
  Deep e;
  e.mode = 1;
  e.a = 1;
  e.b = 2;
  round_trip(u2s, e, "01010109", "AC-3 deep body u2");
}

// A group whose only value sits in a u2 child is present (it was dropped when `present` did not
// look into a u2).
void group_with_only_a_u2_value() {
  auto s = pb::scheme<Deep>(
      1, pb::flags(0, pb::group(0, pb::u2(pb::u8<&Deep::a>(0), pb::u8<&Deep::b>(1))),
                   pb::u8<&Deep::c>(2)));
  Deep d;
  d.a = 1;
  d.b = 2;
  round_trip(s, d, "010109", "AZ-2128 group with only a u2 value");
}

}  // namespace

int run_core_flags_when_member_host_tests() {
  when_member_of_flags();
  when_member_condition_false_drops_the_body_without_an_error();
  old_and_new_packets_unpack();
  when_in_a_flag_bit();
  when_in_a_group();
  when_with_two_values();
  group_with_a_sibling_and_a_when();
  when_names_an_earlier_member_of_the_same_flags();
  when_body_value_at_any_depth();
  group_with_only_a_u2_value();
  return check::failures();
}
