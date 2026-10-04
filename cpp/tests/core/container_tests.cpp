#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstring>

using check::expect;
using packbin::Array;
using packbin::Entry;
using packbin::Error;
using packbin::Opt;
using packbin::View;

namespace {

View view(char const* s) {
  return View{reinterpret_cast<std::uint8_t const*>(s), std::strlen(s)};
}

bool view_is(View const& v, char const* s) {
  return v.len == std::strlen(s) && std::memcmp(v.data, s, v.len) == 0;
}

struct Numbers {
  Array<std::uint16_t, 4> xs;
  std::uint8_t tail = 0;
};

constexpr auto numbers = packbin::scheme<Numbers>(1, packbin::list<&Numbers::xs>(packbin::u16(0)));
constexpr auto numbers_be =
    packbin::scheme<Numbers>(1, packbin::list<&Numbers::xs>(packbin::be(packbin::u16(0))));

struct Small {
  Array<std::uint8_t, 4> xs;
  std::uint8_t tail = 0;
};

constexpr auto small_then = packbin::scheme<Small>(
    1, packbin::list<&Small::xs>(packbin::u8(0)), packbin::u8<&Small::tail>(0));

void counted_list() {
  Numbers row;
  row.xs.count = 2;
  row.xs.items[0] = 1;
  row.xs.items[1] = 2;
  std::uint8_t buf[16];
  auto p = packbin::pack(numbers, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01020001000200"), "list hex");
  Numbers back;
  auto u = packbin::unpack(numbers, buf, p.offset, back);
  expect(u.ok() && back.xs.count == 2 && back.xs.items[1] == 2, "list unpack");

  row.xs.count = 1;
  auto b = packbin::pack(numbers_be, row, buf, sizeof(buf));
  expect(b.ok() && check::same_hex(buf, b.offset, "0101000001"), "list be");

  Small small;
  small.xs.count = 1;
  small.xs.items[0] = 1;
  small.tail = 2;
  auto t = packbin::pack(small_then, small, buf, sizeof(buf));
  expect(t.ok() && check::same_hex(buf, t.offset, "0101000102"), "list then next field");
  Small small_back;
  auto tu = packbin::unpack(small_then, buf, t.offset, small_back);
  expect(tu.ok() && small_back.xs.count == 1 && small_back.xs.items[0] == 1 &&
             small_back.tail == 2,
         "list next field unpack");

  Numbers empty;
  auto e = packbin::pack(numbers, empty, buf, sizeof(buf));
  expect(e.ok() && check::same_hex(buf, e.offset, "010000"), "list empty");

  std::uint8_t many[13] = {0x01, 0x05, 0x00};
  auto m = packbin::unpack(numbers, many, sizeof(many), back);
  expect(m.error == Error::TooMany && m.offset == 3 && m.needed == 5, "list over capacity");

  std::uint8_t cut[5] = {0x01, 0x03, 0x00, 0x01, 0x00};
  auto c = packbin::unpack(numbers, cut, sizeof(cut), back);
  expect(c.error == Error::ShortPacket && c.field == 0 && c.offset == 5,
         "AC-5 list count past the end");
}

struct Points {
  std::uint16_t sid = 0;
  Array<std::uint16_t, 4> points;
};

void element_ids_start_at_zero() {
  constexpr auto s = packbin::scheme<Points>(0x20, packbin::u16<&Points::sid>(0),
                                             packbin::list<&Points::points>(packbin::u16(0)));
  Points row;
  row.sid = 1;
  row.points.count = 2;
  row.points.items[0] = 7;
  row.points.items[1] = 8;
  std::uint8_t buf[16];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "200100020007000800"), "typed list payload");
}

using Actions = Array<View, 4>;

struct User {
  View name;
  Array<View, 4> roles;
  Array<Entry<Actions>, 4> access;
};

