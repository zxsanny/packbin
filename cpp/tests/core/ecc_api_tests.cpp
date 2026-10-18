// Message ECC in the pack and unpack API (AZ-2688; EC-1 to EC-4, EC-8, EC-17): the parity setting
// on the scheme, the bytes of the position fixture for every parity count, the size limit, the
// scheme limit, in-place repair, the detect-only unpack and the refusal results. The firmware
// runner builds this file: no heap, no OS calls.
#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstring>

using check::expect;
using packbin::Error;

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

constexpr auto plain = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::u8<&Position::flags>(4));

constexpr auto p1 = packbin::parity(plain, 1);
constexpr auto p2 = packbin::parity(plain, 2);
constexpr auto p4 = packbin::parity(plain, 4);
constexpr auto p8 = packbin::parity(plain, 8);
constexpr auto p16 = packbin::parity(plain, 16);
constexpr auto p32 = packbin::parity(plain, 32);

// Results report rows 1 to 6: the fixture and the same fixture with 1, 2, 4, 8 and 16 parity bytes.
constexpr char const* kRow1 = "4001000065cd1d00a3e1110100";
constexpr char const* kRow2 = "4001000065cd1d00a3e1110100ab";
constexpr char const* kRow3 = "4001000065cd1d00a3e111010016bd";
constexpr char const* kRow4 = "4001000065cd1d00a3e1110100ca856682";
constexpr char const* kRow5 = "4001000065cd1d00a3e11101006d4f38479f3f2472";
constexpr char const* kRow6 = "4001000065cd1d00a3e11101004ace66ecd5e4a28ffa28098279f5f19d";
// Row 8: bytes 2 and 9 of row 4 are wrong.
constexpr char const* kRow8 = "40015a0065cd1d00a322110100ca856682";

Position position_row() {
  Position p;
  p.sid = 1;
  p.lat = 500000000;
  p.lon = 300000000;
  p.profile = 1;
  return p;
}

bool same_row(Position const& a, Position const& b) {
  return a.sid == b.sid && a.lat == b.lat && a.lon == b.lon && a.profile == b.profile &&
         a.flags == b.flags;
}

template <std::size_t N>
bool packs_to(packbin::Scheme<Position, N> const& s, char const* hex) {
  std::uint8_t out[64];
  auto r = packbin::pack(s, position_row(), out, sizeof(out));
  return r.ok() && check::same_hex(out, r.offset, hex);
}

// EC-1, EC-2: the bytes of rows 1 to 6; the unprotected scheme is the scheme as before.
void bytes_of_every_parity_count() {
  expect(plain.parity == 0 && packs_to(plain, kRow1), "EC-1 n = 0 packs the 13-byte fixture");
  expect(packs_to(packbin::parity(plain, 0), kRow1), "EC-1 parity(scheme, 0) is the same scheme");
  expect(packs_to(p1, kRow2), "EC-2 n = 1 equals report row 2");
  expect(packs_to(p2, kRow3), "EC-2 n = 2 equals report row 3");
  expect(packs_to(p4, kRow4), "EC-2 n = 4 equals report row 4");
  expect(packs_to(p8, kRow5), "EC-2 n = 8 equals report row 5");
  expect(packs_to(p16, kRow6), "EC-2 n = 16 equals report row 6");

  std::uint8_t out[64];
  auto r = packbin::pack(p32, position_row(), out, sizeof(out));
  expect(r.ok() && r.offset == 13 + 32, "EC-2 n = 32 packs the clear length + 32 bytes");
  expect(check::same_hex(out, 13, kRow1), "EC-2 the first bytes are the clear message");
}

// A buffer too small for the parity is BufferFull naming the parity bytes; the fields are not
// cut short.
void pack_into_a_small_buffer() {
  std::uint8_t out[16];
  auto r = packbin::pack(p4, position_row(), out, 16);
  expect(r.error == Error::BufferFull && r.offset == 13 && r.needed == 4 && r.field == -1,
         "pack with room for the fields but not the parity is BufferFull");
  auto fits = packbin::pack(p4, position_row(), out, 17);
  expect(fits.ok() && fits.offset == 17, "pack with room for exactly the message");
}

// EC-8: an intact buffer returns the row and 0 repaired; the offset is the whole message.
void intact_message() {
  std::uint8_t data[32];
  std::size_t n = check::parse_hex(kRow4, data, sizeof(data));
  Position row;
  auto r = packbin::unpack(p4, data, n, row);
  expect(r.ok() && r.repaired == 0 && r.offset == n && same_row(row, position_row()),
         "EC-8 an intact n = 4 message reads, 0 repaired");
  std::uint8_t copy[32];
  std::memcpy(copy, data, n);
  Position again;
  auto u = packbin::unpack_repair(p4, copy, n, again, 2);
  expect(u.ok() && u.repaired == 0 && same_row(again, position_row()) &&
             std::memcmp(copy, data, n) == 0,
         "EC-8 unpack_repair of an intact message repairs 0 and leaves the buffer");
}

