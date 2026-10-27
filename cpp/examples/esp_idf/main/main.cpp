#include <cstdio>

#include "packbin/packbin.hpp"

// The golden position row: the same 13 bytes as every other packbin language.
struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  packbin::Opt<std::uint16_t> heading;
  packbin::Opt<std::uint8_t> speed;
  packbin::Opt<std::int16_t> altitude;
};

constexpr auto position = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::flags(4, packbin::u16<&Position::heading>(4), packbin::u8<&Position::speed>(5),
                   packbin::i16<&Position::altitude>(6)));

// The same row with 4 parity bytes after it: a receiver repairs up to 2 wrong bytes.
constexpr auto protected_position = packbin::parity(position, 4);

extern "C" void app_main(void) {
  Position row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  std::uint8_t buf[16];
  packbin::Result r = packbin::pack(position, row, buf, sizeof(buf));
  for (std::size_t i = 0; r.ok() && i < r.offset; ++i)
    std::printf("%02x", buf[i]);
  std::printf("\n");  // 4001000065cd1d00a3e1110100

  std::uint8_t sent[20];
  packbin::Result q = packbin::pack(protected_position, row, sent, sizeof(sent));
  for (std::size_t i = 0; q.ok() && i < q.offset; ++i)
    std::printf("%02x", sent[i]);
  std::printf("\n");  // 4001000065cd1d00a3e1110100ca856682

  Position back;
  packbin::Result u = packbin::unpack(position, buf, r.offset, back);
  std::printf("unpacked %d, lat %ld\n", u.ok() ? 1 : 0,
              static_cast<long>(back.lat));  // unpacked 1, lat 500000000
}