constexpr auto user = packbin::scheme<User>(
    1, packbin::utf8<&User::name>(0), packbin::list<&User::roles>(packbin::utf8(0)),
    packbin::dict<&User::access>(packbin::list(packbin::utf8(0))));

constexpr char const* kUserHex =
    "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265"
    "616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f726502000400"
    "7265616405007772697465";

void set_actions(Actions& a, std::initializer_list<char const*> names) {
  a.count = 0;
  for (auto const* n : names)
    a.items[a.count++] = view(n);
}

void dictionary() {
  User row;
  row.name = view("zxsanny");
  row.roles.count = 2;
  row.roles.items[0] = view("user");
  row.roles.items[1] = view("dispatcher");
  row.access.count = 3;
  row.access.items[0].key = view("channel");
  set_actions(row.access.items[0].value, {"read"});
  row.access.items[1].key = view("map");
  set_actions(row.access.items[1].value, {"read", "gps_fix", "set", "edit"});
  row.access.items[2].key = view("store");
  set_actions(row.access.items[2].value, {"read", "write"});
  std::uint8_t buf[128];
  auto p = packbin::pack(user, row, buf, sizeof(buf));
  expect(p.ok() && p.offset == 104 && check::same_hex(buf, p.offset, kUserHex), "dict hex");

  User back;
  auto u = packbin::unpack(user, buf, p.offset, back);
  expect(u.ok() && view_is(back.name, "zxsanny") && back.roles.count == 2 &&
             view_is(back.roles.items[1], "dispatcher"),
         "dict user and roles");
  expect(back.access.count == 3 && view_is(back.access.items[1].key, "map") &&
             back.access.items[1].value.count == 4 &&
             view_is(back.access.items[1].value.items[1], "gps_fix") &&
             view_is(back.access.items[2].value.items[1], "write"),
         "dict entries");

  struct Empty {
    View name;
    Array<std::uint8_t, 1> xs;
    Array<Entry<View>, 1> m;
  };
  constexpr auto empty_scheme = packbin::scheme<Empty>(
      1, packbin::utf8<&Empty::name>(0), packbin::list<&Empty::xs>(packbin::u8(0)),
      packbin::dict<&Empty::m>(packbin::utf8(0)));
  Empty none;
  none.name = view("");
  auto e = packbin::pack(empty_scheme, none, buf, sizeof(buf));
  expect(e.ok() && check::same_hex(buf, e.offset, "01000000000000"), "dict empty");

  struct Plain {
    Array<Entry<View>, 4> access;
  };
  constexpr auto dup = packbin::scheme<Plain>(1, packbin::dict<&Plain::access>(packbin::utf8(0)));
  std::uint8_t dup_bytes[15];
  check::parse_hex("010200010061010078010061010079", dup_bytes, sizeof(dup_bytes));
  Plain dup_row;
  auto d = packbin::unpack(dup, dup_bytes, sizeof(dup_bytes), dup_row);
  expect(d.error == Error::BadValue && d.offset == 9, "dict duplicate key");
}

struct Pair {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

struct Groups {
  Array<Pair, 2> groups;
};

constexpr auto groups = packbin::scheme<Groups>(
    1, packbin::repeat<&Groups::groups>(0, packbin::u8<&Pair::a>(0), packbin::u8<&Pair::b>(1)));

void repeat_to_the_end() {
  Groups row;
  row.groups.count = 1;
  row.groups.items[0] = Pair{1, 2};
  std::uint8_t buf[8];
  auto p = packbin::pack(groups, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "010102"), "repeat pack");
  Groups back;
  auto u = packbin::unpack(groups, buf, p.offset, back);
  expect(u.ok() && back.groups.count == 1 && back.groups.items[0].b == 2, "repeat one group");

  std::uint8_t left[4] = {1, 1, 2, 3};
  auto l = packbin::unpack(groups, left, sizeof(left), back);
  expect(l.error == Error::ShortPacket && l.field == 1 && l.offset == 4, "repeat leftover");

