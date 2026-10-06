#include "packbin/codec.hpp"

#include "check.hpp"

using check::expect;
using packbin::Array;
using packbin::Error;
using packbin::Opt;

namespace {

constexpr char const* kGoldenHex = "4001000065cd1d00a3e1110100";

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  Opt<std::uint16_t> heading;
  Opt<std::uint8_t> speed;
  Opt<std::int16_t> altitude;
};

constexpr auto position = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::flags(4, packbin::u16<&Position::heading>(4), packbin::u8<&Position::speed>(5),
                   packbin::i16<&Position::altitude>(6)));

struct Six {
  Opt<std::uint8_t> a, b, c, d, e;
  Opt<std::uint16_t> f;
};

constexpr auto six = packbin::scheme<Six>(
    1, packbin::flags(0, packbin::u8<&Six::a>(0), packbin::u8<&Six::b>(1), packbin::u8<&Six::c>(2),
                      packbin::u8<&Six::d>(3), packbin::u8<&Six::e>(4),
                      packbin::u16<&Six::f>(5)));

struct Login {
  Opt<std::uint16_t> sid;
  Opt<std::uint32_t> since;
  Opt<bool> mark;
};

constexpr auto marked =
    packbin::scheme<Login>(1, packbin::flags(0, packbin::group<&Login::mark>(0)));
constexpr auto login = packbin::scheme<Login>(
    1, packbin::flags(0, packbin::group(0, packbin::u16<&Login::sid>(0),
                                        packbin::u32<&Login::since>(1))));

struct Marker {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t kind = 0;
  Opt<std::uint16_t> kind_id;
  std::uint16_t title = 0;
  Opt<bool> hidden;
  Opt<bool> delta;
};

constexpr auto marker = packbin::scheme<Marker>(
    0x20, packbin::u16<&Marker::sid>(0), packbin::i32<&Marker::lat>(1),
    packbin::i32<&Marker::lon>(2), packbin::u8<&Marker::kind>(3),
    packbin::when(4, packbin::eq(3, 1), packbin::u16<&Marker::kind_id>(4)),
    packbin::u16<&Marker::title>(5),
    packbin::flags(6, packbin::boolean<&Marker::hidden>(6), packbin::boolean<&Marker::delta>(7)));

struct Motion {
  Opt<std::uint16_t> heading;
  Opt<std::uint8_t> speed;
};

constexpr auto motion = packbin::scheme<Motion>(
    1, packbin::flag_byte(0), packbin::flag_bit(0, packbin::u16<&Motion::heading>(0)),
    packbin::flag_bit(0, packbin::u8<&Motion::speed>(1)));

// U4 `bitwhen` vector: a split bit inside a `when` that is not taken keeps its bit.
struct BitWhen {
  std::uint8_t k = 0;
  Opt<std::uint8_t> v;
};

constexpr auto bitwhen = packbin::scheme<BitWhen>(
    1, packbin::u8<&BitWhen::k>(0), packbin::flag_byte(0),
    packbin::when(1, packbin::eq(0, 1), packbin::flag_bit(0, packbin::u8<&BitWhen::v>(1))));

template <typename Row, typename S>
packbin::Result packed(S const& s, Row const& row, std::uint8_t* buf, std::size_t cap) {
  return packbin::pack(s, row, buf, cap);
}

void golden_position() {
  Position row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  std::uint8_t buf[16];
  auto p = packed(position, row, buf, sizeof(buf));
  expect(p.ok() && p.offset == 13 && check::same_hex(buf, p.offset, kGoldenHex), "AC-1 golden");
  auto exact = packed(position, row, buf, 13);
  expect(exact.ok() && exact.offset == 13, "S1 buffer exactly the packet size");

  Position back;
  back.heading = 7;
  auto u = packbin::unpack(position, buf, 13, back);
  expect(u.ok() && back.sid == 1 && back.lat == 500000000 && back.lon == 300000000 &&
             back.profile == 1,
         "AC-1 golden unpack");
  expect(!back.heading.has && !back.speed.has && !back.altitude.has, "AC-3 motion absent");

  std::uint8_t trailing[14];
  check::parse_hex("4001000065cd1d00a3e111010099", trailing, sizeof(trailing));
  auto t = packbin::unpack(position, trailing, sizeof(trailing), back);
  expect(t.error == Error::TrailingBytes && t.offset == 13, "trailing byte");
}

