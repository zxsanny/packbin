// The image of the Rust embedded stage (AZ-2751): decodes the golden fixture and packs and unpacks a
// 14-field route through the Rust static library, measuring the stack of each call. Built twice, like the
// C++ size probe: with the library, and with RUST_BASELINE (same startup, meter and printing, no packbin),
// so the flash of the library is the difference of the two images.
//
// Keys on the console: GOLDEN_OK, ROUTE_HEX, PACK_STACK, UNPACK_STACK, FAILURES.

#include "semihost.h"
#include "stack_meter.hpp"

#include <cstddef>
#include <cstdint>

#ifndef RUST_BASELINE
extern "C" {
int pb_rs_route_pack(std::uint8_t* out, std::size_t cap);
int pb_rs_route_unpack(std::uint8_t const* input, std::size_t len);
int pb_rs_golden(std::uint8_t const* input, std::size_t len);
}
#endif

#ifndef GOLDEN_HEX
#error "GOLDEN_HEX is the hex of fixtures/golden.hex"
#endif

namespace {

std::uint8_t packet[96];
// Declared in both images so that their static RAM is comparable (the stage requires the library to add none).
std::uint8_t golden[16];

void say(char const* key, unsigned long value) {
  sh_write(key);
  sh_write_uint(value);
  sh_write("\n");
}

#ifndef RUST_BASELINE
int nibble(char c) {
  if (c >= '0' && c <= '9')
    return c - '0';
  if (c >= 'a' && c <= 'f')
    return c - 'a' + 10;
  return -1;
}

std::size_t parse_hex(char const* hex, std::uint8_t* out, std::size_t cap) {
  std::size_t n = 0;
  while (hex[0] != '\0' && hex[1] != '\0' && n < cap) {
    out[n++] = static_cast<std::uint8_t>(nibble(hex[0]) * 16 + nibble(hex[1]));
    hex += 2;
  }
  return n;
}

void say_hex(char const* key, std::uint8_t const* data, std::size_t n) {
  static char const digits[] = "0123456789abcdef";
  char line[2 * sizeof(packet) + 1];
  if (n > sizeof(packet))
    n = sizeof(packet);
  for (std::size_t i = 0; i < n; ++i) {
    line[2 * i] = digits[data[i] >> 4];
    line[2 * i + 1] = digits[data[i] & 0xf];
  }
  line[2 * n] = '\0';
  sh_write(key);
  sh_write(line);
  sh_write("\n");
}
#endif

}  // namespace

int main() {
  int failures = 0;
#ifndef RUST_BASELINE
  std::size_t golden_len = parse_hex(GOLDEN_HEX, golden, sizeof(golden));
  int g = -1;
  int p = -1;
  int u = -1;
  std::size_t golden_stack = stack_meter::measure([&] { g = pb_rs_golden(golden, golden_len); });
  std::size_t pack_stack = stack_meter::measure([&] { p = pb_rs_route_pack(packet, sizeof(packet)); });
  std::size_t unpack_stack = stack_meter::measure(
      [&] { u = pb_rs_route_unpack(packet, p > 0 ? static_cast<std::size_t>(p) : 0); });
  failures = (golden_len == 13 ? 0 : 1) + (g == 0 ? 0 : 1) + (p > 0 ? 0 : 1) + (u == 0 ? 0 : 1);
  say("GOLDEN_OK ", g == 0 ? 1 : 0);
  say("PACKET_LEN ", p > 0 ? static_cast<unsigned long>(p) : 0);
  if (p > 0)
    say_hex("ROUTE_HEX ", packet, static_cast<std::size_t>(p));
  if (unpack_stack < golden_stack)
    unpack_stack = golden_stack;
#else
  std::size_t pack_stack = stack_meter::measure([&] { packet[0] = 1; });
  std::size_t unpack_stack = stack_meter::measure([&] {
    packet[1] = packet[0];
    golden[1] = golden[0];
  });
#endif
  say("PACK_STACK ", pack_stack);
  say("UNPACK_STACK ", unpack_stack);
  say("FAILURES ", static_cast<unsigned long>(failures));
  return failures;
}
