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

std::string read_file(char const* path) {
  std::ifstream in(path);
  if (!in)
    return {};
  std::stringstream buf;
  buf << in.rdbuf();
  return buf.str();
}

std::string api_sources() {
  char const* roots[] = {
      "include/packbin/",
      "cpp/include/packbin/",
      "../include/packbin/",
  };
  for (auto const* root : roots) {
    auto main = read_file((std::string(root) + "packbin.hpp").c_str());
    auto scheme = read_file((std::string(root) + "scheme.hpp").c_str());
    if (!main.empty() && !scheme.empty())
      return main + "\n" + scheme;
  }
  return {};
}

struct MarkerRow {
  std::uint8_t sid = 0;
};

struct PositionRow {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
};

struct UserModifiedEvent {
  std::int32_t user_id = 0;
  std::string user_name_change;
  std::string user_email_change;
  std::uint8_t user_status_change = 0;
};

struct UserPositionEvent {
  std::int32_t user_id = 0;
  std::int32_t latitude = 0;
  std::int32_t longitude = 0;
};

auto position_scheme() {
  return packbin::Scheme<PositionRow>(
      0x40, packbin::u16(0, &PositionRow::sid), packbin::i32(1, &PositionRow::lat),
      packbin::i32(2, &PositionRow::lon), packbin::u8(3, &PositionRow::profile),
      packbin::flags({packbin::u16(4), packbin::u8(5), packbin::i16(6)}));
}

auto modified_scheme() {
  return packbin::Scheme<UserModifiedEvent>(
      1, packbin::i32(0, &UserModifiedEvent::user_id),
      packbin::utf8(1, &UserModifiedEvent::user_name_change),
      packbin::utf8(2, &UserModifiedEvent::user_email_change),
      packbin::u8(3, &UserModifiedEvent::user_status_change));
}

auto position_event_scheme() {
  return packbin::Scheme<UserPositionEvent>(
      2, packbin::i32(0, &UserPositionEvent::user_id),
      packbin::i32(1, &UserPositionEvent::latitude),
      packbin::i32(2, &UserPositionEvent::longitude));
}

void ac1_scheme_replaces_packet() {
  auto source = api_sources();
  expect(!source.empty(), "AC-1 header found");
  expect(source.find("struct Packet") == std::string::npos, "AC-1 no struct Packet");
  expect(source.find("struct BinaryPacker") != std::string::npos, "AC-1 BinaryPacker");
  expect(source.find("TypeNum") == std::string::npos, "AC-1 no TypeNum");
  expect(source.find("type_num(") == std::string::npos, "AC-1 no type_num");
  packbin::Scheme<MarkerRow> s(32, packbin::u8(0, &MarkerRow::sid));
  expect(s.type_number == 32, "AC-1 type_number");
  MarkerRow row;
  row.sid = 23;
  auto bytes = packbin::BinaryPacker::pack(s, row);
  expect(packbin::to_hex(bytes) == "2017", "AC-1 pack hex");
}

void ac2_position_golden_no_type_member() {
  PositionRow row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  auto bytes = packbin::BinaryPacker::pack(position_scheme(), row);
  expect(packbin::to_hex(bytes) == "4001000065cd1d00a3e1110100", "AC-2 golden hex");
  auto fixture = find_golden();
  expect(!fixture.empty(), "AC-2 golden.hex found");
  expect(packbin::mismatched_bytes(bytes, parse_hex(fixture)) == 0, "AC-2 fixture");
  auto source = read_file("tests/scheme_tests.cpp");
  if (source.empty())
    source = read_file("cpp/tests/scheme_tests.cpp");
  expect(!source.empty(), "AC-2 source found");
  auto start = source.find("struct PositionRow");
  expect(start != std::string::npos, "AC-2 PositionRow present");
  auto end = source.find("};", start);
  expect(end != std::string::npos, "AC-2 PositionRow body");
  auto body = source.substr(start, end - start);
  expect(body.find("type") == std::string::npos, "AC-2 no type member");
}

