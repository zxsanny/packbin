#include "packbin/packbin.hpp"

#include <cstdlib>
#include <iostream>
#include <string>

namespace {

std::shared_ptr<packbin::ValueList> strs(std::initializer_list<char const*> names) {
  auto list = std::make_shared<packbin::ValueList>();
  for (auto const* name : names)
    list->items.push_back(packbin::Value{std::string(name)});
  return list;
}

packbin::Value one_op(char const* op) {
  auto fields = std::make_shared<packbin::ValueMap>();
  fields->items.emplace("op", packbin::Value{std::string(op)});
  return packbin::Value{fields};
}

auto user_scheme() {
  return packbin::scheme(1, {
      packbin::utf8(0),
      packbin::list("roles", packbin::utf8(0)),
      packbin::dict("access", packbin::list("actions", packbin::utf8(0))),
  });
}

packbin::Values user_values() {
  auto access = std::make_shared<packbin::ValueMap>();
  access->items.emplace("channel", packbin::Value{strs({"read"})});
  access->items.emplace("map", packbin::Value{strs({"read", "gps_fix", "set", "edit"})});
  access->items.emplace("store", packbin::Value{strs({"read", "write"})});
  packbin::Values values;
  values.emplace("0", packbin::Value{std::string("zxsanny")});
  values.emplace("roles", packbin::Value{strs({"user", "dispatcher"})});
  values.emplace("access", packbin::Value{access});
  return values;
}

auto nested_scheme() {
  return packbin::scheme(
      1, {packbin::dict("access",
                        packbin::list("rows", packbin::dict("fields", packbin::utf8(0))))});
}

packbin::Values nested_values() {
  auto map_rows = std::make_shared<packbin::ValueList>();
  map_rows->items.push_back(one_op("gps_fix"));
  auto store_rows = std::make_shared<packbin::ValueList>();
  store_rows->items.push_back(one_op("read"));
  store_rows->items.push_back(one_op("write"));
  auto access = std::make_shared<packbin::ValueMap>();
  access->items.emplace("map", packbin::Value{map_rows});
  access->items.emplace("store", packbin::Value{store_rows});
  packbin::Values values;
  values.emplace("access", packbin::Value{access});
  return values;
}

auto position_scheme() {
  return packbin::scheme(0x40, {
      packbin::u16(0),
      packbin::i32(1),
      packbin::i32(2),
      packbin::u8(3),
      packbin::flags(4, {packbin::u16(4), packbin::u8(5), packbin::i16(6)}),
  });
}

packbin::Values position_values() {
  packbin::Values values;
  values.emplace("0", packbin::Value{std::uint16_t{1}});
  values.emplace("1", packbin::Value{std::int32_t{500000000}});
  values.emplace("2", packbin::Value{std::int32_t{300000000}});
  values.emplace("3", packbin::Value{std::uint8_t{1}});
  return values;
}

std::vector<std::uint8_t> parse_hex(std::string const& hex) {
  std::vector<std::uint8_t> out(hex.size() / 2);
  for (std::size_t i = 0; i < out.size(); ++i)
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  return out;
}

std::vector<std::uint8_t> session_seed() {
  std::vector<std::uint8_t> seed(32);
  for (std::size_t i = 0; i < seed.size(); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  return seed;
}

std::vector<std::uint8_t> session_nonce() {
  return parse_hex("01000000000000000000000000000000");
}

bool session_fields_ok(packbin::Values const& got) {
  try {
    if (std::get<std::uint16_t>(got.at("0").data) != 1)
      return false;
    if (std::get<std::int32_t>(got.at("1").data) != 500000000)
      return false;
    if (std::get<std::int32_t>(got.at("2").data) != 300000000)
      return false;
    if (std::get<std::uint8_t>(got.at("3").data) != 1)
      return false;
  } catch (...) {
    return false;
  }
  return !packbin::present(got, 4) && !packbin::present(got, 5) && !packbin::present(got, 6);
}

bool same_strs(packbin::Value::List const& list, std::initializer_list<char const*> expect) {
  if (!list || list->items.size() != expect.size())
    return false;
  std::size_t i = 0;
  for (auto const* name : expect) {
    if (std::get<std::string>(list->items[i].data) != name)
      return false;
    ++i;
  }
  return true;
}

bool user_ok(std::string const& hex) {
  packbin::Values got;
  auto result = packbin::BinaryPacker::unpack(
      parse_hex(hex), user_scheme().on([&](packbin::Values const& row) { got = row; }));
  if (!result.ok || got.size() != 3)
    return false;
  if (std::get<std::string>(got.at("0").data) != "zxsanny")
    return false;
  auto const& roles = std::get<packbin::Value::List>(got.at("roles").data);
  auto const& access = std::get<packbin::Value::Map>(got.at("access").data);
  if (!same_strs(roles, {"user", "dispatcher"}) || !access || access->items.size() != 3)
    return false;
  return same_strs(std::get<packbin::Value::List>(access->items.at("channel").data), {"read"}) &&
         same_strs(std::get<packbin::Value::List>(access->items.at("map").data),
                   {"read", "gps_fix", "set", "edit"}) &&
         same_strs(std::get<packbin::Value::List>(access->items.at("store").data), {"read", "write"});
}

bool op_is(packbin::Value const& row, char const* op) {
  auto const& fields = std::get<packbin::Value::Map>(row.data);
  return fields && fields->items.size() == 1 &&
         std::get<std::string>(fields->items.at("op").data) == op;
}

bool nested_ok(std::string const& hex) {
  packbin::Values got;
  auto result = packbin::BinaryPacker::unpack(
      parse_hex(hex), nested_scheme().on([&](packbin::Values const& row) { got = row; }));
  if (!result.ok)
    return false;
  auto const& access = std::get<packbin::Value::Map>(got.at("access").data);
  if (!access)
    return false;
  auto const& map = std::get<packbin::Value::List>(access->items.at("map").data);
  auto const& store = std::get<packbin::Value::List>(access->items.at("store").data);
  return map && map->items.size() == 1 && op_is(map->items[0], "gps_fix") && store &&
         store->items.size() == 2 && op_is(store->items[0], "read") && op_is(store->items[1], "write");
}

bool session_ok(std::string const& hex) {
  auto waiter = packbin::PackSession::load(session_seed());
  if (!waiter || !waiter->join(session_nonce()))
    return false;
  packbin::Values got;
  auto result = waiter->unpack(
      parse_hex(hex), position_scheme().on([&](packbin::Values const& row) { got = row; }));
  return result.ok && session_fields_ok(got);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 2)
    return 2;
  std::string cmd = argv[1];
  if (cmd == "pack-user") {
    std::cout << packbin::to_hex(packbin::BinaryPacker::pack(user_scheme(), user_values())) << '\n';
    return 0;
  }
  if (cmd == "pack-nested") {
    std::cout << packbin::to_hex(packbin::BinaryPacker::pack(nested_scheme(), nested_values())) << '\n';
    return 0;
  }
  if (cmd == "pack-session") {
    auto opener = packbin::PackSession::load(session_seed());
    if (!opener || !opener->start(session_nonce()))
      return 1;
    auto payload = opener->pack(position_scheme(), position_values());
    if (!payload)
      return 1;
    std::cout << packbin::to_hex(*payload) << '\n';
    return 0;
  }
  if (argc < 3)
    return 2;
  if (cmd == "unpack-user")
    return user_ok(argv[2]) ? 0 : 1;
  if (cmd == "unpack-nested")
    return nested_ok(argv[2]) ? 0 : 1;
  if (cmd == "unpack-session")
    return session_ok(argv[2]) ? 0 : 1;
  return 2;
}
