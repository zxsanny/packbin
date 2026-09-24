#include "packbin/packbin.hpp"

#include <chrono>
#include <cstdlib>
#include <fstream>
#include <functional>
#include <iostream>
#include <sstream>
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
  for (std::size_t i = 0; i < out.size(); ++i) {
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  }
  return out;
}

std::string find_golden() {
  char const* candidates[] = {
      "../fixtures/golden.hex",
      "fixtures/golden.hex",
      "../../fixtures/golden.hex",
  };
  for (auto const* path : candidates) {
    std::ifstream in(path);
    if (in) {
      std::stringstream buf;
      buf << in.rdbuf();
      return buf.str();
    }
  }
  return {};
}

packbin::Packet position_packet() {
  return packbin::packet({
      packbin::u8("type"),
      packbin::u16("sid"),
      packbin::i32("lat"),
      packbin::i32("lon"),
      packbin::u8("profile"),
      packbin::flags("motion",
                     {packbin::u16("heading"), packbin::u8("speed"), packbin::i16("altitude")}),
  });
}

packbin::Values position_values() {
  packbin::Values v;
  v.emplace("type", packbin::Value{std::uint8_t{64}});
  v.emplace("sid", packbin::Value{std::uint16_t{1}});
  v.emplace("lat", packbin::Value{std::int32_t{500000000}});
  v.emplace("lon", packbin::Value{std::int32_t{300000000}});
  v.emplace("profile", packbin::Value{std::uint8_t{1}});
  return v;
}

constexpr char const* kGoldenHex = "4001000065cd1d00a3e1110100";

void ac1_position_pack() {
  auto bytes = packbin::pack(position_packet(), position_values());
  auto hex = packbin::to_hex(bytes);
  expect(hex == kGoldenHex, "AC-1 hex");
  expect(packbin::mismatched_bytes(bytes, parse_hex(kGoldenHex)) == 0, "AC-1 mismatched");
  expect(bytes.size() == 13, "AC-1 length 13");
  auto again = packbin::pack(position_packet(), position_values());
  expect(packbin::mismatched_bytes(bytes, again) == 0, "AC-1 packed twice");
}

void ac2_position_unpack() {
  auto got = packbin::unpack(position_packet(), parse_hex(kGoldenHex));
  expect(got.ok, "AC-2 ok");
  expect(std::get<std::uint8_t>(got.value.at("type").data) == 64, "AC-2 type");
  expect(std::get<std::uint16_t>(got.value.at("sid").data) == 1, "AC-2 sid");
  expect(std::get<std::int32_t>(got.value.at("lat").data) == 500000000, "AC-2 lat");
  expect(std::get<std::int32_t>(got.value.at("lon").data) == 300000000, "AC-2 lon");
  expect(std::get<std::uint8_t>(got.value.at("profile").data) == 1, "AC-2 profile");
  expect(packbin::motion_field_count(got.value) == 0, "AC-2 motion count 0");
  expect(!packbin::present(got.value, "heading"), "AC-2 no heading");
  expect(!packbin::present(got.value, "speed"), "AC-2 no speed");
  expect(!packbin::present(got.value, "altitude"), "AC-2 no altitude");
}

void ac3_bytes_match_fixture() {
  auto fixture_text = find_golden();
  expect(!fixture_text.empty(), "AC-3 golden.hex found");
  auto fixture = parse_hex(fixture_text);
  auto bytes = packbin::pack(position_packet(), position_values());
  expect(packbin::mismatched_bytes(bytes, fixture) == 0, "AC-3 mismatched 0");
}