void ac3_known_scheme_checks_leading_byte() {
  auto layout = packbin::Scheme<MarkerRow>(1, packbin::u8(0, &MarkerRow::sid));
  auto got = packbin::BinaryPacker::unpack(layout, parse_hex("0217"));
  expect(!got.ok, "AC-3 not ok");
  expect(!got.value.has_value(), "AC-3 no row");
  expect(got.type_mismatch.has_value(), "AC-3 type_mismatch");
  if (got.type_mismatch) {
    expect(got.type_mismatch->expected.has_value() && *got.type_mismatch->expected == 1,
           "AC-3 expected 1");
    expect(got.type_mismatch->actual == 2, "AC-3 actual 2");
  }
}

void ac4_unknown_buffer_matching_handler() {
  UserPositionEvent row;
  row.user_id = 7;
  row.latitude = 8;
  row.longitude = 9;
  auto bytes = packbin::BinaryPacker::pack(position_event_scheme(), row);
  expect(packbin::to_hex(bytes) == "02070000000800000009000000", "AC-4 hex");

  int modified = 0;
  int position = 0;
  UserPositionEvent seen{};
  auto result = packbin::BinaryPacker::unpack(
      bytes, modified_scheme().on([&](UserModifiedEvent const&) { ++modified; }),
      position_event_scheme().on([&](UserPositionEvent const& ev) {
        ++position;
        seen = ev;
      }));
  expect(result.ok, "AC-4 ok");
  expect(modified == 0, "AC-4 modified not called");
  expect(position == 1, "AC-4 position called");
  expect(seen.user_id == 7, "AC-4 user_id");
  expect(seen.latitude == 8, "AC-4 latitude");
  expect(seen.longitude == 9, "AC-4 longitude");
}

void ac5_unknown_type_number() {
  int modified = 0;
  int position = 0;
  auto result = packbin::BinaryPacker::unpack(
      std::vector<std::uint8_t>{9},
      modified_scheme().on([&](UserModifiedEvent const&) { ++modified; }),
      position_event_scheme().on([&](UserPositionEvent const&) { ++position; }));
  expect(!result.ok, "AC-5 not ok");
  expect(result.type_mismatch.has_value(), "AC-5 type_mismatch");
  if (result.type_mismatch) {
    expect(!result.type_mismatch->expected.has_value(), "AC-5 no expected");
    expect(result.type_mismatch->actual == 9, "AC-5 actual 9");
  }
  expect(modified == 0 && position == 0, "AC-5 no handlers");
}

void ac6_type_numbers_unique() {
  bool threw = false;
  try {
    packbin::BinaryPacker::unpack(std::vector<std::uint8_t>{1},
                    modified_scheme().on([](UserModifiedEvent const&) {}),
                    packbin::Scheme<UserModifiedEvent>(1, packbin::i32(0, &UserModifiedEvent::user_id))
                        .on([](UserModifiedEvent const&) {}));
  } catch (std::runtime_error const&) {
    threw = true;
  }
  expect(threw, "AC-6 duplicate throws");
}

void type_number_range() {
  bool high = false;
  bool low = false;
  try {
    packbin::scheme(256, {packbin::u8(0)});
  } catch (std::runtime_error const&) {
    high = true;
  }
  try {
    packbin::scheme(-1, {packbin::u8(0)});
  } catch (std::runtime_error const&) {
    low = true;
  }
  bool typed_high = false;
  try {
    packbin::Scheme<MarkerRow>(256, packbin::u8(0, &MarkerRow::sid));
  } catch (std::runtime_error const&) {
    typed_high = true;
  }
  expect(high && low && typed_high, "type number 0..255");
}

}  // namespace

int run_scheme_tests() {
  ac1_scheme_replaces_packet();
  ac2_position_golden_no_type_member();
  ac3_known_scheme_checks_leading_byte();
  ac4_unknown_buffer_matching_handler();
  ac5_unknown_type_number();
  ac6_type_numbers_unique();
  type_number_range();
  return failures;
}
