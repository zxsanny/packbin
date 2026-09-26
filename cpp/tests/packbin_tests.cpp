#include "packbin/packbin.hpp"

#include <chrono>
#include <fstream>
#include <iostream>
#include <sstream>
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

auto position_scheme() {
  return packbin::scheme(0x40, {
      packbin::u16(0),
      packbin::i32(1),
      packbin::i32(2),
      packbin::u8(3),
      packbin::flags({packbin::u16(4), packbin::u8(5), packbin::i16(6)}),
  });
}

packbin::Values position_values() {
  packbin::Values v;
  v.emplace("0", packbin::Value{std::uint16_t{1}});
  v.emplace("1", packbin::Value{std::int32_t{500000000}});
  v.emplace("2", packbin::Value{std::int32_t{300000000}});
  v.emplace("3", packbin::Value{std::uint8_t{1}});
  return v;
}

constexpr char const* kGoldenHex = "4001000065cd1d00a3e1110100";

void ac1_position_pack() {
  auto bytes = packbin::BinaryPacker::pack(position_scheme(), position_values());
  auto hex = packbin::to_hex(bytes);
  expect(hex == kGoldenHex, "AC-1 hex");
  expect(packbin::mismatched_bytes(bytes, parse_hex(kGoldenHex)) == 0, "AC-1 mismatched");
  expect(bytes.size() == 13, "AC-1 length 13");
  auto again = packbin::BinaryPacker::pack(position_scheme(), position_values());
  expect(packbin::mismatched_bytes(bytes, again) == 0, "AC-1 packed twice");
}

void ac2_position_unpack() {
  packbin::Values got;
  auto result = packbin::BinaryPacker::unpack(
      parse_hex(kGoldenHex), position_scheme().on([&](packbin::Values const& row) { got = row; }));
  expect(result.ok, "AC-2 ok");
  expect(!packbin::present(got, "type"), "AC-2 no type");
  expect(std::get<std::uint16_t>(got.at("0").data) == 1, "AC-2 sid");
  expect(std::get<std::int32_t>(got.at("1").data) == 500000000, "AC-2 lat");
  expect(std::get<std::int32_t>(got.at("2").data) == 300000000, "AC-2 lon");
  expect(std::get<std::uint8_t>(got.at("3").data) == 1, "AC-2 profile");
  expect(packbin::motion_field_count(got) == 0, "AC-2 motion count 0");
  expect(!packbin::present(got, 4), "AC-2 no heading");
  expect(!packbin::present(got, 5), "AC-2 no speed");
  expect(!packbin::present(got, 6), "AC-2 no altitude");
}

void ac3_bytes_match_fixture() {
  auto fixture_text = find_golden();
  expect(!fixture_text.empty(), "AC-3 golden.hex found");
  auto fixture = parse_hex(fixture_text);
  auto bytes = packbin::BinaryPacker::pack(position_scheme(), position_values());
  expect(packbin::mismatched_bytes(bytes, fixture) == 0, "AC-3 mismatched 0");
}

void ac4_flags_and_stored_zero() {
  auto layout = packbin::scheme(1, {
      packbin::flags({packbin::u8(0), packbin::u8(1), packbin::u8(2), packbin::u8(3),
                      packbin::u8(4), packbin::u16(5)}),
  });

  auto clear = packbin::BinaryPacker::pack(layout, {});
  expect(clear.size() == 2, "AC-4 clear size 2");
  expect(clear[0] == 0x01 && clear[1] == 0x00, "AC-4 clear 0x01 0x00");

  packbin::Values set;
  set.emplace("5", packbin::Value{std::uint16_t{0x1234}});
  auto set_bytes = packbin::BinaryPacker::pack(layout, set);
  expect(set_bytes.size() == 4, "AC-4 0x20 size 4");
  expect(set_bytes[0] == 0x01 && set_bytes[1] == 0x20, "AC-4 flags 0x20");
  expect(set_bytes.size() - clear.size() == 2, "AC-4 adds 2 bytes");

  packbin::Values zero;
  zero.emplace("5", packbin::Value{std::uint16_t{0}});
  auto zero_bytes = packbin::BinaryPacker::pack(layout, zero);
  expect(zero_bytes.size() == 4, "AC-4 present 0 size");
  expect(zero_bytes[0] == 0x01 && zero_bytes[1] == 0x20, "AC-4 present 0 bit set");
  expect(zero_bytes[2] == 0x00 && zero_bytes[3] == 0x00, "AC-4 present 0 written");

  auto absent = packbin::BinaryPacker::pack(layout, {});
  expect(absent.size() == 2, "AC-4 absence size");
  expect(absent[0] == 0x01 && absent[1] == 0x00, "AC-4 absence no substitute");
  expect(absent.size() != zero_bytes.size(), "AC-4 absence != present 0");
}

