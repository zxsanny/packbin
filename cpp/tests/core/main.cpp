#include "check.hpp"

int run_core_scalar_tests();
int run_core_scheme_tests();
int run_core_grouped_tests();
int run_core_counted_tests();
int run_core_session_tests();
int run_core_session_host_tests();
int run_core_host_tests();
int run_core_hostile_host_tests();

int main() {
  run_core_scalar_tests();
  run_core_scheme_tests();
  run_core_grouped_tests();
  run_core_counted_tests();
  run_core_session_tests();
  run_core_session_host_tests();
  run_core_host_tests();
  run_core_hostile_host_tests();
  if (check::failures() != 0) {
    std::fprintf(stderr, "%d failure(s)\n", check::failures());
    return 1;
  }
  std::printf("all tests passed\n");
  return 0;
}
