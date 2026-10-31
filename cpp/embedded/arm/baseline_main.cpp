// Stack meter baseline: the startup, meter and printing of the packbin images with no packbin in them. The meter reads
// its own unpainted guard as used, so a row takes the PACK_STACK of this image as the overhead to subtract.

#include "semihost.h"
#include "stack_meter.hpp"

#include <cstddef>
#include <cstdint>

namespace {

std::uint8_t packet[64];

void say(char const* key, unsigned long value) {
  sh_write(key);
  sh_write_uint(value);
  sh_write("\n");
}

}  // namespace

int main() {
  std::size_t pack_stack = stack_meter::measure([&] { packet[0] = 1; });
  std::size_t unpack_stack = stack_meter::measure([&] { packet[1] = packet[0]; });
  say("PACK_STACK ", pack_stack);
  say("UNPACK_STACK ", unpack_stack);
  say("FAILURES ", 0);
  return 0;
}
