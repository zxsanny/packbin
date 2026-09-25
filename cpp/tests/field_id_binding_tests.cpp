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
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t kind = 0;
  std::optional<std::uint16_t> kind_id;
  std::uint16_t title = 0;
  std::optional<bool> hidden;
  std::optional<bool> delta;
};

struct PointsRow {
  std::uint16_t sid = 0;
  std::vector<std::uint16_t> points;
};

auto marker_scheme() {
  return packbin::Scheme<MarkerRow>(
      0x20, packbin::u16(0, &MarkerRow::sid), packbin::i32(1, &MarkerRow::lat),
      packbin::i32(2, &MarkerRow::lon), packbin::u8(3, &MarkerRow::kind),
      packbin::when(packbin::eq(3, packbin::Value{std::uint8_t{1}}),
                    {packbin::u16(4, &MarkerRow::kind_id)}),
      packbin::u16(5, &MarkerRow::title),
      packbin::flags({packbin::boolean(6, &MarkerRow::hidden),
                      packbin::boolean(7, &MarkerRow::delta)}));
}

void ac1_member_names_are_not_wire_names() {
  MarkerRow row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.kind = 1;
  row.kind_id = 0;
  row.title = 0;
  auto bytes = packbin::BinaryPacker::pack(marker_scheme(), row);
  expect(packbin::to_hex(bytes) == kAc1Hex, "AC-1 hex");
  expect(bytes[0] == 0x20, "AC-1 type 0x20");
  expect(bytes.size() == 17, "AC-1 length");
  std::int32_t lat = 0;
  std::memcpy(&lat, bytes.data() + 3, 4);
  expect(lat == 500000000, "AC-1 lat bytes");
  std::optional<MarkerRow> got;
  auto back = packbin::BinaryPacker::unpack(
      bytes, marker_scheme().on([&](MarkerRow const& row) { got = row; }));
  expect(back.ok && got.has_value(), "AC-1 unpack ok");
  expect(got->lat == 500000000, "AC-1 lat");
  expect(got->sid == 1, "AC-1 sid");
  expect(got->lon == 300000000, "AC-1 lon");
  expect(got->kind == 1, "AC-1 kind");
}

void ac2_sibling_references_use_order() {
  MarkerRow with_kind;
  with_kind.sid = 1;
  with_kind.kind = 1;
  with_kind.kind_id = 9;
  auto hit = packbin::BinaryPacker::pack(marker_scheme(), with_kind);
  std::optional<MarkerRow> back_hit;
  auto hit_err = packbin::BinaryPacker::unpack(
      hit, marker_scheme().on([&](MarkerRow const& row) { back_hit = row; }));
  expect(hit_err.ok && back_hit && back_hit->kind_id == 9, "AC-2 kind_id 9");

  MarkerRow without;
  without.sid = 1;
  without.kind = 0;
  auto miss = packbin::BinaryPacker::pack(marker_scheme(), without);
  expect(hit.size() == miss.size() + 2, "AC-2 kind_id width");
  std::optional<MarkerRow> back_miss;
  auto miss_err = packbin::BinaryPacker::unpack(
      miss, marker_scheme().on([&](MarkerRow const& row) { back_miss = row; }));
  expect(miss_err.ok && back_miss && !back_miss->kind_id.has_value(), "AC-2 kind_id absent");
}

void ac3_flags_use_child_accessors() {
  MarkerRow row;
  row.sid = 1;
  row.hidden = true;
  row.delta = std::nullopt;
  auto bytes = packbin::BinaryPacker::pack(marker_scheme(), row);
  expect(bytes.back() == 0x01, "AC-3 flag byte");
  std::optional<MarkerRow> back;
  auto err = packbin::BinaryPacker::unpack(
      bytes, marker_scheme().on([&](MarkerRow const& v) { back = v; }));
  expect(err.ok && back, "AC-3 unpack");
  expect(back->hidden == true, "AC-3 hidden");
  expect(!back->delta.has_value(), "AC-3 delta null");
}

void ac4_nested_row_type_has_own_ids() {
  auto scheme = packbin::Scheme<PointsRow>(0x20, packbin::u16(0, &PointsRow::sid),
                                           packbin::list(&PointsRow::points, packbin::u16(0)));
  PointsRow row;
  row.sid = 1;
  row.points = {7, 8};
  auto bytes = packbin::BinaryPacker::pack(scheme, row);
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
    packbin::Scheme<MarkerRow>(0x20, packbin::i32(2, &MarkerRow::lat));
  } catch (std::runtime_error const&) {
    gap = true;
  }
  try {
    packbin::Scheme<MarkerRow>(0x20, packbin::u16(0, &MarkerRow::sid),
                               packbin::i32(0, &MarkerRow::lat));
  } catch (std::runtime_error const&) {
    dup = true;
  }
  try {
    packbin::Scheme<MarkerRow>(0x20, packbin::u16(0, &MarkerRow::sid),
                               packbin::i32(2, &MarkerRow::lat));
  } catch (std::runtime_error const&) {
    skip = true;
  }
  expect(gap && dup && skip, "AC-5 order fails");
}

void ac6_ac1_bytes_stable() {
  MarkerRow row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.kind = 1;
  row.kind_id = 0;
  row.title = 0;
  auto bytes = packbin::BinaryPacker::pack(marker_scheme(), row);
  expect(packbin::mismatched_bytes(bytes, parse_hex(kAc1Hex)) == 0, "AC-6 mismatched 0");
  std::optional<MarkerRow> back;
  auto err = packbin::BinaryPacker::unpack(
      bytes, marker_scheme().on([&](MarkerRow const& v) { back = v; }));
  expect(err.ok && back && back->lat == 500000000, "AC-6 lat");
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
