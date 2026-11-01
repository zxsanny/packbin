// Parity percentage on the target (AZ-3525; contract message-ecc.md 1.1.0, README "A percentage
// instead of a count"): the count and the bytes of a scheme that declares a percentage p, the
// rounding up and the cap of 32, p = 0, p = 101, and a pack, damage and repair round trip whose
// repair limit above n / 2 is lowered to n / 2. The expected bytes are rows of
// fixtures/ecc/percent-vectors.txt compiled in as text. The firmware runner builds this file:
// no files, no heap, no OS calls.
#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>

using check::expect;
using packbin::Error;

namespace {

// 40 clear bytes: the type byte 0x00 and 39 payload bytes (the "zeros" rows of the fixture).
struct Block {
  std::uint8_t raw[39] = {};
};

constexpr auto block = packbin::scheme<Block>(0x00, packbin::bytes<&Block::raw>(0));

// 13 clear bytes: the position row of the ECC fixture ("pos" rows).
struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

constexpr auto position = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::u8<&Position::flags>(4));

constexpr char const* kZeros40 =
    "00000000000000000000000000000000000000000000000000000000000000000000000000000000";
constexpr char const* kPosition13 = "4001000065cd1d00a3e1110100";

// Parity bytes after the 40 zero bytes, rows encp.zeros.p1 to p100: n = 1, 4, 10, 20 and 32.
constexpr char const* kZerosP1 = "28";
constexpr char const* kZerosP10 = "ce82b6d2";
constexpr char const* kZerosP25 = "48dd01283cf56252deb3";
constexpr char const* kZerosP50 = "3af905d24ab1d1083699affd73976c2361f9c212";
constexpr char const* kZerosP100 = "a1452120c0aa1c0ede7f0fe0972ffa489c1bb4d823a8b0f114be92b7ebedb1e8";

// Parity bytes after the 13 position bytes, rows encp.pos.p1 to p100: n = 1, 2, 4, 7 and 13.
constexpr char const* kPosP1 = "ab";
constexpr char const* kPosP10 = "16bd";
constexpr char const* kPosP25 = "ca856682";
constexpr char const* kPosP50 = "b70ae84487d2ef";
constexpr char const* kPosP100 = "c49166ec7d2c52cfbea12967e9";

// Received messages of fixp and badp rows: wrong bytes in a message with n parity bytes.
constexpr char const* kZerosP25Five =
    "0000000000000000000000000000000000000000000000000000aa00eb0000000000000000d2000048ea01143c"
    "f56252deb3";
constexpr char const* kZerosP25Six =
    "0000007c000000000000000000bc00d900000000000000000000000000000000000000000000000048dd01cb3c"
    "d5e452deb3";
constexpr char const* kZerosP100Sixteen =
    "000000a5000000000000000000007a0000001e006300000000d300000000000000fe0000000000e1a1ef2120c0"
    "aa1cbc1c7f0fd8972f94489c1bb4d823a84ef114be7cb7f1ed3de8";
constexpr char const* kZerosP100Seventeen =
    "c7000000003e0000000b2d5e00006e0000000000954d7400fb0000450000003a0000000000008a00a1452166c0"
    "aa1c0ede7f0fe0972ffa487d1bb4d893a8b0f114be92b7ebede8e8";
constexpr char const* kPosP10One = "4001000065cd8000a3e111010016bd";
constexpr char const* kPosP10Two = "4001005165cd0300a3e111010016bd";

Block patterned() {
  Block b;
  for (unsigned i = 0; i < sizeof(b.raw); ++i)
    b.raw[i] = static_cast<std::uint8_t>(i * 7u + 3u);
  return b;
}

Position position_row() {
  Position p;
  p.sid = 1;
  p.lat = 500000000;
  p.lon = 300000000;
  p.profile = 1;
  return p;
}

bool same_block(Block const& a, Block const& b) {
  return std::memcmp(a.raw, b.raw, sizeof(a.raw)) == 0;
}

