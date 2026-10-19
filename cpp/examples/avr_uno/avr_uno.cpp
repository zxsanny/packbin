// An Arduino Uno (ATmega328P) packs a sensor reading and reads it back with avr-gcc and avr-libc
// alone: no Arduino core, no C++ library, no heap. The kinds are integers and f32 only: avr-gcc's
// double is 4 bytes, so a scheme with f64 does not compile there. The LED on pin 13 lights when the
// row read back equals the row packed. The CI build (cpp/embedded/avr.sh, target cpp-avr-uno):
//
//   avr-g++ -std=c++17 -mmcu=atmega328p -Os -fno-exceptions -fno-rtti -DPACKBIN_NO_TEXT
//     -DPACKBIN_NO_ECC -Icpp/include cpp/src/core/*.cpp cpp/examples/avr_uno/avr_uno.cpp
//
// PACKBIN_NO_TEXT and PACKBIN_NO_ECC leave out the string and parity tables: constant tables sit in
// the Uno's 2 KB of RAM.

#include <avr/io.h>

#include <packbin/codec.hpp>

struct Reading {
  std::uint16_t station = 0;
  std::int16_t temperature = 0;  // hundredths of a degree
  std::uint8_t humidity = 0;
  float pressure = 0;  // hPa
  packbin::Opt<std::uint16_t> battery;  // millivolts, sent when set
};

constexpr auto reading = packbin::scheme<Reading>(
    0x21, packbin::u16<&Reading::station>(0), packbin::i16<&Reading::temperature>(1),
    packbin::u8<&Reading::humidity>(2), packbin::f32<&Reading::pressure>(3),
    packbin::flags(4, packbin::u16<&Reading::battery>(4)));

// avr-gcc 7.3 has no __builtin_is_constant_evaluated, so a constant scheme that breaks a rule
// is not stopped at compile time there; this assert stops it.
static_assert(reading.status.ok(), "the reading scheme is valid");

static bool same(Reading const& a, Reading const& b) {
  return a.station == b.station && a.temperature == b.temperature && a.humidity == b.humidity &&
         a.pressure == b.pressure && a.battery.has == b.battery.has &&
         a.battery.value == b.battery.value;
}

int main() {
  Reading sent;
  sent.station = 7;
  sent.temperature = -1250;
  sent.humidity = 63;
  sent.pressure = 1013.25f;
  sent.battery = 3700;

  std::uint8_t packet[16];
  packbin::Result packed = packbin::pack(reading, sent, packet, sizeof(packet));
  Reading got;
  packbin::Result read = packed.ok() ? packbin::unpack(reading, packet, packed.offset, got) : packed;

  DDRB |= _BV(DDB5);
  if (read.ok() && same(sent, got))
    PORTB |= _BV(PORTB5);
  for (;;) {
  }
}
