#include "ecc_probe.hpp"

#include "packbin/codec.hpp"

#include <cstring>

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

constexpr auto position = packbin::parity(
    packbin::scheme<Position>(0x40, packbin::u16<&Position::sid>(0),
                              packbin::i32<&Position::lat>(1), packbin::i32<&Position::lon>(2),
                              packbin::u8<&Position::profile>(3), packbin::u8<&Position::flags>(4)),
    4);

// Results report row 4: 4001000065cd1d00a3e1110100 then the 4 parity bytes.
constexpr std::uint8_t kRow4[17] = {0x40, 0x01, 0x00, 0x00, 0x65, 0xcd, 0x1d, 0x00, 0xa3,
                                    0xe1, 0x11, 0x01, 0x00, 0xca, 0x85, 0x66, 0x82};

Position fixture() {
  Position p;
  p.sid = 1;
  p.lat = 500000000;
  p.lon = 300000000;
  p.profile = 1;
  return p;
}

}  // namespace

namespace ecc_probe {

std::size_t pack_position(std::uint8_t* out, std::size_t cap) {
  packbin::Result r = packbin::pack(position, fixture(), out, cap);
  return r.ok() ? r.offset : 0;
}

int failed_checks() {
  int failed = 0;
  std::uint8_t packet[17];
  if (pack_position(packet, sizeof(packet)) != sizeof(kRow4) ||
      std::memcmp(packet, kRow4, sizeof(kRow4)) != 0)
    ++failed;
  packet[2] = static_cast<std::uint8_t>(packet[2] ^ 0x5a);
  packet[9] = static_cast<std::uint8_t>(packet[9] ^ 0xc3);
  Position row;
  packbin::Result r = packbin::unpack_repair(position, packet, sizeof(packet), row, 2);
  Position want = fixture();
  if (!r.ok() || r.repaired != 2 || row.sid != want.sid || row.lat != want.lat ||
      row.lon != want.lon || row.profile != want.profile ||
      std::memcmp(packet, kRow4, sizeof(kRow4)) != 0)
    ++failed;
  return failed;
}

}  // namespace ecc_probe