bool same_position(Position const& a, Position const& b) {
  return a.sid == b.sid && a.lat == b.lat && a.lon == b.lon && a.profile == b.profile &&
         a.flags == b.flags;
}

// The packet of `row` is the clear bytes `clear` and then the parity bytes `tail`.
template <typename Row, std::size_t N>
bool packs_to(packbin::Scheme<Row, N> const& s, Row const& row, char const* clear,
              char const* tail) {
  std::uint8_t out[128];
  auto r = packbin::pack(s, row, out, sizeof(out));
  std::size_t clear_len = std::strlen(clear) / 2;
  std::size_t tail_len = std::strlen(tail) / 2;
  return r.ok() && r.offset == clear_len + tail_len && check::same_hex(out, clear_len, clear) &&
         check::same_hex(out + clear_len, tail_len, tail);
}

// 40 clear bytes: p = 1 rounds up to 1, 25 % is 10, 50 % is 20, p = 100 is capped at 32.
void forty_clear_bytes() {
  Block zeros;
  expect(packs_to(packbin::parity_percent(block, 1), zeros, kZeros40, kZerosP1),
         "p 1, 40 clear bytes: 0.4 rounds up to n 1");
  expect(packs_to(packbin::parity_percent(block, 10), zeros, kZeros40, kZerosP10),
         "p 10, 40 clear bytes: n 4");
  expect(packs_to(packbin::parity_percent(block, 25), zeros, kZeros40, kZerosP25),
         "p 25, 40 clear bytes: n 10");
  expect(packs_to(packbin::parity_percent(block, 50), zeros, kZeros40, kZerosP50),
         "p 50, 40 clear bytes: n 20");
  expect(packs_to(packbin::parity_percent(block, 100), zeros, kZeros40, kZerosP100),
         "p 100, 40 clear bytes: 40 is capped at n 32");
}

// 13 clear bytes: the counts 1, 2, 4, 7 (6.5 rounds up) and 13 (p = 100 is one per data byte).
void thirteen_clear_bytes() {
  Position row = position_row();
  expect(packs_to(packbin::parity_percent(position, 1), row, kPosition13, kPosP1),
         "p 1, 13 clear bytes: n 1");
  expect(packs_to(packbin::parity_percent(position, 10), row, kPosition13, kPosP10),
         "p 10, 13 clear bytes: 1.3 rounds up to n 2");
  expect(packs_to(packbin::parity_percent(position, 25), row, kPosition13, kPosP25),
         "p 25, 13 clear bytes: 3.25 rounds up to n 4");
  expect(packs_to(packbin::parity_percent(position, 50), row, kPosition13, kPosP50),
         "p 50, 13 clear bytes: 6.5 rounds up to n 7");
  expect(packs_to(packbin::parity_percent(position, 100), row, kPosition13, kPosP100),
         "p 100, 13 clear bytes: n 13");
}

// p = 0 is a scheme without parity: the clear bytes alone, as with n = 0.
void percent_zero() {
  Block zeros;
  auto none = packbin::parity_percent(block, 0);
  expect(none.status.ok() && none.parity == 0 && none.parity_percent == 0 &&
             packs_to(none, zeros, kZeros40, ""),
         "p 0 packs the 40 clear bytes and nothing more");
  expect(packs_to(packbin::parity_percent(position, 0), position_row(), kPosition13, ""),
         "p 0 packs the 13 position bytes and nothing more");
  auto replaced = packbin::parity_percent(packbin::parity(block, 4), 0);
  expect(replaced.parity == 0 && replaced.parity_percent == 0,
         "p 0 replaces a count: the last one set wins");
}

