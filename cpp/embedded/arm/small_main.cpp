// Runner of the string-free, ECC-free build (PACKBIN_NO_TEXT and PACKBIN_NO_ECC together): the two host tests of that
// build, tests/core/no_text_tests.cpp and tests/core/no_ecc_tests.cpp, compiled unchanged with their `main` renamed,
// run on the target. Prints every assert site that ran per file and the failure count; arm.sh compares the per-file
// counts with the `expect(` calls in each file.

#include "check.hpp"

#include <cstdio>

int run_no_text_tests();
int run_no_ecc_tests();

int main() {
  run_no_text_tests();
  run_no_ecc_tests();
  check::Site const* s = check::sites();
  for (int i = 0; i < check::site_count(); ++i) {
    bool seen = false;
    for (int j = 0; j < i; ++j)
      if (std::strcmp(s[j].file, s[i].file) == 0)
        seen = true;
    if (!seen)
      std::printf("VECTORS_RUN %s %d\n", s[i].file, check::sites_run(s[i].file));
  }
  int failures = check::failures();
  std::printf("FAILURES %d\n", failures);
  std::fflush(stdout);
  std::fflush(stderr);
  return failures > 255 ? 255 : failures;
}