void ac5_short_then_pack() {
  auto layout = packbin::scheme(1, {
      packbin::flags({packbin::u8(0), packbin::u8(1), packbin::u8(2), packbin::u8(3),
                      packbin::u8(4), packbin::u16(5)}),
  });
  bool ran = false;
  auto got = packbin::BinaryPacker::unpack(
      std::vector<std::uint8_t>{0x01, 0x20, 0x34},
      layout.on([&](packbin::Values const&) { ran = true; }));
  expect(!got.ok, "AC-5 not ok");
  expect(!ran, "AC-5 handler not run");
  expect(got.value_count() == 0, "AC-5 value count 0");
  expect(got.short_packet.has_value(), "AC-5 short packet");
  if (got.short_packet) {
    expect(got.short_packet->field == "5", "AC-5 field 5");
    expect(got.short_packet->needed == 2, "AC-5 needed 2");
    expect(got.short_packet->left == 1, "AC-5 left 1");
  }
  auto bytes = packbin::BinaryPacker::pack(position_scheme(), position_values());
  expect(packbin::to_hex(bytes) == kGoldenHex, "AC-5 pack after short");
}

void when_group_width() {
  auto layout = packbin::scheme(
      1, {packbin::u8(0),
          packbin::when(packbin::eq(0, packbin::Value{std::uint8_t{0}}), {packbin::u8(1)})});
  packbin::Values miss;
  miss.emplace("0", packbin::Value{std::uint8_t{1}});
  auto miss_bytes = packbin::BinaryPacker::pack(layout, miss);
  expect(miss_bytes.size() == 2, "when miss adds 0");

  packbin::Values hit;
  hit.emplace("0", packbin::Value{std::uint8_t{0}});
  hit.emplace("1", packbin::Value{std::uint8_t{9}});
  auto hit_bytes = packbin::BinaryPacker::pack(layout, hit);
  expect(hit_bytes.size() - miss_bytes.size() == 1, "when match adds group width");
}

void repeat_and_leftover() {
  auto layout = packbin::scheme(1, {packbin::repeat({packbin::u8(0), packbin::u8(1)})});
  packbin::Values ok_row;
  auto ok = packbin::BinaryPacker::unpack(
      std::vector<std::uint8_t>{1, 1, 2},
      layout.on([&](packbin::Values const& row) { ok_row = row; }));
  expect(ok.ok, "repeat ok");
  auto it = ok_row.find("0");
  expect(it != ok_row.end(), "repeat key");
  if (it != ok_row.end()) {
    auto const* list = std::get_if<packbin::Value::List>(&it->second.data);
    expect(list && *list && (*list)->items.size() == 1, "one group");
  }
  bool bad_ran = false;
  auto bad = packbin::BinaryPacker::unpack(
      std::vector<std::uint8_t>{1, 1, 2, 3},
      layout.on([&](packbin::Values const&) { bad_ran = true; }));
  expect(!bad.ok, "leftover not ok");
  expect(!bad_ran, "leftover handler not run");
  expect(bad.value_count() == 0, "leftover value count 0");
  expect(bad.short_packet.has_value(), "leftover short");
}

void trailing_byte() {
  bool ran = false;
  auto got = packbin::BinaryPacker::unpack(
      parse_hex(std::string(kGoldenHex) + "99"),
      position_scheme().on([&](packbin::Values const&) { ran = true; }));
  expect(!got.ok, "trailing not ok");
  expect(!ran, "trailing handler not run");
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

void nfr_round_trips() {
  auto layout = position_scheme();
  auto vals = position_values();
  auto start = std::chrono::steady_clock::now();
  packbin::Values last;
  bool ok = true;
  for (int i = 0; i < 100000; ++i) {
    auto bytes = packbin::BinaryPacker::pack(layout, vals);
    packbin::Values row;
    auto got = packbin::BinaryPacker::unpack(
        bytes, layout.on([&](packbin::Values const& v) { row = v; }));
    if (!got.ok) {
      ok = false;
      break;
    }
    last = std::move(row);
  }
  auto elapsed = std::chrono::steady_clock::now() - start;
  auto ms = std::chrono::duration<double, std::milli>(elapsed).count();
  expect(ok, "NFR unpack ok");
  expect(ok && std::get<std::int32_t>(last.at("1").data) == 500000000, "NFR lat");
  expect(ms <= 1000.0, "NFR <= 1s");
  assert_no_gpu();
  std::cerr << "nfr elapsed_ms " << ms << "\n";
}

}  // namespace

int run_kinds_tests();
int run_scheme_tests();
int run_field_id_binding_tests();
int run_borrowed_count_tests();

int main() {
  ac1_position_pack();
  ac2_position_unpack();
  ac3_bytes_match_fixture();
  ac4_flags_and_stored_zero();
  ac5_short_then_pack();
  when_group_width();
  repeat_and_leftover();
  trailing_byte();
  nfr_round_trips();
  failures += run_kinds_tests();
  failures += run_scheme_tests();
  failures += run_field_id_binding_tests();
  failures += run_borrowed_count_tests();
  if (failures != 0) {
    std::cerr << failures << " failure(s)\n";
    return 1;
  }
  std::cout << "all tests passed\n";
  return 0;
}