// p = 101 is a bad scheme, as is a count above 32; nothing is packed from it.
void percent_above_100() {
  auto bad = packbin::parity_percent(block, 101);
  expect(bad.status.error == Error::SchemeInvalid && bad.status.needed == 100 &&
             bad.parity_percent == 0 && bad.parity == 0,
         "p 101 is SchemeInvalid, naming 100");
  std::uint8_t out[64];
  std::memset(out, 0xaa, sizeof(out));
  Block zeros;
  auto r = packbin::pack(bad, zeros, out, sizeof(out));
  expect(r.error == Error::SchemeInvalid && out[0] == 0xaa, "p 101 packs 0 bytes");
}

// Pack, damage 5 bytes (n / 2 for n = 10), repair with t = 16: the limit is lowered to 5.
void round_trip_lowers_the_limit() {
  auto s = packbin::parity_percent(block, 25);
  Block row = patterned();
  std::uint8_t sent[64];
  auto p = packbin::pack(s, row, sent, sizeof(sent));
  expect(p.ok() && p.offset == 50, "p 25 round trip: the packet is 40 + 10 bytes");

  std::uint8_t got[64];
  std::memcpy(got, sent, p.offset);
  std::size_t const hit[5] = {0, 7, 20, 39, 45};
  for (std::size_t i : hit)
    got[i] = static_cast<std::uint8_t>(got[i] ^ 0xffu);
  Block back;
  auto r = packbin::unpack_repair(s, got, p.offset, back, 16);
  expect(r.ok() && r.repaired == 5 && same_block(back, row) &&
             std::memcmp(got, sent, p.offset) == 0,
         "p 25, t 16 lowered to 5: 5 wrong bytes are repaired, the buffer is the packet");
}

// Rows fixp.zeros.p25.t16.k5.0 and badp.zeros.p25.t5.k6: n = 10, so t 16 is lowered to 5.
void limit_of_ten_parity_bytes() {
  auto s = packbin::parity_percent(block, 25);
  std::uint8_t data[64];
  Block row;
  std::size_t n = check::parse_hex(kZerosP25Five, data, sizeof(data));
  auto fixed = packbin::unpack_repair(s, data, n, row, 16);
  expect(fixed.ok() && fixed.repaired == 5 && same_block(row, Block{}),
         "p 25, t 16: 5 wrong bytes of a 50-byte message are repaired");

  n = check::parse_hex(kZerosP25Six, data, sizeof(data));
  std::uint8_t before[64];
  std::memcpy(before, data, n);
  Block marked;
  marked.raw[0] = 0x7e;
  auto refused = packbin::unpack_repair(s, data, n, marked, 16);
  expect(refused.error == Error::Uncorrectable && refused.repaired == 0 &&
             std::memcmp(data, before, n) == 0 && marked.raw[0] == 0x7e,
         "p 25, t 16 lowered to 5: 6 wrong bytes are Uncorrectable, buffer and row untouched");
}

// Rows fixp.zeros.p100.t16.k16.0 and badp.zeros.p100.t16.k17: n = 32, so t 16 is n / 2 itself.
void limit_of_the_cap() {
  auto s = packbin::parity_percent(block, 100);
  std::uint8_t data[96];
  Block row;
  std::size_t n = check::parse_hex(kZerosP100Sixteen, data, sizeof(data));
  auto fixed = packbin::unpack_repair(s, data, n, row, 16);
  expect(n == 72 && fixed.ok() && fixed.repaired == 16 && same_block(row, Block{}),
         "p 100, t 16: 16 wrong bytes of a 72-byte message are repaired");

  n = check::parse_hex(kZerosP100Seventeen, data, sizeof(data));
  Block marked;
  marked.raw[0] = 0x7e;
  auto refused = packbin::unpack_repair(s, data, n, marked, 16);
  expect(refused.error == Error::Uncorrectable && marked.raw[0] == 0x7e,
         "p 100, t 16: 17 wrong bytes are Uncorrectable");
}

