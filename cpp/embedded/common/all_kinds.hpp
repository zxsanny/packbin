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
  packbin::Text<16> name;
  packbin::Array<std::uint16_t, 4> xs;
  packbin::Array<packbin::Entry<packbin::Text<8>, packbin::Text<8>>, 2> tags;
  packbin::Array<Pair, 4> pairs;
};

// AZ-3132: a source three `when`s deep, the stack cost of `when_matches` and `source_skipped`
// calling each other once per enclosing `when`:
// u8 m; when(m==1){ u8 k1; when(k1==1){ u8 k2; when(k2==1){ u8 k3; when(k3==1){ u8 b } } } }
struct ChainRow {
  std::uint8_t m = 0;
  packbin::Opt<std::uint8_t> k1;
  packbin::Opt<std::uint8_t> k2;
  packbin::Opt<std::uint8_t> k3;
  packbin::Opt<std::uint8_t> b;
};

// Rows of the chain scheme: 0 all true, 1 m = 0, 2 m = 1 and k1 = 0, 3 m = 1, k1 = 1 and k2 = 0.
constexpr std::size_t chain_row_count = 4;
ChainRow chain_sample(std::size_t index);
packbin::Result chain_pack(ChainRow const& row, std::uint8_t* out, std::size_t cap);
packbin::Result chain_unpack(std::uint8_t const* data, std::size_t len, ChainRow& row);
int chain_mismatched(ChainRow const& a, ChainRow const& b);
// The packet of row `index` from the Python package (2026-10-21); `len` is its length.
std::uint8_t const* chain_expected(std::size_t index, std::size_t& len);
// Differences of row `index` from the reference: packet bytes and unpacked fields (0 when equal).
int chain_failures(std::size_t index);

Row sample();
// Packs `row` into `out`; on success `offset` is the packet length. The compact text encoder
// works in a scratch that lives in this file's static memory, not on the caller's stack.
packbin::Result pack(Row const& row, std::uint8_t* out, std::size_t cap);
packbin::Result unpack(std::uint8_t const* data, std::size_t len, Row& row);
// Field-by-field differences between two rows (0 when they match).
int mismatched_fields(Row const& a, Row const& b);
// Number of entries in the scheme table.
std::size_t table_entries();

}  // namespace all_kinds
