#include "packbin/packbin.hpp"

#include <cstdio>

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

int main() {
  Position row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  std::uint8_t buf[16];
  auto r = packbin::pack(position, row, buf, sizeof(buf));
  if (!r.ok())
    return 1;
  for (std::size_t i = 0; i < r.offset; ++i)
    std::printf("%02x", buf[i]);
  std::printf("\n");
  return 0;
}
