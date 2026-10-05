#include <cstdio>

#include "esp_random.h"
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

// The board's hardware random number generator for PackSession::start.
static bool board_random(std::uint8_t* out, std::size_t n, void*) {
  esp_fill_random(out, n);
  return true;
}

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

  std::uint8_t seed[packbin::PackSession::SeedSize] = {1};
  std::uint8_t nonce[packbin::PackSession::NonceSize];
  packbin::PackSession session;
  if (session.load(seed, sizeof(seed)) && session.start(board_random, nullptr, nonce)) {
    packbin::Result s = session.pack(position, row, buf, sizeof(buf));
    std::printf("session packet %u bytes\n", static_cast<unsigned>(s.offset));
  }
}
