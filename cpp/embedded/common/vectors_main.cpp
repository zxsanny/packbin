// Vector runner: the host core test sources (cpp/tests/core, VECTOR_TESTS in cpp/Makefile) run
// unchanged on the target. Prints every assert site that ran per file, the all-kinds packet
// and the failure count; run.sh compares the per-file counts with the `expect(` calls asserted
// in each file. Builds for Cortex-M (newlib-nano + semihosting) and big-endian Linux.

#include "check.hpp"
#include "all_kinds.hpp"

#include <cstdio>
#include <cstring>

int run_core_scalar_tests();
int run_core_scheme_tests();
int run_core_grouped_tests();
int run_core_counted_tests();
int run_core_session_tests();

namespace {

bool big_endian() {
  std::uint16_t probe = 1;
  std::uint8_t first = 0;
  std::memcpy(&first, &probe, 1);
  return first == 0;
}

void print_files() {
  check::Site const* s = check::sites();
  for (int i = 0; i < check::site_count(); ++i) {
    bool seen = false;
    for (int j = 0; j < i; ++j)
      if (std::strcmp(s[j].file, s[i].file) == 0)
        seen = true;
    if (!seen)
      std::printf("VECTORS_RUN %s %d\n", s[i].file, check::sites_run(s[i].file));
  }
  std::printf("VECTORS_RUN_TOTAL %d\n", check::site_count());
}

int all_kinds_packet() {
  all_kinds::Row row = all_kinds::sample();
  std::uint8_t buf[256];
  std::uint8_t again[256];
  packbin::Result p = all_kinds::pack(row, buf, sizeof(buf));
  all_kinds::Row back;
  packbin::Result u = all_kinds::unpack(buf, p.offset, back);
  int fields = all_kinds::mismatched_fields(row, back);
  packbin::Result r = all_kinds::pack(back, again, sizeof(again));
  bool same = r.ok() && r.offset == p.offset && std::memcmp(buf, again, p.offset) == 0;
  std::printf("ALL_KINDS_HEX ");
  for (std::size_t i = 0; i < p.offset; ++i)
    std::printf("%02x", buf[i]);
  std::printf("\nALL_KINDS pack_ok=%d unpack_ok=%d mismatched_fields=%d repack_same=%d\n",
              p.ok() ? 1 : 0, u.ok() ? 1 : 0, fields, same ? 1 : 0);
  return (p.ok() ? 0 : 1) + (u.ok() ? 0 : 1) + fields + (same ? 0 : 1);
}

}  // namespace

int main() {
  run_core_scalar_tests();
  run_core_scheme_tests();
  run_core_grouped_tests();
  run_core_counted_tests();
  run_core_session_tests();
  print_files();
  int failures = check::failures() + all_kinds_packet();
  std::printf("ENDIAN %s\n", big_endian() ? "big" : "little");
  std::printf("FAILURES %d\n", failures);
  std::fflush(stdout);
  std::fflush(stderr);
  return failures > 255 ? 255 : failures;
}
