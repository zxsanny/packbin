// AC-2 firmware: packs and unpacks the all-kinds scheme with no stdio and no heap. Linked with
// aborting malloc/calloc/realloc/new wrappers (wrap.c); prints through semihosting only.

#include "all_kinds.hpp"
#include "semihost.h"
#include "stack_meter.hpp"

#include <cstring>

namespace {

std::uint8_t packet[256];
std::uint8_t again[256];
all_kinds::Row row;
all_kinds::Row back;

void say(char const* key, unsigned long value) {
  sh_write(key);
  sh_write_uint(value);
  sh_write("\n");
}

void hex(std::uint8_t const* p, std::size_t n) {
  static char const digits[] = "0123456789abcdef";
  char line[3] = {0, 0, 0};
  sh_write("ALL_KINDS_HEX ");
  for (std::size_t i = 0; i < n; ++i) {
    line[0] = digits[p[i] >> 4];
    line[1] = digits[p[i] & 15];
    sh_write(line);
  }
  sh_write("\n");
}

}  // namespace

int main() {
  row = all_kinds::sample();
  packbin::Result p{};
  packbin::Result u{};
  std::size_t pack_stack =
      stack_meter::measure([&] { p = all_kinds::pack(row, packet, sizeof(packet)); });
  std::size_t unpack_stack =
      stack_meter::measure([&] { u = all_kinds::unpack(packet, p.offset, back); });
  int fields = all_kinds::mismatched_fields(row, back);
  packbin::Result r = all_kinds::pack(back, again, sizeof(again));
  bool same = r.ok() && r.offset == p.offset && std::memcmp(packet, again, p.offset) == 0;

  hex(packet, p.offset);
  say("TABLE_ENTRIES ", all_kinds::table_entries());
  say("PACK_OK ", p.ok() ? 1 : 0);
  say("UNPACK_OK ", u.ok() ? 1 : 0);
  say("MISMATCHED_FIELDS ", static_cast<unsigned long>(fields));
  say("REPACK_SAME ", same ? 1 : 0);
  say("PACK_STACK ", pack_stack);
  say("UNPACK_STACK ", unpack_stack);
  say("WRAPPER_CALLS ", 0);
  int failures = (p.ok() ? 0 : 1) + (u.ok() ? 0 : 1) + fields + (same ? 0 : 1);
  say("FAILURES ", static_cast<unsigned long>(failures));
  return failures;
}
