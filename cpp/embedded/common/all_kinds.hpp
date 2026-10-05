#pragma once

// One scheme that uses every field kind (feature AC-2): u8…u64, i8…i64, f32, f64, bytes, bool,
// flags, flag byte bits, when, repeat, group, sized, u2, bits, packed, times, utf8, list, dict.
// Shared by the Cortex-M firmware, the ESP-IDF build and the big-endian run.

#include "packbin/codec.hpp"

#include <cstddef>
#include <cstdint>

namespace all_kinds {

struct Point {
  std::int32_t lat = 0;
  std::int32_t lon = 0;
};

struct Pair {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

struct Row {
  std::uint8_t u8v = 0;
  std::uint16_t u16v = 0;
  std::uint32_t u32v = 0;
  std::uint64_t u64v = 0;
  std::int8_t i8v = 0;
  std::int16_t i16v = 0;
  std::int32_t i32v = 0;
  std::int64_t i64v = 0;
  float f32v = 0;
  double f64v = 0;
  std::uint8_t raw[4] = {};
  packbin::Opt<std::uint16_t> leg;
  packbin::Opt<std::uint8_t> ga;
  packbin::Opt<std::uint8_t> gb;
  packbin::Opt<bool> hidden;
  packbin::Opt<std::uint16_t> heading;
  packbin::Opt<std::uint8_t> speed;
  std::uint8_t kind = 0;
  packbin::Opt<std::uint16_t> kind_id;
  std::uint16_t payload_len = 0;
  packbin::Blob<8> payload;
  std::uint8_t q0 = 0, q1 = 0, q2 = 0, q3 = 0;
  std::uint8_t nbits = 0;
  packbin::Array<std::uint8_t, 16> bits;
  std::uint8_t nkinds = 0;
  packbin::Array<std::uint8_t, 8> kinds;
  std::uint8_t npoints = 0;
  packbin::Array<Point, 4> points;
  packbin::View name;
  packbin::Array<std::uint16_t, 4> xs;
  packbin::Array<packbin::Entry<packbin::View>, 2> tags;
  packbin::Array<Pair, 4> pairs;
};

Row sample();
// Packs `row` into `out`; on success `offset` is the packet length.
packbin::Result pack(Row const& row, std::uint8_t* out, std::size_t cap);
packbin::Result unpack(std::uint8_t const* data, std::size_t len, Row& row);
// Field-by-field differences between two rows (0 when they match).
int mismatched_fields(Row const& a, Row const& b);
// Number of entries in the scheme table.
std::size_t table_entries();

}  // namespace all_kinds
