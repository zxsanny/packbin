#include "check.hpp"

int run_core_scalar_tests();
int run_core_scheme_tests();
int run_core_grouped_tests();
int run_core_counted_tests();
int run_core_session_tests();
int run_core_session_host_tests();
int run_core_host_tests();
int run_core_hostile_host_tests();
int run_core_flag_scope_host_tests();
int run_core_source_kinds_host_tests();
int run_core_flags_when_member_host_tests();
int run_core_flags_times_repeat_member_host_tests();
int run_core_split_form_loud_host_tests();
int run_core_times_count_zero_host_tests();
int run_core_eq_value_checked_host_tests();
int run_core_late_source_host_tests();
int run_core_held_count_nested_late_host_tests();
int run_core_empty_body_rule_host_tests();
int run_core_packed_bias_novalue_host_tests();
int run_core_novalue_nested_host_tests();
int run_core_builder_id_range_host_tests();
int run_core_loop25_probe_d1_d7_host_tests();
int run_core_text_vectors_host_tests();
int run_core_text_codec_host_tests();
int run_core_text_api_host_tests();

int main() {
  run_core_scalar_tests();
  run_core_scheme_tests();
  run_core_grouped_tests();
  run_core_counted_tests();
  run_core_session_tests();
  run_core_session_host_tests();
  run_core_host_tests();
  run_core_hostile_host_tests();
  run_core_flag_scope_host_tests();
  run_core_source_kinds_host_tests();
  run_core_flags_when_member_host_tests();
  run_core_flags_times_repeat_member_host_tests();
  run_core_split_form_loud_host_tests();
  run_core_times_count_zero_host_tests();
  run_core_eq_value_checked_host_tests();
  run_core_late_source_host_tests();
  run_core_held_count_nested_late_host_tests();
  run_core_empty_body_rule_host_tests();
  run_core_packed_bias_novalue_host_tests();
  run_core_novalue_nested_host_tests();
  run_core_builder_id_range_host_tests();
  run_core_loop25_probe_d1_d7_host_tests();
  run_core_text_vectors_host_tests();
  run_core_text_codec_host_tests();
  run_core_text_api_host_tests();
  if (check::failures() != 0) {
    std::fprintf(stderr, "%d failure(s)\n", check::failures());
    return 1;
  }
  std::printf("all tests passed\n");
  return 0;
}