void ac4_flags_and_stored_zero() {
  auto pkt = packbin::packet({
      packbin::flags("flags",
                     {packbin::u8("b0"), packbin::u8("b1"), packbin::u8("b2"), packbin::u8("b3"),
                      packbin::u8("b4"), packbin::u16("wide")}),
  });

  auto clear = packbin::pack(pkt, {});
  expect(clear.size() == 1, "AC-4 clear size 1");
  expect(clear[0] == 0x00, "AC-4 clear 0x00");

  packbin::Values set;
  set.emplace("wide", packbin::Value{std::uint16_t{0x1234}});
  auto set_bytes = packbin::pack(pkt, set);
  expect(set_bytes.size() == 3, "AC-4 0x20 size 3");
  expect(set_bytes[0] == 0x20, "AC-4 flags 0x20");
  expect(set_bytes.size() - clear.size() == 2, "AC-4 adds 2 bytes");

  packbin::Values zero;
  zero.emplace("wide", packbin::Value{std::uint16_t{0}});
  auto zero_bytes = packbin::pack(pkt, zero);
  expect(zero_bytes.size() == 3, "AC-4 present 0 size");
  expect(zero_bytes[0] == 0x20, "AC-4 present 0 bit set");
  expect(zero_bytes[1] == 0x00 && zero_bytes[2] == 0x00, "AC-4 present 0 written");

  auto absent = packbin::pack(pkt, {});
  expect(absent.size() == 1, "AC-4 absence size");
  expect(absent[0] == 0x00, "AC-4 absence no substitute");
  expect(absent.size() != zero_bytes.size(), "AC-4 absence != present 0");
}

void ac5_short_then_pack() {
  auto pkt = packbin::packet({
      packbin::flags("flags",
                     {packbin::u8("b0"), packbin::u8("b1"), packbin::u8("b2"), packbin::u8("b3"),
                      packbin::u8("b4"), packbin::u16("wide")}),
  });
  auto got = packbin::unpack(pkt, std::vector<std::uint8_t>{0x20, 0x34});
  expect(!got.ok, "AC-5 not ok");
  expect(got.value_count() == 0, "AC-5 value count 0");
  expect(got.short_packet.has_value(), "AC-5 short packet");
  if (got.short_packet) {
    expect(got.short_packet->field == "wide", "AC-5 field wide");
    expect(got.short_packet->needed == 2, "AC-5 needed 2");
    expect(got.short_packet->left == 1, "AC-5 left 1");
  }
  auto bytes = packbin::pack(position_packet(), position_values());
  expect(packbin::to_hex(bytes) == kGoldenHex, "AC-5 pack after short");
}

void when_group_width() {
  auto pkt = packbin::packet({
      packbin::u8("profile"),
      packbin::when(packbin::eq("profile", packbin::Value{std::uint8_t{0}}), {packbin::u8("shape")}),
  });
  packbin::Values miss;
  miss.emplace("profile", packbin::Value{std::uint8_t{1}});
  auto miss_bytes = packbin::pack(pkt, miss);
  expect(miss_bytes.size() == 1, "when miss adds 0");

  packbin::Values hit;
  hit.emplace("profile", packbin::Value{std::uint8_t{0}});
  hit.emplace("shape", packbin::Value{std::uint8_t{9}});
  auto hit_bytes = packbin::pack(pkt, hit);
  expect(hit_bytes.size() - miss_bytes.size() == 1, "when match adds group width");
}

void repeat_and_leftover() {
  auto pkt = packbin::packet({packbin::repeat({packbin::u8("a"), packbin::u8("b")})});
  auto ok = packbin::unpack(pkt, std::vector<std::uint8_t>{1, 2});
  expect(ok.ok, "repeat ok");
  auto it = ok.value.find("a");
  expect(it != ok.value.end(), "repeat key");
  if (it != ok.value.end()) {
    auto const* list = std::get_if<packbin::Value::List>(&it->second.data);
    expect(list && *list && (*list)->items.size() == 1, "one group");
  }
  auto bad = packbin::unpack(pkt, std::vector<std::uint8_t>{1, 2, 3});
  expect(!bad.ok, "leftover not ok");
  expect(bad.value_count() == 0, "leftover value count 0");
  expect(bad.short_packet.has_value(), "leftover short");
}

void trailing_byte() {
  auto pkt = packbin::packet({packbin::u8("type")});
  auto got = packbin::unpack(pkt, std::vector<std::uint8_t>{0x40, 0x99});
  expect(!got.ok, "trailing not ok");
  expect(got.value_count() == 0, "trailing value count 0");
  expect(got.trailing && got.trailing->left == 1, "trailing left 1");
}

