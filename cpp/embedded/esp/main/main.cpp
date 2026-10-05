// ESP-IDF app that packs and unpacks the all-kinds scheme with the core. CI builds it for
// esp32s3 and esp32c3 (no run); the bytes are proven on QEMU Cortex-M and s390x.

#include "all_kinds.hpp"

#include <cstdint>
#include <cstdio>

namespace {

std::uint8_t packet[256];
all_kinds::Row back;

}  // namespace

extern "C" void app_main(void) {
  all_kinds::Row row = all_kinds::sample();
  packbin::Result p = all_kinds::pack(row, packet, sizeof(packet));
  packbin::Result u = all_kinds::unpack(packet, p.offset, back);
  std::printf("packbin all kinds: %u bytes, mismatched fields %d\n",
              static_cast<unsigned>(p.offset),
              u.ok() ? all_kinds::mismatched_fields(row, back) : -1);
}
