#include "all_kinds.hpp"

#include <cstring>

namespace all_kinds {

namespace {

namespace pb = packbin;

constexpr auto scheme = pb::scheme<Row>(
    0x5a, pb::u8<&Row::u8v>(0), pb::u16<&Row::u16v>(1), pb::be(pb::u32<&Row::u32v>(2)),
    pb::u64<&Row::u64v>(3), pb::i8<&Row::i8v>(4), pb::i16<&Row::i16v>(5), pb::i32<&Row::i32v>(6),
    pb::i64<&Row::i64v>(7), pb::f32<&Row::f32v>(8), pb::f64<&Row::f64v>(9),
    pb::bytes<&Row::raw>(10),
    pb::flags(11, pb::u16<&Row::leg>(11), pb::group(12, pb::u8<&Row::ga>(12), pb::u8<&Row::gb>(13)),
              pb::boolean<&Row::hidden>(14)),
    pb::flag_byte(0), pb::flag_bit(0, pb::u16<&Row::heading>(15)),
    pb::flag_bit(0, pb::u8<&Row::speed>(16)),
    pb::u8<&Row::kind>(17), pb::when(18, pb::eq(17, 1), pb::u16<&Row::kind_id>(18)),
    pb::u16<&Row::payload_len>(19), pb::sized<&Row::payload>(20, 19),
    pb::u2(pb::u8<&Row::q0>(21), pb::u8<&Row::q1>(22), pb::u8<&Row::q2>(23),
           pb::u8<&Row::q3>(24)),
    pb::u8<&Row::nbits>(25), pb::bits<&Row::bits>(26, 25), pb::u8<&Row::nkinds>(27),
    pb::packed<&Row::kinds>(2, 28, 27), pb::u8<&Row::npoints>(29),
    pb::times<&Row::points>(30, 29, pb::i32<&Point::lat>(30), pb::i32<&Point::lon>(31)),
    pb::utf8<&Row::name>(32), pb::list<&Row::xs>(pb::u16(0)), pb::dict<&Row::tags>(pb::utf8(0)),
    pb::repeat<&Row::pairs>(33, pb::u8<&Pair::a>(33), pb::u8<&Pair::b>(34)));

static_assert(pb::validate(scheme).ok(), "all-kinds scheme is valid");

pb::View text(char const* s) {
  return pb::View{reinterpret_cast<std::uint8_t const*>(s), std::strlen(s)};
}

bool same_view(pb::View const& a, pb::View const& b) {
  return a.len == b.len && (a.len == 0 || std::memcmp(a.data, b.data, a.len) == 0);
}

template <typename T>
int differs(pb::Opt<T> const& a, pb::Opt<T> const& b) {
  return (a.has != b.has || (a.has && !(a.value == b.value))) ? 1 : 0;
}

template <typename T, std::size_t N, typename Eq>
int differs(pb::Array<T, N> const& a, pb::Array<T, N> const& b, Eq eq) {
  if (a.count != b.count)
    return 1;
  for (std::size_t i = 0; i < a.count; ++i)
    if (!eq(a.items[i], b.items[i]))
      return 1;
  return 0;
}

}  // namespace

Row sample() {
  Row r;
  r.u8v = 0xab;
  r.u16v = 0x1234;
  r.u32v = 0x01020304u;
  r.u64v = 0x0102030405060708ull;
  r.i8v = -5;
  r.i16v = -300;
  r.i32v = -500000000;
  r.i64v = -1234567890123ll;
  r.f32v = 1.5f;
  r.f64v = -2.25;
  r.raw[0] = 0xde;
  r.raw[1] = 0xad;
  r.raw[2] = 0xbe;
  r.raw[3] = 0xef;
  r.leg = 7;
  r.ga = 1;
  r.gb = 2;
  r.hidden = true;
  r.heading = 90;
  r.kind = 1;
  r.kind_id = 42;
  r.payload_len = 3;
  r.payload.len = 3;
  std::memcpy(r.payload.data, "uav", 3);
  r.q0 = 0;
  r.q1 = 1;
  r.q2 = 2;
  r.q3 = 3;
  r.nbits = 9;
  r.bits.count = 9;
  for (std::size_t i = 0; i < 9; ++i)
    r.bits.items[i] = static_cast<std::uint8_t>(i % 2);
  r.nkinds = 4;
  r.kinds.count = 4;
  for (std::uint8_t i = 0; i < 4; ++i)
    r.kinds.items[i] = i;
  r.npoints = 2;
  r.points.count = 2;
  r.points.items[0] = Point{500000000, 300000000};
  r.points.items[1] = Point{500010000, 300010000};
  r.name = text("zxsanny");
  r.xs.count = 2;
  r.xs.items[0] = 1;
  r.xs.items[1] = 2;
  r.tags.count = 2;
  r.tags.items[0].key = text("map");
  r.tags.items[0].value = text("read");
  r.tags.items[1].key = text("store");
  r.tags.items[1].value = text("write");
  r.pairs.count = 2;
  r.pairs.items[0] = Pair{1, 2};
  r.pairs.items[1] = Pair{3, 4};
  return r;
}

pb::Result pack(Row const& row, std::uint8_t* out, std::size_t cap) {
  return pb::pack(scheme, row, out, cap);
}

pb::Result unpack(std::uint8_t const* data, std::size_t len, Row& row) {
  return pb::unpack(scheme, data, len, row);
}

int mismatched_fields(Row const& a, Row const& b) {
  int n = 0;
  n += a.u8v != b.u8v;
  n += a.u16v != b.u16v;
  n += a.u32v != b.u32v;
  n += a.u64v != b.u64v;
  n += a.i8v != b.i8v;
  n += a.i16v != b.i16v;
  n += a.i32v != b.i32v;
  n += a.i64v != b.i64v;
  n += std::memcmp(&a.f32v, &b.f32v, sizeof(float)) != 0;
  n += std::memcmp(&a.f64v, &b.f64v, sizeof(double)) != 0;
  n += std::memcmp(a.raw, b.raw, sizeof(a.raw)) != 0;
  n += differs(a.leg, b.leg) + differs(a.ga, b.ga);
  n += differs(a.gb, b.gb) + differs(a.hidden, b.hidden) + differs(a.heading, b.heading);
  n += differs(a.speed, b.speed);
  n += a.kind != b.kind;
  n += differs(a.kind_id, b.kind_id);
  n += a.payload_len != b.payload_len;
  n += a.payload.len != b.payload.len ||
       std::memcmp(a.payload.data, b.payload.data, a.payload.len) != 0;
  n += a.q0 != b.q0;
  n += a.q1 != b.q1;
  n += a.q2 != b.q2;
  n += a.q3 != b.q3;
  n += a.nbits != b.nbits;
  auto same_u8 = [](std::uint8_t x, std::uint8_t y) { return x == y; };
  n += differs(a.bits, b.bits, same_u8);
  n += a.nkinds != b.nkinds;
  n += differs(a.kinds, b.kinds, same_u8);
  n += a.npoints != b.npoints;
  n += differs(a.points, b.points,
               [](Point const& x, Point const& y) { return x.lat == y.lat && x.lon == y.lon; });
  n += !same_view(a.name, b.name);
  n += differs(a.xs, b.xs, [](std::uint16_t x, std::uint16_t y) { return x == y; });
  n += differs(a.tags, b.tags, [](pb::Entry<pb::View> const& x, pb::Entry<pb::View> const& y) {
    return same_view(x.key, y.key) && same_view(x.value, y.value);
  });
  n += differs(a.pairs, b.pairs, [](Pair const& x, Pair const& y) {
    return x.a == y.a && x.b == y.b;
  });
  return n;
}

std::size_t table_entries() { return scheme.fields.size(); }

}  // namespace all_kinds
