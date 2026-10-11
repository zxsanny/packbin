# Autodev loop record — loop 19

loop: 19
branch:
worktree: none (worked on dev, same as loops 11 to 18)
plan_artifact: _docs/loops/loop19/plan19.md
tasks_shipped: [AZ-2329_pack_round_count_cap, AZ-2330_python_round_fresh_scope, AZ-2331_split_form_pack_fails_loudly, AZ-2332_lone_bytes_in_round_refused, AZ-2333_rust_flags_member_scope, AZ-2334_cpp_empty_group_when_source, AZ-2335_times_count_zero_with_values_error, AZ-2336_python_short_times_list_named_error, AZ-2337_csharp_group_element_members_only, AZ-2338_eq_value_checked_at_construction, AZ-2339_fraction_slot_probe, AZ-2340_cpp_present_result_pinned, AZ-2341_run_suite_python_venv_check, AZ-2342_split_files_near_cap]
partly_shipped: []
held: [AZ-2068_cpp_avr_build (optional stretch, claim cleared)]
leftovers:
  - "The next loop's intake is `_docs/loops/loop20/handoff20.md`: nine owner decisions with a recommendation each (the first is F28, a pack output budget `maxBytes`), the clear gaps (Java G1/F29/F30, Python G2, TypeScript G3, C++ G4, G5, F17/F27, stale docs), the hopper as waves; then the Go package (AZ-2222), then Swift (AZ-2223)"
  - "Review `review19.md`: FAIL before the owner-approved fixes (6 Medium), PASS_WITH_WARNINGS after; open: B6, A5, C2, C10 (Low). Security `_docs/05_security/security_report.md`: PASS_WITH_WARNINGS, 0 Critical, 0 High, 3 Medium (F10, F12, F28), 18 Low; F21 closed for the count, re-filed as F28; F29 to F32 new (F32 fixed in the loop)"
  - "Assessment `assessment19.md` CLARIFY: 7 gap-unclear rows U1 to U7 and 5 gap-clear rows G1 to G5 recorded in the handoff; no re-entry round (owner preference)"
  - "Not run locally in the total test run (`test_run_loop19_report.md`, verdict PARTIAL): the `cpp-example-pico` PlatformIO example (no arm64 toolchain on this host; the CI `embedded` job runs it) and the two real-vcpkg checks of the publish gate; everything else ran, including the embedded ARM and ESP targets"
  - "Total run found no code failure; its two first-pass stage failures (ring, publish gate) were the host Python 3.9 and the missing sysroot: recipe in `AGENT_GOTCHAS.md` and `smoke19.md`"
smoke: PENDING
smoke_artifact: _docs/loops/loop19/smoke19.md
assessment_artifact: _docs/loops/loop19/assessment19.md
suite: PARTIAL locally (Pico example and two vcpkg checks not run, reasons above; every executed stage passed at the final commits)
suite_report: _docs/03_implementation/test_run_loop19_report.md
merged_local: true
conflicts_resolved: ""
loop_end_merge: main (fast-forward `origin/main` only after the `dev` push and a green `test.yml` on `dev`)
---
