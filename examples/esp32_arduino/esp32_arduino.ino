// ESP32 with the Arduino core. Install packbin from the Library Manager, then build this sketch.
#include <packbin.h>

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

void setup() {
  Serial.begin(115200);
  Position row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  std::uint8_t buf[16];
  packbin::Result r = packbin::pack(position, row, buf, sizeof(buf));
  static char const hex[] = "0123456789abcdef";
  for (std::size_t i = 0; r.ok() && i < r.offset; ++i) {
    Serial.print(hex[buf[i] >> 4]);
    Serial.print(hex[buf[i] & 0xf]);
  }
  Serial.println();  // 4001000065cd1d00a3e1110100
}

void loop() {}