void assert_no_gpu() {
  std::ifstream in("/proc/self/maps");
  if (!in)
    return;
  std::stringstream buf;
  buf << in.rdbuf();
  auto blob = buf.str();
  for (auto const* bad : {"libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"})
    expect(blob.find(bad) == std::string::npos, bad);
}

void new_field_kinds() {
  auto empty = packbin::packet({packbin::flags("f", {packbin::group("mark", {})})});
  packbin::Values mark;
  mark.emplace("mark", packbin::Value{std::uint8_t{1}});
  auto set_bit = packbin::pack(empty, mark);
  expect(set_bit.size() == 1 && set_bit[0] == 0x01, "group empty set");
  auto clear = packbin::pack(empty, {});
  expect(clear.size() == 1 && clear[0] == 0x00, "group empty clear");

  auto one = packbin::packet({packbin::flags(
      "f", {packbin::u8("a"), packbin::u8("b"), packbin::u8("c"), packbin::u8("d"),
            packbin::u8("e"), packbin::u16("b5")})});
  packbin::Values a;
  a.emplace("a", packbin::Value{std::uint8_t{1}});
  expect(packbin::pack(one, a).size() == 2, "one field bit length 2");
  packbin::Values wide;
  wide.emplace("b5", packbin::Value{std::uint16_t{1}});
  auto wide_bytes = packbin::pack(one, wide);
  expect(wide_bytes[0] == 0x20, "bit 5 is 0x20");
  expect(wide_bytes.size() - packbin::pack(one, {}).size() == 2, "bit 5 adds 2");

  auto two = packbin::packet({packbin::flags(
      "f", {packbin::group("session", {packbin::u16("login"), packbin::u32("ts")})})});
  packbin::Values session;
  session.emplace("login", packbin::Value{std::uint16_t{7}});
  session.emplace("ts", packbin::Value{std::uint32_t{1000}});
  auto raw = packbin::pack(two, session);
  expect(packbin::to_hex(std::vector<std::uint8_t>(raw.begin() + 1, raw.end())) == "0700e8030000",
         "group adds 6 bytes");
  expect(raw.size() - 1 == 6, "group width 6");
  auto absent = packbin::pack(two, {});
  expect(absent.size() == 1 && absent[0] == 0x00, "group clear adds 0");
  auto absent_got = packbin::unpack(two, absent);
  expect(absent_got.ok && !packbin::present(absent_got.value, "login") &&
             !packbin::present(absent_got.value, "ts"),
         "group clear unpacks no fields");

  auto zero = packbin::packet({packbin::flags("f", {packbin::group("g", {packbin::u8("b")})})});
  packbin::Values zero_v;
  zero_v.emplace("b", packbin::Value{std::uint8_t{0}});
  auto stored = packbin::pack(zero, zero_v);
  expect(stored.size() == 2 && stored[0] == 0x01 && stored[1] == 0x00, "present 0 stored");

  auto short_got = packbin::unpack(two, std::vector<std::uint8_t>{0x01, 0x07});
  expect(!short_got.ok && short_got.value_count() == 0, "group short no value");
  expect(short_got.short_packet && short_got.short_packet->field == "login" &&
             short_got.short_packet->needed == 2 && short_got.short_packet->left == 1,
         "group short login");

  auto sized_pkt = packbin::packet({packbin::u16("n"), packbin::sized("payload", "n")});
  packbin::Values sized_v;
  sized_v.emplace("n", packbin::Value{std::uint16_t{3}});
  sized_v.emplace("payload", packbin::Value{packbin::Value::Bytes{0x75, 0x61, 0x76}});
  expect(packbin::to_hex(packbin::pack(sized_pkt, sized_v)) == "0300756176", "sized 3");
  auto sized_got = packbin::unpack(sized_pkt, packbin::pack(sized_pkt, sized_v));
  expect(sized_got.ok && std::get<packbin::Value::Bytes>(sized_got.value.at("payload").data) ==
                             packbin::Value::Bytes{0x75, 0x61, 0x76},
         "sized unpack");
  packbin::Values empty_v;
  empty_v.emplace("n", packbin::Value{std::uint16_t{0}});
  empty_v.emplace("payload", packbin::Value{packbin::Value::Bytes{}});
  expect(packbin::to_hex(packbin::pack(sized_pkt, empty_v)) == "0000", "sized 0");
  auto empty_got = packbin::unpack(sized_pkt, packbin::pack(sized_pkt, empty_v));
  expect(empty_got.ok &&
             std::get<packbin::Value::Bytes>(empty_got.value.at("payload").data).empty(),
         "sized 0 unpack");
  auto sized_short = packbin::unpack(sized_pkt, parse_hex("030075"));
  expect(!sized_short.ok && sized_short.value_count() == 0 && sized_short.short_packet &&
             sized_short.short_packet->field == "payload" &&
             sized_short.short_packet->needed == 3 && sized_short.short_packet->left == 1,
         "sized short");

  auto kinds = packbin::packet({packbin::u2({"a", "b", "c", "d"})});
  packbin::Values kinds_v;
  kinds_v.emplace("a", packbin::Value{std::uint8_t{0}});
  kinds_v.emplace("b", packbin::Value{std::uint8_t{1}});
  kinds_v.emplace("c", packbin::Value{std::uint8_t{2}});
  kinds_v.emplace("d", packbin::Value{std::uint8_t{3}});
  auto kind_bytes = packbin::pack(kinds, kinds_v);
  expect(packbin::to_hex(kind_bytes) == "e4", "u2 e4");
  auto kind_got = packbin::unpack(kinds, kind_bytes);
  expect(kind_got.ok && std::get<std::uint8_t>(kind_got.value.at("a").data) == 0 &&
             std::get<std::uint8_t>(kind_got.value.at("b").data) == 1 &&
             std::get<std::uint8_t>(kind_got.value.at("c").data) == 2 &&
             std::get<std::uint8_t>(kind_got.value.at("d").data) == 3,
         "u2 unpack");
  packbin::Values one_v;
  one_v.emplace("a", packbin::Value{std::uint8_t{1}});
  expect(packbin::to_hex(packbin::pack(packbin::packet({packbin::u2({"a"})}), one_v)) == "01",
         "u2 one");

  auto bits_pkt = packbin::packet({packbin::u8("n"), packbin::bits("segs", "n")});
  auto eight = std::make_shared<packbin::ValueList>();
  for (int i = 0; i < 8; ++i)
    eight->items.push_back(packbin::Value{std::uint8_t{1}});
  packbin::Values eight_v;
  eight_v.emplace("n", packbin::Value{std::uint8_t{8}});
  eight_v.emplace("segs", packbin::Value{eight});
  auto eight_bytes = packbin::pack(bits_pkt, eight_v);
  expect(eight_bytes.size() == 2 && eight_bytes[1] == 0xff, "bits 8");
  auto nine = std::make_shared<packbin::ValueList>();
  for (int i = 0; i < 9; ++i)
    nine->items.push_back(packbin::Value{std::uint8_t{1}});
  packbin::Values nine_v;
  nine_v.emplace("n", packbin::Value{std::uint8_t{9}});
  nine_v.emplace("segs", packbin::Value{nine});
  auto nine_bytes = packbin::pack(bits_pkt, nine_v);
  expect(nine_bytes.size() == 3 && nine_bytes[1] == 0xff && (nine_bytes[2] & 0xfe) == 0,
         "bits 9 unused 0");
  auto bits_short = packbin::unpack(bits_pkt, std::vector<std::uint8_t>{9, 0x01});
  expect(!bits_short.ok && bits_short.value_count() == 0 && bits_short.short_packet &&
             bits_short.short_packet->field == "segs" && bits_short.short_packet->needed == 2 &&
             bits_short.short_packet->left == 1,
         "bits short");
}

