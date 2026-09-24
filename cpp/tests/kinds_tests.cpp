#include "packbin/packbin.hpp"

#include <functional>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

namespace {

int failures = 0;

void expect(bool ok, char const* msg) {
  if (!ok) {
    std::cerr << "FAIL: " << msg << "\n";
    ++failures;
  }
}

std::vector<std::uint8_t> parse_hex(std::string hex) {
  while (!hex.empty() && (hex.back() == '\n' || hex.back() == '\r' || hex.back() == ' '))
    hex.pop_back();
  std::vector<std::uint8_t> out(hex.size() / 2);
  for (std::size_t i = 0; i < out.size(); ++i)
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  return out;
}

void new_field_kinds() {
  auto empty = packbin::scheme(1, {packbin::flags({packbin::group("mark", {})})});
  packbin::Values mark;
  mark.emplace("mark", packbin::Value{std::uint8_t{1}});
  auto set_bit = packbin::BinaryPacker::pack(empty, mark);
  expect(set_bit.size() == 2 && set_bit[0] == 0x01 && set_bit[1] == 0x01, "group empty set");
  auto clear = packbin::BinaryPacker::pack(empty, {});
  expect(clear.size() == 2 && clear[0] == 0x01 && clear[1] == 0x00, "group empty clear");

  auto one = packbin::scheme(
      1, {packbin::flags({packbin::u8(0), packbin::u8(1), packbin::u8(2), packbin::u8(3),
                          packbin::u8(4), packbin::u16(5)})});
  packbin::Values a;
  a.emplace("0", packbin::Value{std::uint8_t{1}});
  expect(packbin::BinaryPacker::pack(one, a).size() == 3, "one field bit length 3");
  packbin::Values wide;
  wide.emplace("5", packbin::Value{std::uint16_t{1}});
  auto wide_bytes = packbin::BinaryPacker::pack(one, wide);
  expect(wide_bytes[0] == 0x01 && wide_bytes[1] == 0x20, "bit 5 is 0x20");
  expect(wide_bytes.size() - packbin::BinaryPacker::pack(one, {}).size() == 2, "bit 5 adds 2");

  auto two = packbin::scheme(
      1, {packbin::flags({packbin::group({packbin::u16(0), packbin::u32(1)})})});
  packbin::Values session;
  session.emplace("0", packbin::Value{std::uint16_t{7}});
  session.emplace("1", packbin::Value{std::uint32_t{1000}});
  auto raw = packbin::BinaryPacker::pack(two, session);
  expect(packbin::to_hex(std::vector<std::uint8_t>(raw.begin() + 2, raw.end())) == "0700e8030000",
         "group adds 6 bytes");
  expect(raw.size() - 2 == 6, "group width 6");
  auto absent = packbin::BinaryPacker::pack(two, {});
  expect(absent.size() == 2 && absent[0] == 0x01 && absent[1] == 0x00, "group clear adds 0");
  auto absent_got = packbin::BinaryPacker::unpack(two, absent);
  expect(absent_got.ok && !packbin::present(absent_got.value, 0) &&
             !packbin::present(absent_got.value, 1),
         "group clear unpacks no fields");

  auto zero = packbin::scheme(1, {packbin::flags({packbin::group({packbin::u8(0)})})});
  packbin::Values zero_v;
  zero_v.emplace("0", packbin::Value{std::uint8_t{0}});
  auto stored = packbin::BinaryPacker::pack(zero, zero_v);
  expect(stored.size() == 3 && stored[0] == 0x01 && stored[1] == 0x01 && stored[2] == 0x00,
         "present 0 stored");

  auto short_got = packbin::BinaryPacker::unpack(two, std::vector<std::uint8_t>{0x01, 0x01, 0x07});
  expect(!short_got.ok && short_got.value_count() == 0, "group short no value");
  expect(short_got.short_packet && short_got.short_packet->field == "0" &&
             short_got.short_packet->needed == 2 && short_got.short_packet->left == 1,
         "group short login");

  auto sized_layout = packbin::scheme(1, {packbin::u16(0), packbin::sized(1, 0)});
  packbin::Values sized_v;
  sized_v.emplace("0", packbin::Value{std::uint16_t{3}});
  sized_v.emplace("1", packbin::Value{packbin::Value::Bytes{0x75, 0x61, 0x76}});
  expect(packbin::to_hex(packbin::BinaryPacker::pack(sized_layout, sized_v)) == "010300756176", "sized 3");
  auto sized_got = packbin::BinaryPacker::unpack(sized_layout, packbin::BinaryPacker::pack(sized_layout, sized_v));
  expect(sized_got.ok && std::get<packbin::Value::Bytes>(sized_got.value.at("1").data) ==
                             packbin::Value::Bytes{0x75, 0x61, 0x76},
         "sized unpack");
  packbin::Values empty_v;
  empty_v.emplace("0", packbin::Value{std::uint16_t{0}});
  empty_v.emplace("1", packbin::Value{packbin::Value::Bytes{}});
  expect(packbin::to_hex(packbin::BinaryPacker::pack(sized_layout, empty_v)) == "010000", "sized 0");
  auto empty_got = packbin::BinaryPacker::unpack(sized_layout, packbin::BinaryPacker::pack(sized_layout, empty_v));
  expect(empty_got.ok &&
             std::get<packbin::Value::Bytes>(empty_got.value.at("1").data).empty(),
         "sized 0 unpack");
  auto sized_short = packbin::BinaryPacker::unpack(sized_layout, parse_hex("01030075"));
  expect(!sized_short.ok && sized_short.value_count() == 0 && sized_short.short_packet &&
             sized_short.short_packet->field == "1" &&
             sized_short.short_packet->needed == 3 && sized_short.short_packet->left == 1,
         "sized short");

  auto kinds = packbin::scheme(1, {packbin::u2({0, 1, 2, 3})});
  packbin::Values kinds_v;
  kinds_v.emplace("0", packbin::Value{std::uint8_t{0}});
  kinds_v.emplace("1", packbin::Value{std::uint8_t{1}});
  kinds_v.emplace("2", packbin::Value{std::uint8_t{2}});
  kinds_v.emplace("3", packbin::Value{std::uint8_t{3}});
  auto kind_bytes = packbin::BinaryPacker::pack(kinds, kinds_v);
  expect(packbin::to_hex(kind_bytes) == "01e4", "u2 e4");
  auto kind_got = packbin::BinaryPacker::unpack(kinds, kind_bytes);
  expect(kind_got.ok && std::get<std::uint8_t>(kind_got.value.at("0").data) == 0 &&
             std::get<std::uint8_t>(kind_got.value.at("1").data) == 1 &&
             std::get<std::uint8_t>(kind_got.value.at("2").data) == 2 &&
             std::get<std::uint8_t>(kind_got.value.at("3").data) == 3,
         "u2 unpack");
  packbin::Values one_v;
  one_v.emplace("0", packbin::Value{std::uint8_t{1}});
  expect(packbin::to_hex(packbin::BinaryPacker::pack(packbin::scheme(1, {packbin::u2({0})}), one_v)) == "0101",
         "u2 one");

  auto bits_layout = packbin::scheme(1, {packbin::u8(0), packbin::bits(1, 0)});
  auto eight = std::make_shared<packbin::ValueList>();
  for (int i = 0; i < 8; ++i)
    eight->items.push_back(packbin::Value{std::uint8_t{1}});
  packbin::Values eight_v;
  eight_v.emplace("0", packbin::Value{std::uint8_t{8}});
  eight_v.emplace("1", packbin::Value{eight});
  auto eight_bytes = packbin::BinaryPacker::pack(bits_layout, eight_v);
  expect(eight_bytes.size() == 3 && eight_bytes[0] == 0x01 && eight_bytes[2] == 0xff, "bits 8");
  auto nine = std::make_shared<packbin::ValueList>();
  for (int i = 0; i < 9; ++i)
    nine->items.push_back(packbin::Value{std::uint8_t{1}});
  packbin::Values nine_v;
  nine_v.emplace("0", packbin::Value{std::uint8_t{9}});
  nine_v.emplace("1", packbin::Value{nine});
  auto nine_bytes = packbin::BinaryPacker::pack(bits_layout, nine_v);
  expect(nine_bytes.size() == 4 && nine_bytes[0] == 0x01 && nine_bytes[2] == 0xff &&
             (nine_bytes[3] & 0xfe) == 0,
         "bits 9 unused 0");
  auto bits_short = packbin::BinaryPacker::unpack(bits_layout, std::vector<std::uint8_t>{1, 9, 0x01});
  expect(!bits_short.ok && bits_short.value_count() == 0 && bits_short.short_packet &&
             bits_short.short_packet->field == "1" && bits_short.short_packet->needed == 2 &&
             bits_short.short_packet->left == 1,
         "bits short");
}

void utf8_string() {
  auto layout = packbin::scheme(1, {packbin::utf8(0)});
  packbin::Values vals;
  vals.emplace("0", packbin::Value{"zxsanny"});
  auto raw = packbin::BinaryPacker::pack(layout, vals);
  expect(packbin::to_hex(raw) == "0107007a7873616e6e79", "utf8 hex");
  expect(raw.size() == 10, "utf8 len");
  auto got = packbin::BinaryPacker::unpack(layout, raw);
  expect(got.ok && std::get<std::string>(got.value.at("0").data) == "zxsanny", "utf8 text");

  packbin::Values empty_vals;
  empty_vals.emplace("0", packbin::Value{""});
  auto empty = packbin::BinaryPacker::pack(layout, empty_vals);
  expect(packbin::to_hex(empty) == "010000", "utf8 empty");
  auto empty_got = packbin::BinaryPacker::unpack(layout, empty);
  expect(empty_got.ok && std::get<std::string>(empty_got.value.at("0").data).empty(),
         "utf8 empty text");

  packbin::Values long_vals;
  long_vals.emplace("0", packbin::Value{std::string(65536, 'a')});
  bool failed = false;
  try {
    packbin::BinaryPacker::pack(layout, long_vals);
  } catch (std::runtime_error const&) {
    failed = true;
  }
  expect(failed, "utf8 too long");

  auto short_got = packbin::BinaryPacker::unpack(layout, parse_hex("0107007a78"));
  expect(!short_got.ok && short_got.value_count() == 0 && short_got.short_packet &&
             short_got.short_packet->field == "0" && short_got.short_packet->needed == 7 &&
             short_got.short_packet->left == 2,
         "utf8 short");
}

void counted_list() {
  auto two = packbin::scheme(1, {packbin::list("xs", packbin::u16(0))});
  auto items = std::make_shared<packbin::ValueList>();
  items->items.push_back(packbin::Value{std::uint16_t{1}});
  items->items.push_back(packbin::Value{std::uint16_t{2}});
  packbin::Values vals;
  vals.emplace("xs", packbin::Value{items});
  auto raw = packbin::BinaryPacker::pack(two, vals);
  expect(packbin::to_hex(raw) == "01020001000200", "list hex");
  auto got = packbin::BinaryPacker::unpack(two, raw);
  auto const& back = std::get<packbin::Value::List>(got.value.at("xs").data);
  expect(got.ok && back && back->items.size() == 2, "list unpack");
  expect(std::get<std::uint16_t>(back->items[0].data) == 1, "list 0");
  expect(std::get<std::uint16_t>(back->items[1].data) == 2, "list 1");

  auto be_items = std::make_shared<packbin::ValueList>();
  be_items->items.push_back(packbin::Value{std::uint16_t{1}});
  auto be_one = packbin::scheme(1, {packbin::list("xs", packbin::be(packbin::u16(0)))});
  packbin::Values be_vals;
  be_vals.emplace("xs", packbin::Value{be_items});
  expect(packbin::to_hex(packbin::BinaryPacker::pack(be_one, be_vals)) == "0101000001", "list be");

  auto one = std::make_shared<packbin::ValueList>();
  one->items.push_back(packbin::Value{std::uint8_t{1}});
  auto followed = packbin::scheme(1, {packbin::list("xs", packbin::u8(0)), packbin::u8(0)});
  packbin::Values both_vals;
  both_vals.emplace("xs", packbin::Value{one});
  both_vals.emplace("0", packbin::Value{std::uint8_t{2}});
  auto both = packbin::BinaryPacker::pack(followed, both_vals);
  expect(packbin::to_hex(both) == "0101000102", "list next hex");
  auto back_got = packbin::BinaryPacker::unpack(followed, both);
  auto const& xs = std::get<packbin::Value::List>(back_got.value.at("xs").data);
  expect(back_got.ok && xs && xs->items.size() == 1, "list next xs");
  expect(std::get<std::uint8_t>(xs->items[0].data) == 1, "list next 1");
  expect(std::get<std::uint8_t>(back_got.value.at("0").data) == 2, "list next y");

  auto empty_items = std::make_shared<packbin::ValueList>();
  packbin::Values empty_vals;
  empty_vals.emplace("xs", packbin::Value{empty_items});
  expect(packbin::to_hex(packbin::BinaryPacker::pack(two, empty_vals)) == "010000", "list empty");

  auto huge = std::make_shared<packbin::ValueList>();
  huge->items.assign(65536, packbin::Value{std::uint16_t{1}});
  packbin::Values long_vals;
  long_vals.emplace("xs", packbin::Value{huge});
  bool failed = false;
  try {
    packbin::BinaryPacker::pack(two, long_vals);
  } catch (std::runtime_error const&) {
    failed = true;
  }
  expect(failed, "list too long");
}

std::shared_ptr<packbin::ValueList> strs(std::initializer_list<char const*> names) {
  auto list = std::make_shared<packbin::ValueList>();
  for (auto const* name : names)
    list->items.push_back(packbin::Value{std::string(name)});
  return list;
}

void dictionary() {
  auto const user_hex =
      "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265"
      "616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f726502000400"
      "7265616405007772697465";
  auto layout = packbin::scheme(1, {
      packbin::utf8(0),
      packbin::list("roles", packbin::utf8(0)),
      packbin::dict("access", packbin::list("actions", packbin::utf8(0))),
  });
  auto access = std::make_shared<packbin::ValueMap>();
  access->items.emplace("store", packbin::Value{strs({"read", "write"})});
  access->items.emplace("channel", packbin::Value{strs({"read"})});
  access->items.emplace("map", packbin::Value{strs({"read", "gps_fix", "set", "edit"})});
  packbin::Values values;
  values.emplace("0", packbin::Value{std::string("zxsanny")});
  values.emplace("roles", packbin::Value{strs({"user", "dispatcher"})});
  values.emplace("access", packbin::Value{access});
  auto raw = packbin::BinaryPacker::pack(layout, values);
  expect(packbin::to_hex(raw) == user_hex, "dict hex");
  expect(raw.size() == 104, "dict len");
  auto again = packbin::BinaryPacker::pack(layout, values);
  expect(packbin::mismatched_bytes(raw, again) == 0, "dict twice");
  std::vector<std::uint8_t> left;
  std::vector<std::uint8_t> right;
  std::thread t1([&] { left = packbin::BinaryPacker::pack(layout, values); });
  std::thread t2([&] { right = packbin::BinaryPacker::pack(layout, values); });
  t1.join();
  t2.join();
  expect(packbin::mismatched_bytes(left, right) == 0, "dict parallel");
  auto got = packbin::BinaryPacker::unpack(layout, raw);
  expect(got.ok && std::get<std::string>(got.value.at("0").data) == "zxsanny", "dict user");
  auto const& roles = std::get<packbin::Value::List>(got.value.at("roles").data);
  expect(roles && roles->items.size() == 2, "dict roles");
  expect(std::get<std::string>(roles->items[0].data) == "user", "dict role 0");
  expect(std::get<std::string>(roles->items[1].data) == "dispatcher", "dict role 1");
  auto const& back = std::get<packbin::Value::Map>(got.value.at("access").data);
  expect(back && back->items.size() == 3, "dict access");
  auto const& channel = std::get<packbin::Value::List>(back->items.at("channel").data);
  expect(channel && channel->items.size() == 1 &&
             std::get<std::string>(channel->items[0].data) == "read",
         "dict channel");
  auto const& map = std::get<packbin::Value::List>(back->items.at("map").data);
  expect(map && map->items.size() == 4 && std::get<std::string>(map->items[1].data) == "gps_fix",
         "dict map");
  auto const& store = std::get<packbin::Value::List>(back->items.at("store").data);
  expect(store && store->items.size() == 2 && std::get<std::string>(store->items[1].data) == "write",
         "dict store");

  auto empty = packbin::scheme(
      1, {packbin::utf8(0), packbin::list("xs", packbin::u8(0)), packbin::dict("m", packbin::utf8(0))});
  packbin::Values empty_vals;
  empty_vals.emplace("0", packbin::Value{std::string()});
  empty_vals.emplace("xs", packbin::Value{std::make_shared<packbin::ValueList>()});
  empty_vals.emplace("m", packbin::Value{std::make_shared<packbin::ValueMap>()});
  expect(packbin::to_hex(packbin::BinaryPacker::pack(empty, empty_vals)) == "01000000000000", "dict empty");

  auto dup = packbin::scheme(1, {packbin::dict("access", packbin::utf8(0))});
  auto bad = packbin::BinaryPacker::unpack(dup, parse_hex("010200010061010078010061010079"));
  expect(!bad.ok && bad.value_count() == 0 && bad.short_packet, "dict dup");

  auto huge = std::make_shared<packbin::ValueMap>();
  for (int i = 0; i < 65536; ++i)
    huge->items.emplace(std::to_string(i), packbin::Value{std::string("x")});
  packbin::Values long_vals;
  long_vals.emplace("access", packbin::Value{huge});
  bool failed = false;
  try {
    packbin::BinaryPacker::pack(dup, long_vals);
  } catch (std::runtime_error const&) {
    failed = true;
  }
  expect(failed, "dict too long");
}

}  // namespace

int run_kinds_tests() {
  new_field_kinds();
  utf8_string();
  counted_list();
  dictionary();
  return failures;
}
