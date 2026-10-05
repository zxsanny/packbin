#include "packbin/packbin.hpp"

#include <cstdio>
#include <cstring>
#include <initializer_list>
#include <string>

namespace {

using packbin::Array;
using packbin::Entry;
using packbin::View;

View view(char const* s) {
  return View{reinterpret_cast<std::uint8_t const*>(s), std::strlen(s)};
}

bool view_is(View const& v, char const* s) {
  return v.len == std::strlen(s) && std::memcmp(v.data, s, v.len) == 0;
}

using Names = Array<View, 8>;

void set_names(Names& names, std::initializer_list<char const*> items) {
  names.count = 0;
  for (auto const* item : items)
    names.items[names.count++] = view(item);
}

bool names_are(Names const& names, std::initializer_list<char const*> items) {
  if (names.count != items.size())
    return false;
  std::size_t i = 0;
  for (auto const* item : items) {
    if (!view_is(names.items[i++], item))
      return false;
  }
  return true;
}

struct User {
  View name;
  Names roles;
  Array<Entry<Names>, 8> access;
};

constexpr auto user_scheme = packbin::scheme<User>(
    1, packbin::utf8<&User::name>(0), packbin::list<&User::roles>(packbin::utf8(0)),
    packbin::dict<&User::access>(packbin::list(packbin::utf8(0))));

User user_row() {
  User row;
  row.name = view("zxsanny");
  set_names(row.roles, {"user", "dispatcher"});
  row.access.count = 3;
  row.access.items[0].key = view("channel");
  set_names(row.access.items[0].value, {"read"});
  row.access.items[1].key = view("map");
  set_names(row.access.items[1].value, {"read", "gps_fix", "set", "edit"});
  row.access.items[2].key = view("store");
  set_names(row.access.items[2].value, {"read", "write"});
  return row;
}

Names const* find(Array<Entry<Names>, 8> const& access, char const* key) {
  for (std::size_t i = 0; i < access.count; ++i) {
    if (view_is(access.items[i].key, key))
      return &access.items[i].value;
  }
  return nullptr;
}

using Fields = Array<Entry<View>, 4>;
using Rows = Array<Fields, 4>;

struct Nested {
  Array<Entry<Rows>, 4> access;
};

constexpr auto nested_scheme = packbin::scheme<Nested>(
    1, packbin::dict<&Nested::access>(packbin::list(packbin::dict(packbin::utf8(0)))));

void set_op(Fields& fields, char const* op) {
  fields.count = 1;
  fields.items[0].key = view("op");
  fields.items[0].value = view(op);
}

bool op_is(Fields const& fields, char const* op) {
  return fields.count == 1 && view_is(fields.items[0].key, "op") &&
         view_is(fields.items[0].value, op);
}

Nested nested_row() {
  Nested row;
  row.access.count = 2;
  row.access.items[0].key = view("map");
  row.access.items[0].value.count = 1;
  set_op(row.access.items[0].value.items[0], "gps_fix");
  row.access.items[1].key = view("store");
  row.access.items[1].value.count = 2;
  set_op(row.access.items[1].value.items[0], "read");
  set_op(row.access.items[1].value.items[1], "write");
  return row;
}

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  packbin::Opt<std::uint16_t> heading;
  packbin::Opt<std::uint8_t> speed;
  packbin::Opt<std::int16_t> altitude;
};

constexpr auto position_scheme = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::flags(4, packbin::u16<&Position::heading>(4), packbin::u8<&Position::speed>(5),
                   packbin::i16<&Position::altitude>(6)));

Position position_row() {
  Position row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  return row;
}

constexpr std::size_t kMax = 512;

std::size_t parse_hex(std::string const& hex, std::uint8_t* out) {
  std::size_t n = hex.size() / 2;
  if (n > kMax)
    return 0;
  for (std::size_t i = 0; i < n; ++i)
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  return n;
}

int print(packbin::Result r, std::uint8_t const* buf) {
  if (!r.ok())
    return 1;
  for (std::size_t i = 0; i < r.offset; ++i)
    std::printf("%02x", buf[i]);
  std::printf("\n");
  return 0;
}

bool open_session(packbin::PackSession& s, bool opener) {
  std::uint8_t seed[32];
  for (std::size_t i = 0; i < sizeof(seed); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  std::uint8_t nonce[16] = {1};
  if (!s.load(seed, sizeof(seed)))
    return false;
  return opener ? s.start(nonce, sizeof(nonce)) : s.join(nonce, sizeof(nonce));
}

bool user_ok(std::uint8_t const* data, std::size_t len) {
  User got;
  if (!packbin::unpack(user_scheme, data, len, got).ok())
    return false;
  auto const* channel = find(got.access, "channel");
  auto const* map = find(got.access, "map");
  auto const* store = find(got.access, "store");
  return view_is(got.name, "zxsanny") && names_are(got.roles, {"user", "dispatcher"}) &&
         got.access.count == 3 && channel && names_are(*channel, {"read"}) && map &&
         names_are(*map, {"read", "gps_fix", "set", "edit"}) && store &&
         names_are(*store, {"read", "write"});
}

bool nested_ok(std::uint8_t const* data, std::size_t len) {
  Nested got;
  if (!packbin::unpack(nested_scheme, data, len, got).ok() || got.access.count != 2)
    return false;
  auto const& map = got.access.items[0];
  auto const& store = got.access.items[1];
  return view_is(map.key, "map") && map.value.count == 1 && op_is(map.value.items[0], "gps_fix") &&
         view_is(store.key, "store") && store.value.count == 2 &&
         op_is(store.value.items[0], "read") && op_is(store.value.items[1], "write");
}

bool session_ok(std::uint8_t* data, std::size_t len) {
  packbin::PackSession waiter;
  Position got;
  if (!open_session(waiter, false) || !waiter.unpack(position_scheme, data, len, got).ok())
    return false;
  return got.sid == 1 && got.lat == 500000000 && got.lon == 300000000 && got.profile == 1 &&
         !got.heading.has && !got.speed.has && !got.altitude.has;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2)
    return 2;
  std::string cmd = argv[1];
  std::uint8_t buf[kMax];
  if (cmd == "pack-user")
    return print(packbin::pack(user_scheme, user_row(), buf, sizeof(buf)), buf);
  if (cmd == "pack-nested")
    return print(packbin::pack(nested_scheme, nested_row(), buf, sizeof(buf)), buf);
  if (cmd == "pack-session") {
    packbin::PackSession opener;
    if (!open_session(opener, true))
      return 1;
    return print(opener.pack(position_scheme, position_row(), buf, sizeof(buf)), buf);
  }
  if (argc < 3)
    return 2;
  std::size_t len = parse_hex(argv[2], buf);
  if (cmd == "unpack-user")
    return user_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-nested")
    return nested_ok(buf, len) ? 0 : 1;
  if (cmd == "unpack-session")
    return session_ok(buf, len) ? 0 : 1;
  return 2;
}