void utf8_string() {
  auto pkt = packbin::packet({packbin::utf8("name")});
  packbin::Values vals;
  vals.emplace("name", packbin::Value{"zxsanny"});
  auto raw = packbin::pack(pkt, vals);
  expect(packbin::to_hex(raw) == "07007a7873616e6e79", "utf8 hex");
  expect(raw.size() == 9, "utf8 len");
  auto got = packbin::unpack(pkt, raw);
  expect(got.ok && std::get<std::string>(got.value.at("name").data) == "zxsanny", "utf8 text");

  packbin::Values empty_vals;
  empty_vals.emplace("name", packbin::Value{""});
  auto empty = packbin::pack(pkt, empty_vals);
  expect(packbin::to_hex(empty) == "0000", "utf8 empty");
  auto empty_got = packbin::unpack(pkt, empty);
  expect(empty_got.ok && std::get<std::string>(empty_got.value.at("name").data).empty(),
         "utf8 empty text");

  packbin::Values long_vals;
  long_vals.emplace("name", packbin::Value{std::string(65536, 'a')});
  bool failed = false;
  try {
    packbin::pack(pkt, long_vals);
  } catch (std::runtime_error const&) {
    failed = true;
  }
  expect(failed, "utf8 too long");

  auto short_got = packbin::unpack(pkt, parse_hex("07007a78"));
  expect(!short_got.ok && short_got.value_count() == 0 && short_got.short_packet &&
             short_got.short_packet->field == "name" && short_got.short_packet->needed == 7 &&
             short_got.short_packet->left == 2,
         "utf8 short");
}

