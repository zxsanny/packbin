#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstring>
#include <initializer_list>

using check::expect;
using packbin::Array;
using packbin::Entry;
using packbin::Error;
using packbin::Opt;
using packbin::Text;

namespace {

template <std::size_t N>
void put_text(Text<N>& t, char const* s) {
  t.len = static_cast<std::uint16_t>(std::strlen(s));
  std::memcpy(t.data, s, t.len);
}

template <std::size_t N>
bool text_is(Text<N> const& t, char const* s) {
  return t.len == std::strlen(s) && std::memcmp(t.data, s, t.len) == 0;
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

using Word = Text<16>;
using Actions = Array<Word, 4>;

struct User {
  Word name;
  Array<Word, 4> roles;
  Array<Entry<Actions, Word>, 4> access;
};

constexpr auto user = packbin::scheme<User>(
    1, packbin::utf8<&User::name>(0), packbin::list<&User::roles>(packbin::utf8(0)),
    packbin::dict<&User::access>(packbin::list(packbin::utf8(0))));

// The ring packet `ref.user` of fixtures/text/vectors.txt.
constexpr char const* kUserHex =
    "01062bfcfee119b20200030ba818078a8b1ca4ed51800300056b6aa330b00100032b0128036ae9c80400032b0128"
    "08106770735f66697803ea04800348516404ca25f0000200032b0128048bbc2c80";

void set_actions(Actions& a, std::initializer_list<char const*> names) {
  a.count = 0;
  for (auto const* n : names)
    put_text(a.items[a.count++], n);
}

void dictionary() {
  User row;
  put_text(row.name, "zxsanny");
  row.roles.count = 2;
  put_text(row.roles.items[0], "user");
  put_text(row.roles.items[1], "dispatcher");
  row.access.count = 3;
  put_text(row.access.items[0].key, "channel");
  set_actions(row.access.items[0].value, {"read"});
  put_text(row.access.items[1].key, "map");
  set_actions(row.access.items[1].value, {"read", "gps_fix", "set", "edit"});
  put_text(row.access.items[2].key, "store");
  set_actions(row.access.items[2].value, {"read", "write"});
  std::uint8_t buf[128];
  packbin::Scratch<16> scratch;
  auto p = packbin::pack(user, row, buf, sizeof(buf), scratch);
  expect(p.ok() && p.offset == 79 && check::same_hex(buf, p.offset, kUserHex), "dict hex");

  User back;
  auto u = packbin::unpack(user, buf, p.offset, back);
  expect(u.ok() && text_is(back.name, "zxsanny") && back.roles.count == 2 &&
             text_is(back.roles.items[1], "dispatcher"),
         "dict user and roles");
  expect(back.access.count == 3 && text_is(back.access.items[1].key, "map") &&
             back.access.items[1].value.count == 4 &&
             text_is(back.access.items[1].value.items[1], "gps_fix") &&
             text_is(back.access.items[2].value.items[1], "write"),
         "dict entries");

  struct Empty {
    Text<4> name;
    Array<std::uint8_t, 1> xs;
    Array<Entry<Text<4>, Text<4>>, 1> m;
  };
  constexpr auto empty_scheme = packbin::scheme<Empty>(
      1, packbin::utf8<&Empty::name>(0), packbin::list<&Empty::xs>(packbin::u8(0)),
      packbin::dict<&Empty::m>(packbin::utf8(0)));
  Empty none;
  auto e = packbin::pack(empty_scheme, none, buf, sizeof(buf), scratch);
  expect(e.ok() && check::same_hex(buf, e.offset, "010000000000"), "dict empty");

  struct Scores {
    Array<Entry<std::uint8_t, Text<4>>, 4> m;
  };
  constexpr auto scores = packbin::scheme<Scores>(1, packbin::dict<&Scores::m>(packbin::u8(0)));
  Scores sorted;
  sorted.m.count = 2;
  put_text(sorted.m.items[0].key, "a");
  sorted.m.items[0].value = 2;
  put_text(sorted.m.items[1].key, "b");
  sorted.m.items[1].value = 1;
  auto so = packbin::pack(scores, sorted, buf, sizeof(buf), scratch);
  expect(so.ok() && check::same_hex(buf, so.offset, "01020002106102021062" "01"),
         "dict README example");
  Scores unsorted;
  unsorted.m.count = 2;
  put_text(unsorted.m.items[0].key, "b");
  unsorted.m.items[0].value = 1;
  put_text(unsorted.m.items[1].key, "a");
  unsorted.m.items[1].value = 2;
  auto us = packbin::pack(scores, unsorted, buf, sizeof(buf), scratch);
  expect(us.error == Error::BadValue, "dict keys must ascend in unsigned byte order");
  put_text(unsorted.m.items[0].key, "a");
  auto same = packbin::pack(scores, unsorted, buf, sizeof(buf), scratch);
  expect(same.error == Error::BadValue, "dict pack refuses a repeated key");

  struct Plain {
    Array<Entry<Text<4>, Text<4>>, 4> access;
  };
  constexpr auto dup = packbin::scheme<Plain>(1, packbin::dict<&Plain::access>(packbin::utf8(0)));
  std::uint8_t dup_bytes[15];
  check::parse_hex("010200021061021078021061021079", dup_bytes, sizeof(dup_bytes));
  Plain dup_row;
  auto d = packbin::unpack(dup, dup_bytes, sizeof(dup_bytes), dup_row);
  expect(d.error == Error::BadValue && d.offset == 9, "dict duplicate key");
}

using OpFields = Array<Entry<Word, Text<8>>, 2>;
using OpRows = Array<OpFields, 2>;

struct Nested {
  Array<Entry<OpRows, Text<8>>, 2> access;
};

constexpr auto nested = packbin::scheme<Nested>(
    1, packbin::dict<&Nested::access>(packbin::list(packbin::dict(packbin::utf8(0)))));

// The ring packet `ref.nested` of fixtures/text/vectors.txt.
constexpr char const* kNestedHex =
    "010200036ae9c8010001000209f908106770735f66697804ca25f000020001000209f9032b012801000209f9"
    "048bbc2c80";

void set_op(OpFields& fields, char const* op) {
  fields.count = 1;
  put_text(fields.items[0].key, "op");
  put_text(fields.items[0].value, op);
}

void dict_of_lists_of_dicts() {
  Nested row;
  row.access.count = 2;
  put_text(row.access.items[0].key, "map");
  row.access.items[0].value.count = 1;
  set_op(row.access.items[0].value.items[0], "gps_fix");
  put_text(row.access.items[1].key, "store");
  row.access.items[1].value.count = 2;
  set_op(row.access.items[1].value.items[0], "read");
  set_op(row.access.items[1].value.items[1], "write");
  std::uint8_t buf[64];
  packbin::Scratch<16> scratch;
  auto p = packbin::pack(nested, row, buf, sizeof(buf), scratch);
  expect(p.ok() && check::same_hex(buf, p.offset, kNestedHex), "nested pair hex");

  Nested back;
  auto u = packbin::unpack(nested, buf, p.offset, back);
  expect(u.ok() && back.access.count == 2 && back.access.items[1].value.count == 2 &&
             text_is(back.access.items[1].value.items[1].items[0].value, "write") &&
             text_is(back.access.items[0].value.items[0].items[0].key, "op"),
         "nested pair unpack");
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

// A container that reuses a flag-byte number keeps its own byte; the outer bit after it reads
// the outer byte (AZ-2078, AC-1 and AC-2).
struct Item {
  Opt<std::uint8_t> x;
};

struct Reused {
  std::uint8_t n = 0;
  Array<Item, 4> items;
  Opt<std::uint16_t> tail;
};

constexpr auto reused = packbin::scheme<Reused>(
    1, packbin::u8<&Reused::n>(0), packbin::flag_byte(0),
    packbin::times<&Reused::items>(1, 0, packbin::flag_byte(0),
                                   packbin::flag_bit(0, packbin::u8<&Item::x>(1))),
    packbin::flag_bit(0, packbin::u16<&Reused::tail>(2)));

void flag_byte_per_scope() {
  Reused row;
  row.n = 1;
  row.items.count = 1;
  row.tail = 0x0302;
  std::uint8_t buf[16];
  auto p = packbin::pack(reused, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "010101000203"), "AC-1 reused byte packs");
  Reused back;
  auto u = packbin::unpack(reused, buf, p.offset, back);
  expect(u.ok() && u.offset == 6 && back.tail.has && back.tail.value == 0x0302 &&
             back.items.count == 1 && !back.items.items[0].x.has,
         "AC-1 reused byte unpacks");

  Reused inner;
  inner.n = 1;
  inner.items.count = 1;
  inner.items.items[0].x = 7;
  auto q = packbin::pack(reused, inner, buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, "0101000107"), "AC-2 inner bit packs");
  Reused again;
  auto v = packbin::unpack(reused, buf, q.offset, again);
  expect(v.ok() && !again.tail.has && again.items.count == 1 && again.items.items[0].x.has &&
             again.items.items[0].x.value == 7,
         "AC-2 inner bit unpacks");
}

// A repeat or times with no member reads no bytes in any round, so the scheme is refused at
// construction (AZ-2390) and neither pack nor unpack can spin through its rounds.
struct Zero {
  std::uint8_t k = 0;
};

struct ZeroBound {
  std::uint8_t k = 0;
  Array<Zero, 4> items;
};

void empty_round_body_is_refused() {
  auto unbound = packbin::scheme<Zero>(1, packbin::u8<&Zero::k>(0), packbin::repeat(1));
  auto bound = packbin::scheme<ZeroBound>(1, packbin::u8<&ZeroBound::k>(0),
                                          packbin::repeat<&ZeroBound::items>(1));
  std::uint8_t data[3] = {1, 5, 9};
  Zero a;
  auto u = packbin::unpack(unbound, data, sizeof(data), a);
  expect(u.error == Error::SchemeInvalid && u.field == 1, "AZ-2390 unbound empty repeat");
  ZeroBound b;
  auto w = packbin::unpack(bound, data, sizeof(data), b);
  expect(w.error == Error::SchemeInvalid && w.field == 1, "AZ-2390 bound empty repeat");

  struct Spin {
    std::uint32_t n = 0;
  };
  auto spin = packbin::scheme<Spin>(1, packbin::u32<&Spin::n>(0), packbin::times(1, 0));
  std::uint8_t huge[5] = {1, 0xff, 0xff, 0xff, 0xff};
  Spin s;
  auto t = packbin::unpack(spin, huge, sizeof(huge), s);
  expect(t.error == Error::SchemeInvalid && t.field == 1, "AZ-2390 empty-body times");
}

}  // namespace

int run_core_container_tests() {
  counted_list();
  element_ids_start_at_zero();
  dictionary();
  dict_of_lists_of_dicts();
  repeat_to_the_end();
  times_and_route();
  flag_byte_per_scope();
  empty_round_body_is_refused();
  return check::failures();
}
