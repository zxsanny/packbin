# Autodev loop record — loop 11

loop: 11
branch:
worktree: none (worked on dev; owner declined a worktree)
plan_artifact: _docs/loops/loop11/plan11.md
tasks_shipped: [AZ-2071_python_hostile_unpack, AZ-2072_typescript_hostile_unpack, AZ-2073_csharp_hostile_unpack, AZ-2074_java_hostile_unpack, AZ-2075_rust_hostile_unpack, AZ-2076_csharp_unpack_state_per_call, AZ-2077_java_unpack_state_per_call, AZ-2107_python_zero_width_elements, AZ-2108_typescript_zero_width_elements, AZ-2109_csharp_zero_width_elements, AZ-2110_java_zero_width_elements, AZ-2111_rust_zero_width_elements, AZ-2122_typescript_proto_key_when_scope_bom, AZ-2123_csharp_top_range_ints_capacity_session_counter, AZ-2124_java_atomic_session_counter, AZ-2125_rust_capacity_hint_bounded]
leftovers:
  - "Follow-up tickets from feature-assess and worker discoveries, unclaimed in todo/: AZ-2112 (TS u64 counts), AZ-2113 (Python later-field refs), AZ-2114 (hostile session tests, extended to zero-width elements, all five packages), AZ-2115 (split-form reference bytes TS/C#), AZ-2116 (C# exact integer types for the other kinds), AZ-2117 (Rust named-reference scope), AZ-2118 (Rust pack checked_add), AZ-2119 (C# group as list/dict element throws), AZ-2120 (C# When under combined Flags dropped on pack), AZ-2121 (orphan flag-bit tests for every container)"
  - "Remaining bug-fix hopper from the loop 10 plan, by severity: AZ-2079, AZ-2080, AZ-2082 to AZ-2093, then AZ-2094 to AZ-2098 (release blockers; v0.2.0 is tagged only after AZ-2094 to AZ-2097 land), then AZ-2099 to AZ-2105. AZ-2068_cpp_avr_build stays an optional stretch"
  - "Python orphan flag-bit rule rides on AZ-2100 (split form cannot be built in Python yet); recorded as a flagged concern on that spec"
  - "Owner decision still open: error kind and label of the interim error (C15); each package picks its own needed/left/label until then"
  - "TypeScript: counts naming a field of the same repeat round still read the accumulated list (same shape as the fixed when bug); no ticket yet"
  - "Java: PackSession send/recv/seed fields are plain (cross-thread packing assumes the session is opened before other threads start); packet number has no overflow guard"
  - "No packet-size budget in unpack (linear time and memory); the README tells callers to cap packet length at the transport"
  - "Retro recommendation: keep the security auditor's cross-package fuzz generators and drivers in the repo (they live only in the session scratchpad); add a typecheck job (tsc --noEmit --strict over typescript/src) to CI; number owner decisions in the specs; add 'no git stash/checkout/reset' to every worker prompt"
  - "Open Low security findings F1-F3 in _docs/05_security/security_report.md (checkout pin, arduino-cli checksum, image digests) and the loop 10 items AC-12 registry install, 32-bit fuzz in the embedded job"
  - "Docs: _docs/01_solution/schema.md split-form section updated; per-package tests.md and traceability-matrix.md not updated for the new tests; loop 10 drift rows 5, 6, 8-10, 13-15, 17, 18, 20, 30, 32-37 still not fixed"
  - "Breaking changes for callers (in README and package docs): flag byte in one when with its bit in another when; flag byte outside a list/repeat/times/dict element with its bit inside; zero-width times/list/dict element is now an error; C# UnpackResult.Values holds ulong/long for u64/i64"
smoke: PASS
smoke_artifact: _docs/loops/loop11/smoke11.md
assessment_artifact: _docs/loops/loop11/assessment11.md
suite: PASS
suite_report: _docs/03_implementation/test_run_loop11_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: stage