// Rows fixp.pos.p10.t16.k1.0 and badp.pos.p10.t1.k2: 13 + 2 bytes, n = 2, so t 16 is lowered to 1.
void limit_of_two_parity_bytes() {
  auto s = packbin::parity_percent(position, 10);
  std::uint8_t data[32];
  std::size_t n = check::parse_hex(kPosP10One, data, sizeof(data));
  Position row;
  auto fixed = packbin::unpack_repair(s, data, n, row, 16);
  expect(n == 15 && fixed.ok() && fixed.repaired == 1 && same_position(row, position_row()),
         "p 10, t 16 lowered to 1: 1 wrong byte of a 15-byte message is repaired");

  std::uint8_t two[32];
  n = check::parse_hex(kPosP10Two, two, sizeof(two));
  Position marked;
  marked.sid = 0x7e7e;
  auto refused = packbin::unpack_repair(s, two, n, marked, 16);
  expect(refused.error == Error::Uncorrectable && marked.sid == 0x7e7e,
         "p 10, t 16 lowered to 1: 2 wrong bytes are Uncorrectable");
}

// A t outside 0 to 16 is refused before any byte is read; the intact packet reads with 0 repaired.
void limit_range_and_intact_packet() {
  auto s = packbin::parity_percent(block, 25);
  std::uint8_t data[64];
  std::size_t n = check::parse_hex(kZeros40, data, sizeof(data));
  n += check::parse_hex(kZerosP25, data + n, sizeof(data) - n);
  Block row;
  row.raw[0] = 0x7e;
  auto over = packbin::unpack_repair(s, data, n, row, 17);
  auto below = packbin::unpack_repair(s, data, n, row, -1);
  expect(over.error == Error::BadValue && below.error == Error::BadValue && row.raw[0] == 0x7e,
         "t 17 and t -1 are BadValue before any byte is read");
  auto intact = packbin::unpack_repair(s, data, n, row, 16);
  expect(n == 50 && intact.ok() && intact.repaired == 0 && same_block(row, Block{}),
         "an intact 50-byte message under p 25 reads, 0 repaired");
}

template <typename Row, std::size_t N>
void print_packet(char const* name, packbin::Scheme<Row, N> const& s, Row const& row) {
  std::uint8_t out[128];
  auto r = packbin::pack(s, row, out, sizeof(out));
  std::printf("PERCENT_HEX %s ", name);
  for (std::size_t i = 0; i < r.offset; ++i)
    std::printf("%02x", out[i]);
  std::printf("\n");
}

}  // namespace

int run_core_ecc_percent_tests() {
  forty_clear_bytes();
  thirteen_clear_bytes();
  percent_zero();
  percent_above_100();
  round_trip_lowers_the_limit();
  limit_of_ten_parity_bytes();
  limit_of_the_cap();
  limit_of_two_parity_bytes();
  limit_range_and_intact_packet();
  return check::failures();
}

// The packets of the rows above, one line each, for the runner log: the stage compares the lines
// of the Cortex-M3 and the Cortex-M33F images.
void print_core_ecc_percent_packets() {
  Block zeros;
  Block mixed = patterned();
  Position row = position_row();
  print_packet("zeros.p1", packbin::parity_percent(block, 1), zeros);
  print_packet("zeros.p10", packbin::parity_percent(block, 10), zeros);
  print_packet("zeros.p25", packbin::parity_percent(block, 25), zeros);
  print_packet("zeros.p50", packbin::parity_percent(block, 50), zeros);
  print_packet("zeros.p100", packbin::parity_percent(block, 100), zeros);
  print_packet("pos.p1", packbin::parity_percent(position, 1), row);
  print_packet("pos.p10", packbin::parity_percent(position, 10), row);
  print_packet("pos.p25", packbin::parity_percent(position, 25), row);
  print_packet("pos.p50", packbin::parity_percent(position, 50), row);
  print_packet("pos.p100", packbin::parity_percent(position, 100), row);
  print_packet("mixed.p25", packbin::parity_percent(block, 25), mixed);
  print_packet("mixed.p100", packbin::parity_percent(block, 100), mixed);
}