// EC-5 at the API (rows 7, 8): bytes repaired in place, and the buffer equals the protected
// message after a successful unpack (EC-17).
void repair_in_place() {
  std::uint8_t want[32];
  std::size_t n = check::parse_hex(kRow4, want, sizeof(want));
  std::uint8_t data[32];
  check::parse_hex(kRow8, data, sizeof(data));
  Position row;
  auto r = packbin::unpack_repair(p4, data, n, row, 2);
  expect(r.ok() && r.repaired == 2 && r.offset == n && same_row(row, position_row()),
         "EC-5 row 8 is repaired to the position row, 2 bytes");
  expect(std::memcmp(data, want, n) == 0, "EC-17 the buffer equals the protected message");

  std::uint8_t one[32];
  std::size_t m = check::parse_hex("4001000065cc1d00a3e111010016bd", one, sizeof(one));
  Position single;
  auto s = packbin::unpack_repair(p2, one, m, single, 1);
  expect(s.ok() && s.repaired == 1 && same_row(single, position_row()), "EC-5 row 7: one byte");
  expect(check::same_hex(one, m, kRow3), "EC-17 row 7 buffer equals row 3");

  // All 8 bits of a parity byte flip.
  std::uint8_t parity_flip[32];
  check::parse_hex(kRow4, parity_flip, sizeof(parity_flip));
  parity_flip[n - 1] = static_cast<std::uint8_t>(~parity_flip[n - 1]);
  Position back;
  auto pf = packbin::unpack_repair(p4, parity_flip, n, back, 2);
  expect(pf.ok() && pf.repaired == 1 && check::same_hex(parity_flip, n, kRow4),
         "EC-5 a parity byte with all 8 bits flipped is repaired");
}

// EC-6 (rows 9, 10): beyond the limit is Uncorrectable, no values, the buffer untouched; the
// read-only unpack detects and does not write.
void refusals_leave_the_buffer() {
  std::uint8_t data[32];
  std::size_t n = check::parse_hex(kRow8, data, sizeof(data));
  std::uint8_t before[32];
  std::memcpy(before, data, n);

  Position row;
  auto one = packbin::unpack_repair(p4, data, n, row, 1);
  expect(one.error == Error::Uncorrectable && one.field == -1 && one.repaired == 0 &&
             std::memcmp(data, before, n) == 0 && row.sid == 0,
         "EC-6 row 9: limit 1 refuses 2 wrong bytes, nothing written");
  auto zero = packbin::unpack_repair(p4, data, n, row, 0);
  expect(zero.error == Error::Uncorrectable && std::memcmp(data, before, n) == 0 && row.sid == 0,
         "EC-6 row 10: limit 0 refuses 2 wrong bytes");
  std::uint8_t const* view = data;
  auto detect = packbin::unpack(p4, view, n, row);
  expect(detect.error == Error::Uncorrectable && std::memcmp(data, before, n) == 0 && row.sid == 0,
         "EC-17 the read-only unpack of a protected scheme detects and never writes");
}

// EC-8: a limit above n / 2 is an error before any byte is read; shorter than n bytes is a short
// packet naming the parity bytes needed and the bytes present (row 12).
void limit_and_short_buffer() {
  std::uint8_t data[32];
  std::size_t n = check::parse_hex(kRow4, data, sizeof(data));
  Position row;
  auto over = packbin::unpack_repair(p4, data, n, row, 3);
  expect(over.error == Error::BadValue && over.needed == 2 && row.sid == 0,
         "EC-8 a limit above n / 2 is BadValue before any byte is read");
  auto negative = packbin::unpack_repair(p4, data, n, row, -1);
  expect(negative.error == Error::BadValue, "EC-8 a negative limit is BadValue");
  auto plain_limit = packbin::unpack_repair(plain, data, 13, row, 1);
  expect(plain_limit.error == Error::BadValue, "EC-8 a scheme without parity takes limit 0 only");

  std::uint8_t three[3] = {0x40, 0x01, 0x00};
  auto s = packbin::unpack_repair(p4, three, 3, row, 2);
  expect(s.error == Error::ShortPacket && s.offset == 3 && s.needed == 4 && s.field == -1,
         "EC-8 row 12: 3 bytes under n = 4 is ShortPacket, 4 needed, 3 present");
  auto empty = packbin::unpack(p4, three, 0, row);
  expect(empty.error == Error::ShortPacket && empty.needed == 4, "EC-8 an empty buffer is short");
}

