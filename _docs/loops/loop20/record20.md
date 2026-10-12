# Autodev loop record — loop 20

loop: 20
branch:
worktree: none (worked on dev, same as loops 11 to 19)
plan_artifact: _docs/loops/loop20/plan20.md
tasks_shipped: [AZ-2354_pack_output_budget, AZ-2355_repeat_round_cap_on_pack, AZ-2356_count_zero_after_byte_list_error, AZ-2357_cpp_count_behind_clear_when, AZ-2358_csharp_whole_float_refused, AZ-2359_enum_slot_values_pinned, AZ-2360_flags_skipped_count_values_loud, AZ-2361_java_counts_fractions_sink, AZ-2362_python_repeat_empty_flags_named_error, AZ-2363_typescript_times_in_when_split_bit, AZ-2364_cpp_late_marks_every_member, AZ-2365_split_files_near_cap_l20, AZ-2366_csharp_typed_round_unpack_error, AZ-2367_hostile_pack_budget_cases]
partly_shipped: [AZ-2358 (eq values and u2/bits/packed slots done; plain integer fields moved to AZ-2373 by owner decision 2026-10-11)]
held: [AZ-2068_cpp_avr_build (optional stretch), AZ-2373_csharp_exact_integer_types_unpack (loop 21 hopper)]
leftovers:
  - "The next loop's intake is `_docs/loops/loop21/handoff21.md`: ten owner decisions with a recommendation each (U1 to U10), the clear gaps (F33 empty round body charges nothing, F34 TypeScript sliceRound copy, hostile loader rule tables, C# count text and lone byte[] in a repeat, slow tests, AZ-2373), the hopper as waves; then the Go package (AZ-2222), then Swift (AZ-2223)"
  - "Review `review20.md`: 19 findings (1 High, 5 Medium, 13 Low); the fix pass closed A1, A2, A4, A8, B1, B3, C1, C2, C3; A3 accepted (typed non-nullable member counts as given). Security `_docs/05_security/security_report.md`: PASS_WITH_WARNINGS, 0 Critical, 0 High, 2 Medium (F10, F12), 16 Low; F28, F29, F30, F17, F27 fixed; F33 and F34 new"
  - "Assessment `assessment20.md` CLARIFY: 10 gap-unclear rows U1 to U10 and 5 gap-clear rows G1 to G5 recorded in the handoff; no re-entry round (owner preference)"
  - "Not run locally in the total test run (`test_run_loop20_report.md`, verdict PARTIAL): the `cpp-example-pico` PlatformIO example (no arm64 toolchain on this host; the CI `embedded` job runs it) and the two real-vcpkg checks of the publish gate; everything else ran. First-pass failures were a real test defect (Python AC-1 child process import, fixed in 803625f), two timing tests under machine load (C# Ac10 1427 ms, Python test_nfr_round_trips 3.06 s; idle A/B: +20 % and +13 to 15 % against loop 19, far inside the bounds), my own 60 s alarm, and network errors in the ESP stage"
  - "Cortex-M4F flash margin is 32 B (8160 of 8192 B): any edit to `cpp/src/core` or `cpp/include` in loop 21 needs a flash saving first"
  - "Watch the first CI run of `dev` and `main` for the two timing bounds (C# AC-10 and Python test_nfr_round_trips) and the Pico example in the `embedded` job"
smoke: PASS
smoke_artifact: _docs/loops/loop20/smoke20.md
assessment_artifact: _docs/loops/loop20/assessment20.md
suite: PARTIAL locally (Pico example and two vcpkg checks not run, reasons above; every executed stage passed at the final commits)
suite_report: _docs/03_implementation/test_run_loop20_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: main (fast-forward `origin/main` only after the `dev` push and a green `test.yml` on `dev`)
---