void flags_and_stored_zero() {
  std::uint8_t buf[8];
  Six clear;
  auto c = packed(six, clear, buf, sizeof(buf));
  expect(c.ok() && check::same_hex(buf, c.offset, "0100"), "AC-1 clear flags");

  Six set;
  set.f = 0x1234;
  auto s = packed(six, set, buf, sizeof(buf));
  expect(s.ok() && check::same_hex(buf, s.offset, "01203412"), "AC-1 bit 5 is 0x20");

  Six zero;
  zero.f = 0;
  auto z = packed(six, zero, buf, sizeof(buf));
  expect(z.ok() && check::same_hex(buf, z.offset, "01200000"), "AC-3 present 0 is written");
  Six back;
  back.a = 9;
  auto u = packbin::unpack(six, buf, z.offset, back);
  expect(u.ok() && back.f.has && back.f.value == 0 && !back.a.has, "AC-3 zero stays present");

  Six one;
  one.a = 1;
  auto o = packed(six, one, buf, sizeof(buf));
  expect(o.ok() && check::same_hex(buf, o.offset, "010101"), "AC-1 one field bit");

  std::uint8_t cut[3] = {0x01, 0x20, 0x34};
  auto sh = packbin::unpack(six, cut, sizeof(cut), back);
  expect(sh.error == Error::ShortPacket && sh.field == 5 && sh.needed == 2 && sh.offset == 2,
         "short flagged field");
}

void groups_under_flags() {
  std::uint8_t buf[16];
  Login mark;
  mark.mark = true;
  auto m = packed(marked, mark, buf, sizeof(buf));
  expect(m.ok() && check::same_hex(buf, m.offset, "0101"), "AC-1 empty group set");
  Login none;
  auto n = packed(marked, none, buf, sizeof(buf));
  expect(n.ok() && check::same_hex(buf, n.offset, "0100"), "AC-1 empty group clear");
  Login back;
  std::uint8_t on[2] = {0x01, 0x01};
  auto mu = packbin::unpack(marked, on, sizeof(on), back);
  expect(mu.ok() && back.mark.has && back.mark.value, "empty group unpack");

  Login session;
  session.sid = 7;
  session.since = 1000;
  auto s = packed(login, session, buf, sizeof(buf));
  expect(s.ok() && check::same_hex(buf, s.offset, "01010700e8030000"), "AC-1 group adds 6");
  expect(check::same_hex(buf + 2, 6, "0700e8030000"), "AC-1 group body");
  auto a = packed(login, none, buf, sizeof(buf));
  expect(a.ok() && check::same_hex(buf, a.offset, "0100"), "AC-1 group clear adds 0");
  Login absent;
  absent.sid = 3;
  auto au = packbin::unpack(login, buf, a.offset, absent);
  expect(au.ok() && !absent.sid.has && !absent.since.has, "AC-3 group clear unpacks nothing");

  std::uint8_t cut[3] = {0x01, 0x01, 0x07};
  auto sh = packbin::unpack(login, cut, sizeof(cut), absent);
  expect(sh.error == Error::ShortPacket && sh.field == 0 && sh.needed == 2 && sh.offset == 2,
         "group short");

  Login half;
  half.sid = 7;
  auto h = packed(login, half, buf, sizeof(buf));
  expect(h.error == Error::BadValue && h.field == 1, "group needs all its fields");
}

