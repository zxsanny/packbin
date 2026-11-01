# Autodev loop record - loop 97

loop: 97
branch: dev
plan_artifact: _docs/loops/loop97/plan97.md
tasks_shipped: [AZ-3499_parity_percent_reference, AZ-3500_parity_percent_python, AZ-3501_parity_percent_typescript, AZ-3502_parity_percent_csharp, AZ-3503_parity_percent_java, AZ-3504_parity_percent_go, AZ-3505_parity_percent_swift, AZ-3506_parity_percent_rust, AZ-3507_parity_percent_cpp, AZ-3508_parity_percent_ring, AZ-3509_parity_percent_docs, AZ-3511_parity_percent_rust_assess, AZ-3512_parity_percent_tests_pytscsj, AZ-3513_parity_percent_tests_goswcpp]
decisions:
  - owner (2026-10-31, hopper empty): option B of "what about adaptive FEC?" - the system derives the parity count from the message length; the owner picks a percentage
  - owner (2026-10-31): the percentage means overhead (parity bytes = the percentage of the clear length), not the share of wrong bytes survived; the fixed `with_parity(n)` stays
  - agent: n = min(32, ceil(p x L / 100)) in integer arithmetic; the receiver finds L from the received length; no new refusal kind; the repair limit is 0 to 16 and is lowered to n / 2 of the message
  - agent: percentage 0 is exactly a scheme without parity (ruled after four workers read it four ways); a percentage and a count replace each other (last setter wins)
  - agent: the new vector rows live in `fixtures/ecc/percent-vectors.txt`, not in `vectors.txt`, so the eight old loaders stay as they are
  - owner (2026-11-01, assessment D4): make the Rust dispatch-mix error unambiguous - `UnpackError::MixedParity` gains `first_percent` and `other_percent` (a public error type change)
  - agent: Jira AZ-3499 to AZ-3509 and AZ-3511 to AZ-3513 created (Task, Medium, no epic, no story points); all In Testing (read back by one JQL at close)
measurements:
  - ring on HEAD: 64 pairs, 52,800 rows (16 protect, 809 repair rows per writer), 0 mismatched; a Go rounding mutation turned it red with 17 mismatched rows
  - package suites after the last commit: Python 4999, TypeScript 3628 (tsc clean), C# 5346, Java 11,697 checks, Go ok (-race), Swift 455 in 80 suites, Rust 1856, C++ all passed in gcc:16
  - `scripts/loop-tests.sh --all --only scaffold,ring,ac10`: scaffold PASS 180 s, ring PASS 43 s, ac10 PASS 6 s
  - Cortex-M33F: C++ all-kinds image 25,760 B / 724 B to 25,948 B / 740 B; Rust ecc set 18,764 B / 744 B to 19,140 B / 752 B; everything else unchanged (measured by the workers on HEAD, not re-run by the parent)
review: "code-review (low) x4, inline read for batch 6: 0 findings; completeness PASS (implementation_completeness_loop97_report.md); feature assessment round 1 CLARIFY then round 2 COMPLETE (assessment97.md); security lite: 0 findings (_docs/05_security/lite_loop97.md)"
retro: _docs/06_metrics/retro_2026-11-01_loop97.md
leftovers:
  - not run: the percentage on a Cortex-M33F device or QEMU image (the images prove size, stack and link only); the CI publish gate and the ESP stage for the new header `cpp/include/packbin/codec_ecc.hpp` (they run on the push)
  - not run by the parent: the Rust embedded stage and the C++ arm stage (the workers ran them); the Swift release-mode speed step; the `PACKBIN_NO_TEXT` bytes branch of the C++ string test (syntax-checked only)
  - the Swift DocC page `Packbin.md` and the Go `doc.go` still describe only the count (source files, excluded by AZ-3509)
  - owner: remove the root-owned folders `cpp/build/embedded/rust-m33f` and `rust-mutants` (left by the Rust embedded container; host `make -C cpp clean` exits 1 on them)
  - `_docs/04_deploy/release_notes_0.4.0.md` has uncommitted edits that are not from this loop
  - owner (from loop 96): close the epic AZ-2750; U24; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step
  - Jira: AZ-3499 to AZ-3509 and AZ-3511 to AZ-3513 In Testing
smoke: PASS (owner, 2026-11-01: answered PASS to the smoke gate; no UI, no local deploy; checks in smoke97.md)
smoke_artifact: _docs/loops/loop97/smoke97.md
assessment_artifact: _docs/loops/loop97/assessment97.md
loop_end_merge: main