  std::uint8_t three[7] = {1, 1, 2, 3, 4, 5, 6};
  Groups two;
  auto t = packbin::unpack(groups, three, sizeof(three), two);
  expect(t.error == Error::TooMany && t.field == 0 && t.offset == 5, "AC-2 one group too many");
  expect(two.groups.count == 2 && two.groups.items[1].a == 3 && two.groups.items[1].b == 4,
         "AC-2 groups already read keep their values (S5)");

  auto anchor = packbin::scheme<Groups>(
      1, packbin::repeat<&Groups::groups>(1, packbin::u8<&Pair::a>(0), packbin::u8<&Pair::b>(1)));
  expect(packbin::validate(anchor).error == Error::SchemeInvalid, "repeat wrong anchor");
}

struct Point {
  std::int32_t lat = 0;
  std::int32_t lon = 0;
};

struct Route {
  std::uint16_t sid = 0;
  std::uint16_t owner = 0;
  Opt<std::uint16_t> leg;
  Opt<bool> masked;
  Opt<std::uint16_t> title;
  std::uint8_t n = 0;
  Array<std::uint8_t, 8> kinds;
  Array<Point, 8> points;
  Array<std::uint8_t, 8> mask;
};

constexpr auto route = packbin::scheme<Route>(
    0x34, packbin::u16<&Route::sid>(0), packbin::u16<&Route::owner>(1),
    packbin::flags(2, packbin::u16<&Route::leg>(2), packbin::boolean<&Route::masked>(3),
                   packbin::u16<&Route::title>(4)),
    packbin::u8<&Route::n>(5), packbin::packed<&Route::kinds>(2, 6, 5),
    packbin::times<&Route::points>(7, 5, packbin::i32<&Point::lat>(7),
                                   packbin::i32<&Point::lon>(8)),
    packbin::when(9, packbin::eq(3, 1), packbin::packed<&Route::mask>(1, 9, 5, -1)));

constexpr char const* kRouteHex = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101";

void times_and_route() {
  struct Tail {
    std::uint8_t n = 0;
    Array<Point, 4> points;
    std::uint8_t tail = 0;
  };
  constexpr auto s = packbin::scheme<Tail>(
      1, packbin::u8<&Tail::n>(0),
      packbin::times<&Tail::points>(1, 0, packbin::i32<&Point::lat>(1),
                                    packbin::i32<&Point::lon>(2)),
      packbin::u8<&Tail::tail>(3));
  Tail row;
  row.n = 2;
  row.points.count = 2;
  row.points.items[0] = Point{10, 20};
  row.points.items[1] = Point{30, 40};
  row.tail = 7;
  std::uint8_t buf[32];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf + 1, p.offset - 1, "020a000000140000001e0000002800000007"),
         "times body");

  std::uint8_t raw[27];
  check::parse_hex(kRouteHex, raw, sizeof(raw));
  Route r;
  auto u = packbin::unpack(route, raw, sizeof(raw), r);
  expect(u.ok() && r.sid == 16 && r.kinds.count == 2 && r.kinds.items[0] == 1 &&
             r.kinds.items[1] == 3,
         "route kinds");
  expect(r.points.count == 2 && r.points.items[0].lat == 500000000 &&
             r.points.items[1].lat == 500010000,
         "route lats");
  expect(r.masked.has && r.mask.count == 1 && r.mask.items[0] == 1, "route mask");
  std::uint8_t again[32];
  auto rp = packbin::pack(route, r, again, sizeof(again));
  expect(rp.ok() && check::same_hex(again, rp.offset, kRouteHex), "route repack");

  auto cut = packbin::unpack(route, raw, 24, r);
  expect(cut.error == Error::ShortPacket && cut.field == 8 && cut.needed == 4 &&
             24 - cut.offset == 2,
         "route short lon");
}

}  // namespace

int run_core_container_tests() {
  counted_list();
  element_ids_start_at_zero();
  dictionary();
  repeat_to_the_end();
  times_and_route();
  return check::failures();
}