void marker_when_and_booleans() {
  Marker row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.kind = 1;
  row.kind_id = 0;
  std::uint8_t buf[24];
  auto p = packed(marker, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "2001000065cd1d00a3e111010000000000"),
         "AC-1 marker hex");

  row.hidden = true;
  auto h = packed(marker, row, buf, sizeof(buf));
  expect(h.ok() && buf[h.offset - 1] == 0x01, "boolean sets bit 0");
  Marker back;
  auto u = packbin::unpack(marker, buf, h.offset, back);
  expect(u.ok() && back.hidden.has && back.hidden.value && !back.delta.has, "boolean unpack");
  expect(back.kind_id.has && back.kind_id.value == 0 && back.lat == 500000000, "marker fields");
}

void flag_byte_bits() {
  Motion row;
  row.heading = 90;
  std::uint8_t buf[8];
  auto p = packed(motion, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01015a00"), "flag byte vector (Rust)");
  Motion back;
  back.speed = 3;
  auto u = packbin::unpack(motion, buf, p.offset, back);
  expect(u.ok() && back.heading.has && back.heading.value == 90 && !back.speed.has,
         "flag byte unpack");
  row.speed = 4;
  auto both = packed(motion, row, buf, sizeof(buf));
  expect(both.ok() && check::same_hex(buf, both.offset, "01035a0004"), "two flag bits");
}

void flag_bit_inside_untaken_when() {
  BitWhen row;
  row.v = 5;
  std::uint8_t buf[8];
  auto skipped = packed(bitwhen, row, buf, sizeof(buf));
  expect(skipped.ok() && check::same_hex(buf, skipped.offset, "010001"), "bitwhen k=0 hex");
  BitWhen back;
  back.v = 9;
  auto u = packbin::unpack(bitwhen, buf, skipped.offset, back);
  expect(u.ok() && back.k == 0 && !back.v.has, "bitwhen k=0 unpack has no v");

  row.k = 1;
  auto taken = packed(bitwhen, row, buf, sizeof(buf));
  expect(taken.ok() && check::same_hex(buf, taken.offset, "01010105"), "bitwhen k=1 hex");
  BitWhen again;
  auto t = packbin::unpack(bitwhen, buf, taken.offset, again);
  expect(t.ok() && again.k == 1 && again.v.has && again.v.value == 5, "bitwhen k=1 round trip");
}

// AZ-2135 AC-2: a flag byte read inside a `when` is not seen by a bit after it. The bit binds to
// the byte read before the `when`; a byte only inside the `when` leaves the bit without one.
struct ByteInWhen {
  std::uint8_t k = 0;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
};

constexpr auto byte_in_when = packbin::scheme<ByteInWhen>(
    1, packbin::u8<&ByteInWhen::k>(0), packbin::flag_byte(0),
    packbin::when(1, packbin::eq(0, 1), packbin::flag_byte(0),
                  packbin::flag_bit(0, packbin::u8<&ByteInWhen::a>(1))),
    packbin::flag_bit(0, packbin::u8<&ByteInWhen::b>(2)));

void flag_byte_inside_when_is_not_seen_after_it() {
  ByteInWhen row;
  row.b = 6;
  std::uint8_t buf[8];
  auto p = packed(byte_in_when, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01000106"), "AC-2 k=0 hex");
  ByteInWhen back;
  back.a = 9;
  auto u = packbin::unpack(byte_in_when, buf, p.offset, back);
  expect(u.ok() && back.k == 0 && !back.a.has && back.b.has && back.b.value == 6,
         "AC-2 k=0 unpack");

  row.k = 1;
  row.a = 5;
  auto q = packed(byte_in_when, row, buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, "010101010506"), "AC-2 k=1 hex");
  ByteInWhen again;
  auto v = packbin::unpack(byte_in_when, buf, q.offset, again);
  expect(v.ok() && again.a.has && again.a.value == 5 && again.b.has && again.b.value == 6,
         "AC-2 k=1 unpack");

  // The inner byte is 00 here, and the outer byte, not the inner one, decides `b`.
  row.a.reset();
  auto r = packed(byte_in_when, row, buf, sizeof(buf));
  expect(r.ok() && check::same_hex(buf, r.offset, "0101010006"), "AC-2 k=1 without a hex");
  ByteInWhen last;
  auto w = packbin::unpack(byte_in_when, buf, r.offset, last);
  expect(w.ok() && !last.a.has && last.b.has && last.b.value == 6, "AC-2 k=1 without a unpack");

  auto lone = packbin::scheme<ByteInWhen>(
      1, packbin::u8<&ByteInWhen::k>(0),
      packbin::when(1, packbin::eq(0, 1), packbin::flag_byte(0),
                    packbin::flag_bit(0, packbin::u8<&ByteInWhen::a>(1))),
      packbin::flag_bit(0, packbin::u8<&ByteInWhen::b>(2)));
  auto v2 = packbin::validate(lone);
  expect(v2.error == Error::SchemeInvalid && v2.field == 2, "AC-2 no outer byte names b");
}

// Sibling `when` branches each read their own byte of the same number (Rust F5).
constexpr auto two_branches = packbin::scheme<ByteInWhen>(
    1, packbin::u8<&ByteInWhen::k>(0),
    packbin::when(1, packbin::eq(0, 1), packbin::flag_byte(0),
                  packbin::flag_bit(0, packbin::u8<&ByteInWhen::a>(1))),
    packbin::when(2, packbin::eq(0, 2), packbin::flag_byte(0),
                  packbin::flag_bit(0, packbin::u8<&ByteInWhen::b>(2))));

void sibling_when_bytes_stay_apart() {
  ByteInWhen row;
  row.k = 2;
  row.b = 9;
  std::uint8_t buf[8];
  auto p = packed(two_branches, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01020109"), "sibling when bytes hex");
  ByteInWhen back;
  auto u = packbin::unpack(two_branches, buf, p.offset, back);
  expect(u.ok() && !back.a.has && back.b.has && back.b.value == 9, "sibling when bytes unpack");
}

// Unpacks `hex` into `back`, packs it again and reports whether the bytes come out the same.
template <typename Row, typename S>
bool unpacks_and_repacks(S const& s, char const* hex, Row& back) {
  std::uint8_t in[32];
  std::size_t n = check::parse_hex(hex, in, sizeof(in));
  if (!packbin::unpack(s, in, n, back).ok())
    return false;
  std::uint8_t out[32];
  auto p = packbin::pack(s, back, out, sizeof(out));
  return p.ok() && check::same_hex(out, p.offset, hex);
}

// A `when` inside a round: the round's own byte comes back when the `when` ends, while the
// outer byte of the packet stays apart from both (a round reads its own bytes).
struct Round {
  std::uint8_t k = 0;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
};

struct Rounds {
  std::uint8_t n = 0;
  Opt<std::uint8_t> x;
  Array<Round, 4> items;
  Opt<std::uint8_t> y;
};

constexpr auto rounds = packbin::scheme<Rounds>(
    1, packbin::u8<&Rounds::n>(0), packbin::flag_byte(0),
    packbin::flag_bit(0, packbin::u8<&Rounds::x>(1)),
    packbin::times<&Rounds::items>(
        2, 0, packbin::u8<&Round::k>(2), packbin::flag_byte(0),
        packbin::when(3, packbin::eq(2, 1), packbin::flag_byte(0),
                      packbin::flag_bit(0, packbin::u8<&Round::a>(3))),
        packbin::flag_bit(0, packbin::u8<&Round::b>(4))),
    packbin::flag_bit(0, packbin::u8<&Rounds::y>(5)));

void when_in_a_round_keeps_the_round_byte() {
  Rounds row;
  row.n = 3;
  row.x = 3;
  row.y = 4;
  row.items.count = 3;
  row.items.items[0].k = 1;
  row.items.items[0].a = 5;
  row.items.items[0].b = 6;
  row.items.items[1].k = 1;
  row.items.items[1].b = 7;
  row.items.items[2].b = 8;
  char const* hex = "0103030301010105060101000700010804";
  std::uint8_t buf[32];
  auto p = packed(rounds, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, hex), "round when bytes hex");
  Rounds back;
  expect(unpacks_and_repacks(rounds, hex, back), "round when bytes repack");
  expect(back.items.count == 3 && back.x.has && back.y.has && back.y.value == 4 &&
             back.items.items[0].a.has && back.items.items[0].a.value == 5 &&
             back.items.items[0].b.value == 6 && !back.items.items[1].a.has &&
             back.items.items[1].b.has && back.items.items[1].b.value == 7 &&
             !back.items.items[2].a.has && back.items.items[2].b.value == 8,
         "round when bytes values");
}

// A `when` inside a `when`: each level reads its own byte, and a bit after a `when` reads the
// byte of the level it sits in.
struct Nest {
  std::uint8_t k = 0;
  std::uint8_t m = 0;
  Opt<std::uint8_t> a;
  Opt<std::uint8_t> b;
  Opt<std::uint8_t> c;
};

constexpr auto nested = packbin::scheme<Nest>(
    1, packbin::u8<&Nest::k>(0), packbin::flag_byte(0),
    packbin::when(1, packbin::eq(0, 1), packbin::u8<&Nest::m>(1), packbin::flag_byte(0),
                  packbin::when(2, packbin::eq(1, 1), packbin::flag_byte(0),
                                packbin::flag_bit(0, packbin::u8<&Nest::a>(2))),
                  packbin::flag_bit(0, packbin::u8<&Nest::b>(3))),
    packbin::flag_bit(0, packbin::u8<&Nest::c>(4)));

void nested_when_bytes_shadow_in_turn() {
  Nest row;
  row.k = 1;
  row.m = 1;
  row.b = 6;
  std::uint8_t buf[16];
  auto p = packed(nested, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01010001010006"), "nested when inner hex");
  Nest back;
  expect(unpacks_and_repacks(nested, "01010001010006", back) && !back.a.has && back.b.has &&
             back.b.value == 6 && !back.c.has,
         "nested when inner repack");

  row.m = 0;
  auto q = packed(nested, row, buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, "010100000106"), "nested when outer hex");
  Nest again;
  expect(unpacks_and_repacks(nested, "010100000106", again) && !again.a.has && again.b.has &&
             again.b.value == 6 && !again.c.has,
         "nested when outer repack");

  row.m = 1;
  row.a = 5;
  row.b.reset();
  row.c = 7;
  auto r = packed(nested, row, buf, sizeof(buf));
  expect(r.ok() && check::same_hex(buf, r.offset, "0101010100010507"), "nested when c hex");
  Nest last;
  expect(unpacks_and_repacks(nested, "0101010100010507", last) && last.a.has &&
             last.a.value == 5 && !last.b.has && last.c.has && last.c.value == 7,
         "nested when c repack");
}

void flags_overflow() {
  struct Wide {
    std::uint8_t v = 0;
  };
  auto nine = packbin::scheme<Wide>(
      1, packbin::flags(0, packbin::u8(0), packbin::u8(1), packbin::u8(2), packbin::u8(3),
                        packbin::u8(4), packbin::u8(5), packbin::u8(6), packbin::u8(7),
                        packbin::u8(8)));
  auto v = packbin::validate(nine);
  expect(v.error == Error::SchemeInvalid && v.field == 0, "AC-2 nine flag bits");
  auto lost = packbin::scheme<Wide>(1, packbin::flag_bit(0, packbin::u8<&Wide::v>(0)));
  expect(packbin::validate(lost).error == Error::SchemeInvalid, "bit without its flag byte");
}

}  // namespace

int run_core_grouped_tests() {
  golden_position();
  flags_and_stored_zero();
  groups_under_flags();
  marker_when_and_booleans();
  flag_byte_bits();
  flag_bit_inside_untaken_when();
  flag_byte_inside_when_is_not_seen_after_it();
  sibling_when_bytes_stay_apart();
  when_in_a_round_keeps_the_round_byte();
  nested_when_bytes_shadow_in_turn();
  flags_overflow();
  return check::failures();
}
