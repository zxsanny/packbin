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

// AZ-3141: the same shape with a flag byte and one bit in the body of every `when`, so each level
// enters its own flag scope (the walk cannot take a held `when` in its loop):
// u8 m; when(m==1){ flag_byte; bit{ u8 d1 }; u8 k1; when(k1==1){ flag_byte; bit{ u8 d2 }; u8 k2;
// when(k2==1){ flag_byte; bit{ u8 d3 }; u8 k3; when(k3==1){ u8 b } } } }
struct FlagChainRow {
  std::uint8_t m = 0;
  packbin::Opt<std::uint8_t> d1;
  packbin::Opt<std::uint8_t> k1;
  packbin::Opt<std::uint8_t> d2;
  packbin::Opt<std::uint8_t> k2;
  packbin::Opt<std::uint8_t> d3;
  packbin::Opt<std::uint8_t> k3;
  packbin::Opt<std::uint8_t> b;
};

// Rows of the flag-byte chain: 0 all held, 1 m = 0, 2 m = 1 and k1 = 0, 3 m = 1, k1 = 1, no d2
// (bit clear) and k2 = 0.
constexpr std::size_t flag_chain_row_count = 4;
FlagChainRow flag_chain_sample(std::size_t index);
packbin::Result flag_chain_pack(FlagChainRow const& row, std::uint8_t* out, std::size_t cap);
packbin::Result flag_chain_unpack(std::uint8_t const* data, std::size_t len, FlagChainRow& row);
int flag_chain_mismatched(FlagChainRow const& a, FlagChainRow const& b);
// The packet of row `index` from the Python package (2026-10-21); `len` is its length.
std::uint8_t const* flag_chain_expected(std::size_t index, std::size_t& len);
// Differences of row `index` from the reference: packet bytes and unpacked fields (0 when equal).
int flag_chain_failures(std::size_t index);

// AZ-3144: the plain chain of AZ-3132 inside a `times` round, so the walk reaches the first `when` of
// every item through unpack_items and unpack_one, not through unpack_children:
// u8 n; times(n) { u8 m; when(m==1){ u8 k1; when(k1==1){ u8 k2; when(k2==1){ u8 k3; when(k3==1){ u8 b }}}}}
struct RoundItem {
  std::uint8_t m = 0;
  packbin::Opt<std::uint8_t> k1;
  packbin::Opt<std::uint8_t> k2;
  packbin::Opt<std::uint8_t> k3;
  packbin::Opt<std::uint8_t> b;
};

struct RoundChainRow {
  std::uint8_t n = 0;
  packbin::Array<RoundItem, 2> items;
};

// Rows of the round chain: 0 two items, all true; 1 first item m = 0, second k1 = 0; 2 one item with
// k2 = 0; 3 first item k3 = 0, second m = 0.
constexpr std::size_t round_chain_row_count = 4;
RoundChainRow round_chain_sample(std::size_t index);
packbin::Result round_chain_pack(RoundChainRow const& row, std::uint8_t* out, std::size_t cap);
packbin::Result round_chain_unpack(std::uint8_t const* data, std::size_t len, RoundChainRow& row);
int round_chain_mismatched(RoundChainRow const& a, RoundChainRow const& b);
// The packet of row `index` from the Python package (2026-10-21); `len` is its length.
std::uint8_t const* round_chain_expected(std::size_t index, std::size_t& len);
// Differences of row `index` from the reference: packet bytes and unpacked fields (0 when equal).
int round_chain_failures(std::size_t index);

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
