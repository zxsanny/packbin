// AC-2 firmware: packs and unpacks the all-kinds scheme with no stdio and no heap. Linked with
// aborting malloc/calloc/realloc/new wrappers (wrap.c); prints through semihosting only.

#include "all_kinds.hpp"
#include "semihost.h"
#include "stack_meter.hpp"

#include <cstring>

namespace {

std::uint8_t packet[256];
std::uint8_t again[256];
std::uint8_t chain_packet[16];
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

  // AZ-3132: the chain scheme's rows; the deepest figure over the chain counts in the stack budget.
  std::size_t chain_pack_stack = 0;
  std::size_t chain_unpack_stack = 0;
  int chain_failures = 0;
  for (std::size_t i = 0; i < all_kinds::chain_row_count; ++i) {
    all_kinds::ChainRow crow = all_kinds::chain_sample(i);
    all_kinds::ChainRow cback;
    packbin::Result cp{};
    packbin::Result cu{};
    std::size_t ps =
        stack_meter::measure([&] { cp = all_kinds::chain_pack(crow, chain_packet, sizeof(chain_packet)); });
    std::size_t us = stack_meter::measure(
        [&] { cu = all_kinds::chain_unpack(chain_packet, cp.offset, cback); });
    say("CHAIN_ROW_PACK_STACK ", ps);
    say("CHAIN_ROW_UNPACK_STACK ", us);
    if (ps > chain_pack_stack)
      chain_pack_stack = ps;
    if (us > chain_unpack_stack)
      chain_unpack_stack = us;
    chain_failures += (cp.ok() ? 0 : 1) + (cu.ok() ? 0 : 1) +
                      all_kinds::chain_mismatched(crow, cback) + all_kinds::chain_failures(i);
  }
  // AZ-3141: the flag-byte chain, a flag scope entered at every level.
  std::size_t fchain_pack_stack = 0;
  std::size_t fchain_unpack_stack = 0;
  int fchain_failures = 0;
  for (std::size_t i = 0; i < all_kinds::flag_chain_row_count; ++i) {
    all_kinds::FlagChainRow frow = all_kinds::flag_chain_sample(i);
    all_kinds::FlagChainRow fback;
    packbin::Result fp{};
    packbin::Result fu{};
    std::size_t ps = stack_meter::measure(
        [&] { fp = all_kinds::flag_chain_pack(frow, chain_packet, sizeof(chain_packet)); });
    std::size_t us = stack_meter::measure(
        [&] { fu = all_kinds::flag_chain_unpack(chain_packet, fp.offset, fback); });
    say("FLAG_CHAIN_ROW_PACK_STACK ", ps);
    say("FLAG_CHAIN_ROW_UNPACK_STACK ", us);
    if (ps > fchain_pack_stack)
      fchain_pack_stack = ps;
    if (us > fchain_unpack_stack)
      fchain_unpack_stack = us;
    fchain_failures += (fp.ok() ? 0 : 1) + (fu.ok() ? 0 : 1) +
                       all_kinds::flag_chain_mismatched(frow, fback) +
                       all_kinds::flag_chain_failures(i);
  }
  // AZ-3144: the plain chain inside a `times` round.
  std::size_t rchain_pack_stack = 0;
  std::size_t rchain_unpack_stack = 0;
  int rchain_failures = 0;
  for (std::size_t i = 0; i < all_kinds::round_chain_row_count; ++i) {
    all_kinds::RoundChainRow rrow = all_kinds::round_chain_sample(i);
    all_kinds::RoundChainRow rback;
    packbin::Result rp{};
    packbin::Result ru{};
    std::size_t ps = stack_meter::measure(
        [&] { rp = all_kinds::round_chain_pack(rrow, chain_packet, sizeof(chain_packet)); });
    std::size_t us = stack_meter::measure(
        [&] { ru = all_kinds::round_chain_unpack(chain_packet, rp.offset, rback); });
    say("ROUND_CHAIN_ROW_PACK_STACK ", ps);
    say("ROUND_CHAIN_ROW_UNPACK_STACK ", us);
    if (ps > rchain_pack_stack)
      rchain_pack_stack = ps;
    if (us > rchain_unpack_stack)
      rchain_unpack_stack = us;
    rchain_failures += (rp.ok() ? 0 : 1) + (ru.ok() ? 0 : 1) +
                       all_kinds::round_chain_mismatched(rrow, rback) +
                       all_kinds::round_chain_failures(i);
  }
  // The chain figures print on their own lines; PACK_STACK / UNPACK_STACK carry the larger of the
  // sample row and the chain, which is what the stage reads.
  if (chain_pack_stack > pack_stack)
    pack_stack = chain_pack_stack;
  if (chain_unpack_stack > unpack_stack)
    unpack_stack = chain_unpack_stack;
  if (fchain_pack_stack > pack_stack)
    pack_stack = fchain_pack_stack;
  if (fchain_unpack_stack > unpack_stack)
    unpack_stack = fchain_unpack_stack;
  if (rchain_pack_stack > pack_stack)
    pack_stack = rchain_pack_stack;
  if (rchain_unpack_stack > unpack_stack)
    unpack_stack = rchain_unpack_stack;
  hex(packet, p.offset);
  say("TABLE_ENTRIES ", all_kinds::table_entries());
  say("PACK_OK ", p.ok() ? 1 : 0);
  say("UNPACK_OK ", u.ok() ? 1 : 0);
  say("MISMATCHED_FIELDS ", static_cast<unsigned long>(fields));
  say("REPACK_SAME ", same ? 1 : 0);
  say("CHAIN_PACK_STACK ", chain_pack_stack);
  say("CHAIN_UNPACK_STACK ", chain_unpack_stack);
  say("CHAIN_FAILURES ", static_cast<unsigned long>(chain_failures));
  say("FLAG_CHAIN_PACK_STACK ", fchain_pack_stack);
  say("FLAG_CHAIN_UNPACK_STACK ", fchain_unpack_stack);
  say("FLAG_CHAIN_FAILURES ", static_cast<unsigned long>(fchain_failures));
  say("ROUND_CHAIN_PACK_STACK ", rchain_pack_stack);
  say("ROUND_CHAIN_UNPACK_STACK ", rchain_unpack_stack);
  say("ROUND_CHAIN_FAILURES ", static_cast<unsigned long>(rchain_failures));
  say("PACK_STACK ", pack_stack);
  say("UNPACK_STACK ", unpack_stack);
  say("WRAPPER_CALLS ", 0);
  int failures = (p.ok() ? 0 : 1) + (u.ok() ? 0 : 1) + fields + (same ? 0 : 1) + chain_failures +
                 fchain_failures + rchain_failures;
  say("FAILURES ", static_cast<unsigned long>(failures));
  return failures;
}
