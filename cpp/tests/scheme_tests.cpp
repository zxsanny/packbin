#include "packbin/packbin.hpp"

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

std::string find_marker_row_source() {
  char const* candidates[] = {
      "tests/scheme_tests.cpp",
      "cpp/tests/scheme_tests.cpp",
      "../tests/scheme_tests.cpp",
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

struct MarkerRow {
  std::uint8_t sid = 0;
};

auto const& marker_row_scheme() {
  static auto const scheme =
      packbin::Scheme<MarkerRow>::of(packbin::type_num(32),
                                     packbin::bind(packbin::u8("sid"), &MarkerRow::sid));
  return scheme;
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

void ac1_pack_takes_the_scheme() {
  MarkerRow row;
  row.sid = 23;
  auto bytes = packbin::BinaryPacker::pack(marker_row_scheme(), row);
  expect(packbin::to_hex(bytes) == "2017", "scheme AC-1 hex");
  expect(bytes.size() == 2 && bytes[0] == 0x20 && bytes[1] == 0x17, "scheme AC-1 bytes");
}

void ac2_unpack_takes_the_same_scheme() {
  auto back = packbin::BinaryPacker::unpack(marker_row_scheme(), parse_hex("2017"));
  expect(back.ok, "scheme AC-2 ok");
  expect(back.value.has_value(), "scheme AC-2 has row");
  if (back.value)
    expect(back.value->sid == 23, "scheme AC-2 sid");
  expect(!back.type_mismatch.has_value(), "scheme AC-2 no mismatch");
}

void ac4_wrong_type_byte() {
  auto back = packbin::BinaryPacker::unpack(marker_row_scheme(), parse_hex("2117"));
  expect(!back.ok, "scheme AC-4 not ok");
  expect(!back.value.has_value(), "scheme AC-4 no row");
  expect(back.type_mismatch.has_value(), "scheme AC-4 type_mismatch");
  if (back.type_mismatch) {
    expect(back.type_mismatch->expected == 32, "scheme AC-4 expected 32");
    expect(back.type_mismatch->actual == 33, "scheme AC-4 actual 33");
  }
}

void ac5_untyped_path() {
  auto fixture_text = find_golden();
  expect(!fixture_text.empty(), "scheme AC-5 golden.hex found");
  auto fixture = parse_hex(fixture_text);
  auto bytes = packbin::pack(position_packet(), position_values());
  expect(packbin::mismatched_bytes(bytes, fixture) == 0, "scheme AC-5 mismatched 0");
}

void ac6_row_stays_data() {
  auto source = find_marker_row_source();
  expect(!source.empty(), "scheme AC-6 source found");
  auto start = source.find("struct MarkerRow");
  expect(start != std::string::npos, "scheme AC-6 MarkerRow present");
  auto end = source.find('}', start);
  expect(end != std::string::npos, "scheme AC-6 MarkerRow body");
  auto body = source.substr(start, end - start);
  expect(body.find("sid") != std::string::npos, "scheme AC-6 sid");
  expect(body.find("Scheme") == std::string::npos, "scheme AC-6 no Scheme");
  expect(body.find("pack") == std::string::npos, "scheme AC-6 no pack");
  expect(body.find("BinaryPacker") == std::string::npos, "scheme AC-6 no BinaryPacker");
}

}  // namespace

int run_scheme_tests() {
  ac1_pack_takes_the_scheme();
  ac2_unpack_takes_the_same_scheme();
  ac4_wrong_type_byte();
  ac5_untyped_path();
  ac6_row_stays_data();
  return failures;
}