void counted_list() {
  auto two = packbin::packet({packbin::list("xs", packbin::u16("n"))});
  auto items = std::make_shared<packbin::ValueList>();
  items->items.push_back(packbin::Value{std::uint16_t{1}});
  items->items.push_back(packbin::Value{std::uint16_t{2}});
  packbin::Values vals;
  vals.emplace("xs", packbin::Value{items});
  auto raw = packbin::pack(two, vals);
  expect(packbin::to_hex(raw) == "020001000200", "list hex");
  auto got = packbin::unpack(two, raw);
  auto const& back = std::get<packbin::Value::List>(got.value.at("xs").data);
  expect(got.ok && back && back->items.size() == 2, "list unpack");
  expect(std::get<std::uint16_t>(back->items[0].data) == 1, "list 0");
  expect(std::get<std::uint16_t>(back->items[1].data) == 2, "list 1");

  auto be_items = std::make_shared<packbin::ValueList>();
  be_items->items.push_back(packbin::Value{std::uint16_t{1}});
  auto be_one = packbin::packet({packbin::list("xs", packbin::be(packbin::u16("n")))});
  packbin::Values be_vals;
  be_vals.emplace("xs", packbin::Value{be_items});
  expect(packbin::to_hex(packbin::pack(be_one, be_vals)) == "01000001", "list be");

  auto one = std::make_shared<packbin::ValueList>();
  one->items.push_back(packbin::Value{std::uint8_t{1}});
  auto followed = packbin::packet({packbin::list("xs", packbin::u8("n")), packbin::u8("y")});
  packbin::Values both_vals;
  both_vals.emplace("xs", packbin::Value{one});
  both_vals.emplace("y", packbin::Value{std::uint8_t{2}});
  auto both = packbin::pack(followed, both_vals);
  expect(packbin::to_hex(both) == "01000102", "list next hex");
  auto back_got = packbin::unpack(followed, both);
  auto const& xs = std::get<packbin::Value::List>(back_got.value.at("xs").data);
  expect(back_got.ok && xs && xs->items.size() == 1, "list next xs");
  expect(std::get<std::uint8_t>(xs->items[0].data) == 1, "list next 1");
  expect(std::get<std::uint8_t>(back_got.value.at("y").data) == 2, "list next y");

  auto empty_items = std::make_shared<packbin::ValueList>();
  packbin::Values empty_vals;
  empty_vals.emplace("xs", packbin::Value{empty_items});
  expect(packbin::to_hex(packbin::pack(two, empty_vals)) == "0000", "list empty");

  auto huge = std::make_shared<packbin::ValueList>();
  huge->items.assign(65536, packbin::Value{std::uint16_t{1}});
  packbin::Values long_vals;
  long_vals.emplace("xs", packbin::Value{huge});
  bool failed = false;
  try {
    packbin::pack(two, long_vals);
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
      "07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265"
      "616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f726502000400"
      "7265616405007772697465";
  auto layout = packbin::packet({
      packbin::utf8("username"),
      packbin::list("roles", packbin::utf8("role")),
      packbin::dict("access", packbin::list("actions", packbin::utf8("action"))),
  });
  auto access = std::make_shared<packbin::ValueMap>();
  access->items.emplace("store", packbin::Value{strs({"read", "write"})});
  access->items.emplace("channel", packbin::Value{strs({"read"})});
  access->items.emplace("map", packbin::Value{strs({"read", "gps_fix", "set", "edit"})});
  packbin::Values values;
  values.emplace("username", packbin::Value{std::string("zxsanny")});
  values.emplace("roles", packbin::Value{strs({"user", "dispatcher"})});
  values.emplace("access", packbin::Value{access});
  auto raw = packbin::pack(layout, values);
  expect(packbin::to_hex(raw) == user_hex, "dict hex");
  expect(raw.size() == 103, "dict len");
  auto again = packbin::pack(layout, values);
  expect(packbin::mismatched_bytes(raw, again) == 0, "dict twice");
  std::vector<std::uint8_t> left;
  std::vector<std::uint8_t> right;
  std::thread t1([&] { left = packbin::pack(layout, values); });
  std::thread t2([&] { right = packbin::pack(layout, values); });
  t1.join();
  t2.join();
  expect(packbin::mismatched_bytes(left, right) == 0, "dict parallel");
  auto got = packbin::unpack(layout, raw);
  expect(got.ok && std::get<std::string>(got.value.at("username").data) == "zxsanny", "dict user");
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

  auto empty = packbin::packet(
      {packbin::utf8("s"), packbin::list("xs", packbin::u8("n")), packbin::dict("m", packbin::utf8("v"))});
  packbin::Values empty_vals;
  empty_vals.emplace("s", packbin::Value{std::string()});
  empty_vals.emplace("xs", packbin::Value{std::make_shared<packbin::ValueList>()});
  empty_vals.emplace("m", packbin::Value{std::make_shared<packbin::ValueMap>()});
  expect(packbin::to_hex(packbin::pack(empty, empty_vals)) == "000000000000", "dict empty");

  auto dup = packbin::packet({packbin::dict("access", packbin::utf8("v"))});
  auto bad = packbin::unpack(dup, parse_hex("0200010061010078010061010079"));
  expect(!bad.ok && bad.value_count() == 0 && bad.short_packet, "dict dup");

  auto huge = std::make_shared<packbin::ValueMap>();
  for (int i = 0; i < 65536; ++i)
    huge->items.emplace(std::to_string(i), packbin::Value{std::string("x")});
  packbin::Values long_vals;
  long_vals.emplace("access", packbin::Value{huge});
  bool failed = false;
  try {
    packbin::pack(dup, long_vals);
  } catch (std::runtime_error const&) {
    failed = true;
  }
  expect(failed, "dict too long");
}

void nfr_round_trips() {
  auto pkt = position_packet();
  auto vals = position_values();
  auto start = std::chrono::steady_clock::now();
  packbin::Values last;
  bool ok = true;
  for (int i = 0; i < 100000; ++i) {
    auto bytes = packbin::pack(pkt, vals);
    auto got = packbin::unpack(pkt, bytes);
    if (!got.ok) {
      ok = false;
      break;
    }
    last = std::move(got.value);
  }
  auto elapsed = std::chrono::steady_clock::now() - start;
  auto ms = std::chrono::duration<double, std::milli>(elapsed).count();
  expect(ok, "NFR unpack ok");
  expect(ok && std::get<std::int32_t>(last.at("lat").data) == 500000000, "NFR lat");
  expect(ms <= 1000.0, "NFR <= 1s");
  assert_no_gpu();
  std::cerr << "nfr elapsed_ms " << ms << "\n";
}

packbin::Packet type_num_packet() {
  return packbin::packet({packbin::type_num(32), packbin::u8("sid")});
}

void type_num_ac1_pack() {
  packbin::Values vals;
  vals.emplace("sid", packbin::Value{std::uint8_t{23}});
  auto bytes = packbin::pack(type_num_packet(), vals);
  expect(packbin::to_hex(bytes) == "2017", "type_num AC-1 hex");
  expect(packbin::mismatched_bytes(bytes, parse_hex("2017")) == 0, "type_num AC-1 mismatched");
}

void type_num_ac2_unpack() {
  auto got = packbin::unpack(type_num_packet(), parse_hex("2017"));
  expect(got.ok, "type_num AC-2 ok");
  expect(std::get<std::uint8_t>(got.value.at("sid").data) == 23, "type_num AC-2 sid");
  expect(!packbin::present(got.value, "type"), "type_num AC-2 no type");
  expect(got.value.size() == 1, "type_num AC-2 one member");
}

void type_num_ac3_wrong_byte() {
  auto got = packbin::unpack(type_num_packet(), parse_hex("2117"));
  expect(!got.ok, "type_num AC-3 not ok");
  expect(got.value_count() == 0, "type_num AC-3 value count 0");
  expect(got.type_mismatch.has_value(), "type_num AC-3 type_mismatch");
  if (got.type_mismatch) {
    expect(got.type_mismatch->expected == 32, "type_num AC-3 expected 32");
    expect(got.type_mismatch->actual == 33, "type_num AC-3 actual 33");
  }
}

void type_num_ac4_absent_golden() {
  auto fixture_text = find_golden();
  expect(!fixture_text.empty(), "type_num AC-4 golden.hex found");
  auto fixture = parse_hex(fixture_text);
  auto bytes = packbin::pack(position_packet(), position_values());
  expect(packbin::mismatched_bytes(bytes, fixture) == 0, "type_num AC-4 mismatched 0");
  auto got = packbin::unpack(position_packet(), fixture);
  expect(got.ok, "type_num AC-4 unpack ok");
}

bool throws_scheme(std::function<void()> fn) {
  try {
    fn();
    return false;
  } catch (std::runtime_error const&) {
    return true;
  }
}

void type_num_ac5_scheme_rejected() {
  expect(throws_scheme([] { packbin::packet({packbin::u8("sid"), packbin::type_num(32)}); }),
         "type_num AC-5 not first");
  expect(throws_scheme(
             [] { packbin::packet({packbin::type_num(32), packbin::type_num(33), packbin::u8("sid")}); }),
         "type_num AC-5 twice");
  expect(throws_scheme([] { packbin::packet({packbin::flags("f", {packbin::type_num(32)})}); }),
         "type_num AC-5 nested flags");
  expect(throws_scheme([] {
           packbin::packet({packbin::when(packbin::eq("x", packbin::Value{std::uint8_t{1}}),
                                         {packbin::type_num(32)})});
         }),
         "type_num AC-5 nested when");
  expect(throws_scheme([] { packbin::packet({packbin::repeat({packbin::type_num(32)})}); }),
         "type_num AC-5 nested repeat");
  expect(throws_scheme([] { packbin::packet({packbin::group("g", {packbin::type_num(32)})}); }),
         "type_num AC-5 nested group");
  expect(throws_scheme([] { packbin::packet({packbin::list("xs", packbin::type_num(32))}); }),
         "type_num AC-5 nested list");
  expect(throws_scheme([] { packbin::packet({packbin::dict("d", packbin::type_num(32))}); }),
         "type_num AC-5 nested dict");
  expect(throws_scheme([] { packbin::type_num(256); }), "type_num AC-5 above 255");
  expect(throws_scheme([] { packbin::type_num(-1); }), "type_num AC-5 below 0");
}

}  // namespace

int run_scheme_tests();

int main() {
  ac1_position_pack();
  ac2_position_unpack();
  ac3_bytes_match_fixture();
  ac4_flags_and_stored_zero();
  ac5_short_then_pack();
  when_group_width();
  repeat_and_leftover();
  trailing_byte();
  new_field_kinds();
  utf8_string();
  counted_list();
  dictionary();
  nfr_round_trips();
  type_num_ac1_pack();
  type_num_ac2_unpack();
  type_num_ac3_wrong_byte();
  type_num_ac4_absent_golden();
  type_num_ac5_scheme_rejected();
  failures += run_scheme_tests();
  if (failures != 0) {
    std::cerr << failures << " failure(s)\n";
    return 1;
  }
  std::cout << "all tests passed\n";
  return 0;
}
