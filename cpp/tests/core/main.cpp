#include "check.hpp"

int run_core_scalar_tests();
int run_core_scheme_tests();

int main() {
  run_core_scalar_tests();
  run_core_scheme_tests();
  if (check::failures() != 0) {
    std::fprintf(stderr, "%d core failure(s)\n", check::failures());
    return 1;
  }
  std::printf("core tests passed\n");
  return 0;
}