// EC-14: a shifted or resized message is refused; n = 0 keeps its own errors.
void shifted_messages() {
  std::uint8_t data[40];
  std::size_t n = check::parse_hex(kRow4, data, sizeof(data));
  Position row;
  std::uint8_t added[40];
  std::memcpy(added, data, n);
  added[n] = 0;
  auto grown = packbin::unpack_repair(p4, added, n + 1, row, 0);
  expect(!grown.ok() && row.sid == 0, "EC-14 a trailing zero byte is refused");
  auto cut = packbin::unpack_repair(p4, data, n - 1, row, 0);
  expect(!cut.ok() && row.sid == 0, "EC-14 the last byte removed is refused");

  std::uint8_t clear[16];
  std::size_t c = check::parse_hex(kRow1, clear, sizeof(clear));
  auto unprotected = packbin::unpack_repair(p4, clear, c, row, 0);
  expect(!unprotected.ok() && row.sid == 0, "EC-14 the 13-byte message under n = 4 is refused");
  auto trailing = packbin::unpack(plain, data, n, row);
  expect(trailing.error == Error::TrailingBytes && trailing.offset == 13,
         "EC-14 a protected message under n = 0 is TrailingBytes");
}

template <std::size_t K>
struct Fixed {
  std::uint8_t raw[K] = {};
};

template <std::size_t K>
constexpr auto fixed(int n) {
  return packbin::parity(packbin::scheme<Fixed<K>>(0x41, packbin::bytes<&Fixed<K>::raw>(0)), n);
}

// EC-4: the clear message is at most 254 - n bytes; the refusal writes nothing.
template <std::size_t K>
bool packs_ok(int n) {
  auto s = fixed<K>(n);
  static Fixed<K> row;
  static std::uint8_t out[256];
  std::memset(out, 0xaa, sizeof(out));
  auto r = packbin::pack(s, row, out, sizeof(out));
  return r.ok() && r.offset == K + 1 + static_cast<std::size_t>(n);
}

template <std::size_t K>
bool refused_too_long(int n, std::size_t limit) {
  auto s = fixed<K>(n);
  static Fixed<K> row;
  static std::uint8_t out[256];
  std::memset(out, 0xaa, sizeof(out));
  auto r = packbin::pack(s, row, out, sizeof(out));
  for (std::size_t i = 0; i < K + 1; ++i)
    if (out[i] != 0)
      return false;
  return r.error == Error::TooLong && r.offset == K + 1 && r.needed == limit && out[K + 1] == 0xaa;
}

void size_limit() {
  expect(packs_ok<249>(4), "EC-4 n = 4: a 250-byte clear message packs");
  expect(refused_too_long<250>(4, 250), "EC-4 n = 4: a 251-byte clear message is TooLong, 250");
  expect(packs_ok<221>(32), "EC-4 n = 32: a 222-byte clear message packs");
  expect(refused_too_long<222>(32, 222), "EC-4 n = 32: a 223-byte clear message is TooLong, 222");
  expect(packs_ok<253>(0), "EC-1 n = 0 packs the 254-byte clear message as before");

  // A 254-byte buffer under a protected scheme packs; one byte more is TooLong on unpack.
  constexpr auto s = fixed<249>(4);
  static Fixed<249> row;
  static std::uint8_t out[300];
  auto r = packbin::pack(s, row, out, sizeof(out));
  Fixed<249> back;
  expect(r.ok() && r.offset == 254 && packbin::unpack(s, out, 254, back).ok(),
         "EC-4 a 254-byte message reads back");
  out[254] = 0;
  auto longer = packbin::unpack_repair(s, out, 255, back, 2);
  expect(longer.error == Error::TooLong && longer.offset == 255 && longer.needed == 254 &&
             back.raw[0] == 0,
         "EC-4 a buffer above 254 bytes under a protected scheme is TooLong, 0 values");
}

// EC-3: n above 32 or below 0 is SchemeInvalid at construction; no message is built from it.
void scheme_limit() {
  auto over = packbin::parity(plain, 33);
  expect(over.status.error == Error::SchemeInvalid && over.status.needed == 32 &&
             packbin::validate(over).error == Error::SchemeInvalid && over.parity == 0,
         "EC-3 n = 33 is SchemeInvalid");
  std::uint8_t out[64];
  std::memset(out, 0xaa, sizeof(out));
  auto r = packbin::pack(over, position_row(), out, sizeof(out));
  expect(r.error == Error::SchemeInvalid && out[0] == 0xaa,
         "EC-3 pack of an invalid scheme writes 0 bytes");
  auto negative = packbin::parity(plain, -1);
  expect(negative.status.error == Error::SchemeInvalid, "EC-3 n = -1 is SchemeInvalid");
  expect(packbin::validate(p32).ok(), "EC-3 n = 32 is valid");

  auto already = packbin::parity(over, 4);
  expect(already.status.error == Error::SchemeInvalid, "EC-3 an invalid scheme stays invalid");
}

}  // namespace

int run_core_ecc_api_tests() {
  bytes_of_every_parity_count();
  pack_into_a_small_buffer();
  intact_message();
  repair_in_place();
  refusals_leave_the_buffer();
  limit_and_short_buffer();
  shifted_messages();
  size_limit();
  scheme_limit();
  return check::failures();
}
