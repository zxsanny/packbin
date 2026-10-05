# Autodev loop record — loop 10

loop: 10
branch: loop/10-cpp-microcontroller
worktree: /Users/zxsanny/dev/zxsanny/packbin-loop-10-cpp-microcontroller
plan_artifact: _docs/loops/loop10/plan10.md
tasks_shipped: [AZ-2060_cpp_core_scalars, AZ-2061_cpp_core_schemes, AZ-2062_cpp_core_grouped_kinds, AZ-2063_cpp_core_counted_kinds, AZ-2064_cpp_host_on_core, AZ-2065_cpp_core_session, AZ-2066_cpp_target_ci, AZ-2067_cpp_embedded_packaging, AZ-2070_hostile_vectors, AZ-2078_cpp_flag_byte_scope, AZ-2081_cpp_bool_u2_construction, AZ-2106 (security fix, no spec file)]
leftovers:
  - "AZ-2071 to AZ-2105 (33 bug-fix tasks, epic AZ-2069): loop 11 onward by severity: 2071-2077, then 2079-2080 and 2082-2093, then 2094-2098 (release blockers), then 2099-2105. v0.2.0 is tagged only after AZ-2094 to AZ-2097 land"
  - "AZ-2068_cpp_avr_build: optional stretch, stays in todo/"
  - "User decision: UTF-8 validation in the C++ core (invalid_utf8 and invalid_utf8_dict_key vectors unpack Ok), with the error labels (C15)"
  - "User decision: project AC-8 wording ('names the field and the bytes remaining') against the C++ Result (order id, byte offset)"
  - "Maintainer: AC-12 install by registry name needs a published tag and PlatformIO / ESP-IDF registry tokens; Arduino Library Manager registration"
  - "Open Low security findings F1-F3 in _docs/05_security/security_report.md (checkout pin, arduino-cli checksum, image digests)"
  - "Add a 32-bit fuzz or sanitizer build to the embedded job; the stack budget has 24 B of margin"
  - "Candidate C++ task: an unbound container round that reads nothing ends it (done); oversize_count_times expected value could allow short_packet|too_many for other packages"
  - "Docs not fixed in step 13: drift rows 5, 6, 8 (counts), 9, 10, 13-15, 17, 18, 20, 30, 32-37 and README rows 27-29 (not C++ or outside the loop's files)"
smoke: PASS
smoke_artifact: _docs/loops/loop10/smoke10.md
assessment_artifact: _docs/loops/loop10/assessment10.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: stage
