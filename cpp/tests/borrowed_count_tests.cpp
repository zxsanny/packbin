#include "packbin/packbin.hpp"

#include <iostream>
#include <string>
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

std::shared_ptr<packbin::ValueList> ints(std::initializer_list<int> values) {
  auto list = std::make_shared<packbin::ValueList>();
  for (auto n : values)
    list->items.push_back(packbin::Value{static_cast<std::uint8_t>(n)});
  return list;
}

std::shared_ptr<packbin::ValueList> i32s(std::initializer_list<std::int32_t> values) {
  auto list = std::make_shared<packbin::ValueList>();
  for (auto n : values)
    list->items.push_back(packbin::Value{n});
  return list;
}

packbin::Scheme<packbin::Values> route_scheme() {
  return packbin::scheme(0x34, {
      packbin::u16(0),
      packbin::u16(1),
      packbin::flags({packbin::u16(2), packbin::boolean(3), packbin::u16(4)}),
      packbin::u8(5),
      packbin::packed(2, 6, 5),
      packbin::times(5, {packbin::i32(7), packbin::i32(8)}),
      packbin::when(packbin::eq(3, packbin::Value{std::uint8_t{1}}),
                    {packbin::packed(1, 9, 5, -1)}),
  });
}

void width2_four_values() {
  auto layout = packbin::scheme(1, {packbin::u8(0), packbin::packed(2, 1, 0)});
  packbin::Values vals;
  vals.emplace("0", packbin::Value{std::uint8_t{4}});
  vals.emplace("1", packbin::Value{ints({0, 1, 2, 3})});
  auto raw = packbin::BinaryPacker::pack(layout, vals);
  expect(raw.size() == 3 && raw[2] == 0xe4, "width2 e4");
  packbin::Values got;
  auto ok = packbin::BinaryPacker::unpack(raw, layout.on([&](packbin::Values const& row) { got = row; }));
  auto const& kinds = std::get<packbin::Value::List>(got.at("1").data);
  expect(ok.ok && kinds && kinds->items.size() == 4, "width2 unpack size");
  expect(std::get<std::uint8_t>(kinds->items[0].data) == 0 &&
             std::get<std::uint8_t>(kinds->items[1].data) == 1 &&
             std::get<std::uint8_t>(kinds->items[2].data) == 2 &&
             std::get<std::uint8_t>(kinds->items[3].data) == 3,
         "width2 unpack values");
}

void width1_bias_minus_one() {
  auto layout = packbin::scheme(1, {packbin::u8(0), packbin::packed(1, 1, 0, -1)});
  packbin::Values eight_v;
  eight_v.emplace("0", packbin::Value{std::uint8_t{9}});
  eight_v.emplace("1", packbin::Value{ints({1, 1, 1, 1, 1, 1, 1, 1})});
  auto eight = packbin::BinaryPacker::pack(layout, eight_v);
  expect(eight.size() == 3 && eight[2] == 0xff, "bias -1 eight");
  packbin::Values none_v;
  none_v.emplace("0", packbin::Value{std::uint8_t{1}});
  none_v.emplace("1", packbin::Value{ints({})});
  auto none = packbin::BinaryPacker::pack(layout, none_v);
  expect(none.size() == 2, "bias -1 empty");
  packbin::Values got;
  auto ok = packbin::BinaryPacker::unpack(none, layout.on([&](packbin::Values const& row) { got = row; }));
  auto const& kinds = std::get<packbin::Value::List>(got.at("1").data);
  expect(ok.ok && kinds && kinds->items.empty(), "bias -1 unpack empty");
}

void length_mismatch_names_field() {
  auto layout = packbin::scheme(1, {packbin::u8(0), packbin::packed(2, 1, 0)});
  packbin::Values vals;
  vals.emplace("0", packbin::Value{std::uint8_t{2}});
  vals.emplace("1", packbin::Value{ints({1})});
  bool failed = false;
  std::string msg;
  try {
    packbin::BinaryPacker::pack(layout, vals);
  } catch (std::runtime_error const& ex) {
    failed = true;
    msg = ex.what();
  }
  expect(failed && msg.find("1") != std::string::npos, "length mismatch names field");
}

void times_stops_for_next_field() {
  auto layout = packbin::scheme(
      1, {packbin::u8(0), packbin::times(0, {packbin::i32(1), packbin::i32(2)}), packbin::u8(3)});
  packbin::Values vals;
  vals.emplace("0", packbin::Value{std::uint8_t{2}});
  vals.emplace("1", packbin::Value{i32s({10, 30})});
  vals.emplace("2", packbin::Value{i32s({20, 40})});
  vals.emplace("3", packbin::Value{std::uint8_t{7}});
  auto raw = packbin::BinaryPacker::pack(layout, vals);
  expect(packbin::to_hex(std::vector<std::uint8_t>(raw.begin() + 1, raw.end())) ==
             "020a000000140000001e0000002800000007",
         "times body");
  packbin::Values got;
  auto ok = packbin::BinaryPacker::unpack(raw, layout.on([&](packbin::Values const& row) { got = row; }));
  expect(ok.ok && std::get<std::uint8_t>(got.at("3").data) == 7, "times tail");
  auto const& lats = std::get<packbin::Value::List>(got.at("1").data);
  expect(lats && lats->items.size() == 2, "times pairs");
}

void route_fixture() {
  constexpr char const* route_hex =
      "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101";
  auto layout = route_scheme();
  auto raw = parse_hex(route_hex);
  packbin::Values got;
  auto ok = packbin::BinaryPacker::unpack(raw, layout.on([&](packbin::Values const& row) { got = row; }));
  expect(ok.ok, "route unpack ok");
  expect(std::get<std::uint16_t>(got.at("0").data) == 16, "route sid");
  auto const& kinds = std::get<packbin::Value::List>(got.at("6").data);
  expect(kinds && kinds->items.size() == 2 && std::get<std::uint8_t>(kinds->items[0].data) == 1 &&
             std::get<std::uint8_t>(kinds->items[1].data) == 3,
         "route kinds");
  auto const& lats = std::get<packbin::Value::List>(got.at("7").data);
  expect(lats && lats->items.size() == 2, "route lat count");
  expect(std::get<std::int32_t>(lats->items[0].data) == 500000000 &&
             std::get<std::int32_t>(lats->items[1].data) == 500010000,
         "route lats");
  auto const& mask = std::get<packbin::Value::List>(got.at("9").data);
  expect(mask && mask->items.size() == 1 && std::get<std::uint8_t>(mask->items[0].data) == 1,
         "route mask");
  auto again = packbin::BinaryPacker::pack(layout, got);
  expect(packbin::to_hex(again) == route_hex, "route repack");

  auto short_raw = std::vector<std::uint8_t>(raw.begin(), raw.begin() + 24);
  auto short_got = packbin::BinaryPacker::unpack(short_raw, layout.on([&](packbin::Values const&) {}));
  expect(!short_got.ok && short_got.value_count() == 0 && short_got.short_packet &&
             short_got.short_packet->field == "8" && short_got.short_packet->needed == 4 &&
             short_got.short_packet->left == 2,
         "route short lon");
}

}  // namespace

int run_borrowed_count_tests() {
  width2_four_values();
  width1_bias_minus_one();
  length_mismatch_names_field();
  times_stops_for_next_field();
  route_fixture();
  return failures;
}
