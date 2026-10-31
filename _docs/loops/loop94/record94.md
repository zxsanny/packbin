# Autodev loop record - loop 94

loop: 94
branch: dev
plan_artifact: _docs/loops/loop94/plan94.md
tasks_shipped: [AZ-3479_drop_m4f_rows]
decisions:
  - owner (2026-10-31, hopper empty): chose "Drop the M4F row" from the handoff candidates, then chose to drop both M4F rows (C++ `cpp-m4f` and Rust `rust-m4f`) and the place "arm test stage + docs"
  - agent: the route-packet comparison of `rust-m33f` with the M4F run is removed instead of replaced (simplest; the probe already unpacks the sample on the device and decodes the golden fixture); recorded as a Low accepted-risk concern in the spec
  - agent: `arm/size_main.cpp` was also the M33F stack-meter baseline, so it became `baseline_main.cpp` with the unused 14-entry probe cut; `-fstack-usage` went with its only reader (`max_frame`)
  - agent: the Rust stage keeps one target, so the M33F values are the stage defaults, libs build into `rust/embedded/build/`, and `limits.txt` is deleted (`limits-m33f.txt` and `PACKBIN_RUST_EMBEDDED_LIMITS_M33F` stay); `rust-mutants` links the seeded probes for the M33F
  - agent: Jira AZ-3479 created at intake (Task, Medium, no story points sent, no epic); In Progress, then In Testing after the batch commit (read back from the transition results)
measurements:
  - baseline on a HEAD copy before the edit and the same stages after: figure lines identical apart from the removed M4F lines (M33F 315 of 315, flash 25,760 B, stack 724 B, frame 8,416 B / 912 B, Rust pins of `limits-m33f.txt`, compile warnings 0)
  - removed bars: 8,192 B flash and 2,048 B stack budgets, pins 7,712 B and 540 B (C++), Rust M4F limits (base 16,384/512, text 27,964/2,898, ecc 18,879/798, frame 20,480/1,991)
  - scratch proofs: Rust stage alone passes; the clean lib in place of `mutant-panic` fails `rust-mutants` with "the panic check found nothing in the image with the seeded panic defect"
  - `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold`: 3 passed, 0 failed, 198 s (the stage run itself 16 s + 2 s; the arm stage was about 30 s on the first run with no M4F work)
  - `lib.test.sh`, `run-parts.test.sh`, `checks.test.sh` pass
review: "code-review (low): 0 findings; feature assessment COMPLETE (assessment94.md)"
retro: none (3 points, no incident; next retro due after loop 97)
leftovers:
  - not run locally this loop: go, typescript, csharp, python, rust, java, cpp host, swift, ring, ac10 and the publish gate (no source they build changed); CI runs them on the close push
  - the string-free, ECC-free build (`PACKBIN_NO_TEXT` + `PACKBIN_NO_ECC`) has no ARM run any more (host tests and the Uno build stay); accepted-risk, Medium
  - the CI `embedded-arm` job with only the M33F Rust target is read from the close push, not seen before
  - `shellcheck` is not installed on this host (`bash -n` only)
  - a chained command ran its later steps in the real tree after a failed `rsync` and overwrote the seeded `mutant-panic` lib; found and rebuilt in the loop (see the batch report), the lesson is in the retro-less record only
  - Go window floor of 10 s stays conditional on a stalled ask that no CI run shows; cycle timing and a real non-secure image need hardware
  - owner: apply the F44 ruleset and tag `v0.4.0` (CS-D5 is decided); close the epic AZ-2750; U24; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring
  - Jira: AZ-3479 In Testing
smoke: PASS (owner, 2026-10-31: the agent walked checks 1 to 6 from the evidence of the run, the owner answered PASS; no UI, no local deploy)
smoke_artifact: _docs/loops/loop94/smoke94.md
assessment_artifact: _docs/loops/loop94/assessment94.md
loop_end_merge: main
