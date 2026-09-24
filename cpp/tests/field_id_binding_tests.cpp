#include "packbin/packbin.hpp"

#include <cstring>
#include <iostream>
#include <optional>
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

constexpr char const* kAc1Hex = "2001000065cd1d00a3e111010000000000";

struct MarkerRow {
  std::uint16_t Sid = 0;
  std::int32_t Lat = 0;
  std::int32_t Lon = 0;
  std::uint8_t Kind = 0;
  std::optional<std::uint16_t> KindId;
  std::uint16_t Title = 0;
  std::optional<bool> Hidden;
  std::optional<bool> Delta;
};

struct PointsRow {
  std::uint16_t Sid = 0;
  std::vector<std::uint16_t> Points;
};

auto marker_scheme() {
  return packbin::Scheme<MarkerRow>(
      0x20, packbin::u16(0, &MarkerRow::Sid), packbin::i32(1, &MarkerRow::Lat),
      packbin::i32(2, &MarkerRow::Lon), packbin::u8(3, &MarkerRow::Kind),
      packbin::when(packbin::eq(3, packbin::Value{std::uint8_t{1}}),
                    {packbin::u16(4, &MarkerRow::KindId)}),
      packbin::u16(5, &MarkerRow::Title),
      packbin::flags({packbin::boolean(6, &MarkerRow::Hidden),
                      packbin::boolean(7, &MarkerRow::Delta)}));
}

void ac1_member_names_are_not_wire_names() {
  MarkerRow row;
  row.Sid = 1;
  row.Lat = 500000000;
  row.Lon = 300000000;
  row.Kind = 1;
  row.KindId = 0;
  row.Title = 0;
  auto bytes = packbin::pack(marker_scheme(), row);
  expect(packbin::to_hex(bytes) == kAc1Hex, "AC-1 hex");
  expect(bytes[0] == 0x20, "AC-1 type 0x20");
  expect(bytes.size() == 17, "AC-1 length");
  std::int32_t lat = 0;
  std::memcpy(&lat, bytes.data() + 3, 4);
  expect(lat == 500000000, "AC-1 lat bytes");
  auto back = packbin::unpack(marker_scheme(), bytes);
  expect(back.ok && back.value.has_value(), "AC-1 unpack ok");
  expect(back.value->Lat == 500000000, "AC-1 Lat");
  expect(back.value->Sid == 1, "AC-1 Sid");
  expect(back.value->Lon == 300000000, "AC-1 Lon");
  expect(back.value->Kind == 1, "AC-1 Kind");
}

void ac2_sibling_references_use_order() {
  MarkerRow with_kind;
  with_kind.Sid = 1;
  with_kind.Kind = 1;
  with_kind.KindId = 9;
  auto hit = packbin::pack(marker_scheme(), with_kind);
  auto back_hit = packbin::unpack(marker_scheme(), hit);
  expect(back_hit.ok && back_hit.value && back_hit.value->KindId == 9, "AC-2 KindId 9");

  MarkerRow without;
  without.Sid = 1;
  without.Kind = 0;
  auto miss = packbin::pack(marker_scheme(), without);
  expect(hit.size() == miss.size() + 2, "AC-2 KindId width");
  auto back_miss = packbin::unpack(marker_scheme(), miss);
  expect(back_miss.ok && back_miss.value && !back_miss.value->KindId.has_value(),
         "AC-2 KindId absent");
}

void ac3_flags_use_child_accessors() {
  MarkerRow row;
  row.Sid = 1;
  row.Hidden = true;
  row.Delta = std::nullopt;
  auto bytes = packbin::pack(marker_scheme(), row);
  expect(bytes.back() == 0x01, "AC-3 flag byte");
  auto back = packbin::unpack(marker_scheme(), bytes);
  expect(back.ok && back.value, "AC-3 unpack");
  expect(back.value->Hidden == true, "AC-3 Hidden");
  expect(!back.value->Delta.has_value(), "AC-3 Delta null");
}

void ac4_nested_row_type_has_own_ids() {
  auto scheme = packbin::Scheme<PointsRow>(0x20, packbin::u16(0, &PointsRow::Sid),
                                           packbin::list(&PointsRow::Points, packbin::u16(0)));
  PointsRow row;
  row.Sid = 1;
  row.Points = {7, 8};
  auto bytes = packbin::pack(scheme, row);
  expect(bytes[0] == 0x20, "AC-4 type");
  expect(bytes.size() == 9, "AC-4 length");
  std::uint16_t sid = 0;
  std::uint16_t count = 0;
  std::uint16_t a = 0;
  std::uint16_t b = 0;
  std::memcpy(&sid, bytes.data() + 1, 2);
  std::memcpy(&count, bytes.data() + 3, 2);
  std::memcpy(&a, bytes.data() + 5, 2);
  std::memcpy(&b, bytes.data() + 7, 2);
  expect(sid == 1 && count == 2 && a == 7 && b == 8, "AC-4 payload");
}

void ac5_order_must_match_the_number() {
  bool gap = false;
  bool dup = false;
  bool skip = false;
  try {
    packbin::Scheme<MarkerRow>(0x20, packbin::i32(2, &MarkerRow::Lat));
  } catch (std::runtime_error const&) {
    gap = true;
  }
  try {
    packbin::Scheme<MarkerRow>(0x20, packbin::u16(0, &MarkerRow::Sid),
                               packbin::i32(0, &MarkerRow::Lat));
  } catch (std::runtime_error const&) {
    dup = true;
  }
  try {
    packbin::Scheme<MarkerRow>(0x20, packbin::u16(0, &MarkerRow::Sid),
                               packbin::i32(2, &MarkerRow::Lat));
  } catch (std::runtime_error const&) {
    skip = true;
  }
  expect(gap && dup && skip, "AC-5 order fails");
}

void ac6_ac1_bytes_stable() {
  MarkerRow row;
  row.Sid = 1;
  row.Lat = 500000000;
  row.Lon = 300000000;
  row.Kind = 1;
  row.KindId = 0;
  row.Title = 0;
  auto bytes = packbin::pack(marker_scheme(), row);
  expect(packbin::mismatched_bytes(bytes, parse_hex(kAc1Hex)) == 0, "AC-6 mismatched 0");
  auto back = packbin::unpack(marker_scheme(), bytes);
  expect(back.ok && back.value && back.value->Lat == 500000000, "AC-6 Lat");
}

}  // namespace

int run_field_id_binding_tests() {
  ac1_member_names_are_not_wire_names();
  ac2_sibling_references_use_order();
  ac3_flags_use_child_accessors();
  ac4_nested_row_type_has_own_ids();
  ac5_order_must_match_the_number();
  ac6_ac1_bytes_stable();
  return failures;
}
