# Autodev loop record - loop 98

loop: 98
branch: dev
plan_artifact: _docs/loops/loop98/plan98.md
tasks_shipped: [AZ-3524_percent_docs_swift_go, AZ-3525_percent_cpp_device_run, AZ-3526_percent_rust_device_run]
decisions:
  - owner (2026-11-01, hopper empty): "make these" for five loop 97 leftovers; the agent triaged them: items 1 and 2 built, item 3 (epic AZ-2750) already Done in Jira, item 4 (U24) and item 5 (meshbell `FrameSession` rename) not built (see leftovers)
  - agent: three tasks, no epic (same as loops 96 and 97): docs 2 points, C++ device run 3, Rust device run 3
  - agent: the C++ percentage test is target-safe (rows compiled in from `fixtures/ecc/percent-vectors.txt`), in `VECTOR_TESTS`; `cpp/tests/core/main.cpp` also calls it
  - owner (2026-11-01): yes to re-pin the Rust `ecc` flash from 19,140 B to 19,996 B (+856 B, the probe's own test); the agent also lowered the stack pin to the measured 664 B (was 752 B)
  - agent: fixed the README ecc table: the 254-byte error is `TooLong` (Go) and `.tooLong` (Swift), as the packages and tests give
  - agent: Jira AZ-3524 to AZ-3526 created (Task, Medium, no epic, no story points); all In Testing (read back from the transition results)
measurements:
  - C++ percentage test: 13 cases, 25 checks, FAILURES 0 on Cortex-M3, Cortex-M33F and s390x; vector sites 340 of 340 (was 315); 12 packets identical on M3 and M33F; rounding mutation turned all three red; `make -C cpp test` all passed
  - Rust `rust-m33f`: ecc 19,996 B / 664 B (pin 19,996 / 664), EXTRA_RESULT 0, FAILURES 0; rounding mutation gave EXTRA_RESULT 350; base, text and frame unchanged
  - `scripts/loop-tests.sh --all --only rust,cpp,python,typescript,cpp-embedded-arm,rust-embedded`: six stages PASS at 279ef54 (rust after the stale host-built test binaries were rebuilt)
review: "code-review (low): 0 findings; completeness PASS (implementation_completeness_loop98_report.md); feature assessment round 1 COMPLETE (assessment98.md); no security lite pass (docs and test code only)"
retro: none (complexity 2 and 3, no incident; next retro due by loop 102)
leftovers:
  - not run: a physical Cortex-M33F board (QEMU `mps2-an505` only); the Go, C#, Java and Swift suites, the ring, AC-10 and the publish gate (no source of those changed); the ESP stage and the CI publish gate for `codec_ecc.hpp` (they run on the push); a DocC build and `go vet` (no Swift, no network for `x/crypto`)
  - owner: U24 (C++ unbound `bits`/`packed`/`sized` member behind a clear `when`): option B (README only) was chosen on 2026-10-13 and shipped as AZ-2479; say what is still open, for example option A (the core refuses it)
  - owner: the meshbell `FrameSession` rename is in the meshbell repository (outside this workspace); packbin documents it in the README change history (AZ-3291)
  - owner (from loop 96): vcpkg `supports`; a public-key pairing step
  - owner: remove the root-owned folders `cpp/build/embedded/rust-m33f` and `rust-mutants`; the `test-results/embedded/*.hex` files are root-owned and unreadable by the host user
  - `rust/target` is shared by host and container builds: a test binary built on the host bakes `/develop/packbin/...` into `env!("CARGO_MANIFEST_DIR")` paths and fails in the container (`golden.hex`, `frame/vectors.txt` not found); touching `rust/tests/*.rs` rebuilds it (done this loop; nothing to commit)
  - the s390x stage does not compare its percentage packets with the M3 file
  - `_docs/04_deploy/release_notes_0.4.0.md` has uncommitted edits that are not from this loop
  - Jira: AZ-3524 to AZ-3526 In Testing
smoke: PASS (owner, 2026-11-01: answered PASS to the smoke gate; no UI, no local deploy; checks in smoke98.md)
smoke_artifact: _docs/loops/loop98/smoke98.md
assessment_artifact: _docs/loops/loop98/assessment98.md
loop_end_merge: main
