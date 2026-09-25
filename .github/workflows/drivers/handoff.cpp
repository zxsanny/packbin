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

std::vector<std::uint8_t> parse_hex(std::string const& hex) {
  std::vector<std::uint8_t> out(hex.size() / 2);
  for (std::size_t i = 0; i < out.size(); ++i)
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  return out;
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
  if (argc < 3)
    return 2;
  if (cmd == "unpack-user")
    return user_ok(argv[2]) ? 0 : 1;
  if (cmd == "unpack-nested")
    return nested_ok(argv[2]) ? 0 : 1;
  return 2;
}
