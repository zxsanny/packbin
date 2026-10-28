# Autodev loop record — loop 78

loop: 78
branch: dev
plan_artifact: _docs/loops/loop78/plan78.md
tasks_shipped: [AZ-3354_frame_ring_refusal_rows, AZ-3355_frame_ring_driver_hardening]
decisions:
  - owner (2026-10-28, intake): bundle "accept all recommended": refusal rows by name for G2 and G3 with `dirs` and `out_len`, drivers that do not abort, L-1 strict hex, L-2 blame the writer, L-3 Go parse checks, the Python `skip` answer; out: key and msg_id length refusals (U1 of loop 77), multi-part MAC, the five-line refusal display
  - owner (2026-10-28, assessment round 1, U1): Rust has no direction value for 0 and 4, so its driver prints `BadValue` itself for those two rows; keep, documented in `fixtures/frame/README.md` (Java passes `null` and Swift calls `FrameDirection(number:)`, the package answers; the other five hand the number to the package)
  - agent: 8 points split into 5 + 3 (AZ-3354, AZ-3355), no epic; the writer-blame change (L-2) lands before the strict drivers because strict hex makes a bad writer louder (fit decision)
  - agent: the 22 rows are the refusal cases of `vectors.txt` without `refuse.open.short` (the open rows already hold the short packet); `seal` rows may end in an `out_len` (two exact-fit rows `fit.tag4`, `fit.clear`, opened into a buffer of exactly the plaintext) so a driver that answers `BufferFull` for every short buffer fails
  - agent: `scripts/loop-tests.sh` never ran `ring-frame.sh` or `ring-frame.test.sh` (step 11 of loop 77 ran only the cross-language ring and the ECC ring); wired in this loop together with the new `ring-frame-drivers.test.sh`
  - agent: security lite escalated by T1 (a `test.yml` step) and T3 (16 files), answered with a diff-scoped pass (`_docs/05_security/lite_loop78.md`): 0 Critical/High/Medium, 2 Low
  - agent: no per-batch review (owner preference); the assessment was done by the parent, not by independent read-only agents
measurements:
  - real ring on the Mac after AZ-3354: 64 pairs, `refusals <lang>: 38 rows, 0 mismatched` x 8 (was 16); first run of all 8 languages green
  - driver script `ring-frame-drivers.test.sh`: 44 of 44; with the committed lenient TypeScript and Swift drivers put back it printed 8 FAIL (the check is not vacuous)
  - step 11 `scripts/loop-tests.sh --all` at b7b8140, host load 5 to 37: typescript 29 s, csharp 108 s, python 213 s, rust 136 s, go 245 s, java 28 s, cpp 96 s, scaffold 347 s, swift 453 s, cpp-embedded-arm 17 s, rust-embedded 3 s, ring 54 s (now with the frame ring and the driver script), ac10 5 s, publish-gate 341 s: 14 passed, 0 failed, 1,118 s; two vcpkg checks NOT RUN on the Mac (CI runs them)
  - AZ-3354 AC-7 (ring time +20 %): not comparable, the step 11 `ring` stage of loop 77 (51 s) did not run the frame ring; the frame ring with cached builds takes 4 to 13 s on the Mac
  - smoke `smoke78.sh` 7 of 7 on the first trial
  - local CI parity: `g++ -std=c++17 -O2 -Wall -Wextra -Werror` in `gcc:16`, `gofmt` and `go vet` in `golang:1.27`, `cargo build` (no warnings), shellcheck on the ring scripts
review: "no per-batch code review (owner preference); feature assessment by the parent: round 1 CLARIFY (U1) answered the same turn, final COMPLETE 15 covered / 2 out-of-scope (assessment78.md)"
retro: not due (last: loop 74; next due after loop 79)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port should drop `supports: linux | osx`
  - ring, open: the refusal display shows five lines a reader; a direction above 255 wraps in the C#, C++ and Go drivers (257 reads as Up; Low); a huge `out_len` aborts a driver (Low); multi-part MAC messages (a new driver line format); key and msg_id length refusals (U1 of loop 77, the types forbid them)
  - candidates from loop 76 still open: a public-key pairing step; the AVR runtime check of `chacha20_xor`; a cfg-only cleanup of the 4 dead-code warnings in `cfg(test)` items of the `frame` test builds
  - open: the cause of the `publish-timing.selftest.sh` broken-pipe flake (L75-2) is unproven; Go intermittent failure L74-3 did not show in step 11
  - Jira: AZ-3354 and AZ-3355 In Testing (read back); AZ-3338, AZ-3341, AZ-3329..AZ-3334 and earlier In Testing
lessons:
  - A CI step added to `test.yml` also goes into `scripts/loop-tests.sh` in the same commit: step 11 of loop 77 passed 14 stages without running the frame ring or its self-test, because the `ring` and `scaffold` stages list their scripts by hand (found in loop 78 by comparing the two).
  - A new check over real drivers is proven by putting an old defective driver back (`git show <commit>:<file>` in a scratch copy) and seeing it fail: the lenient TypeScript and Swift drivers gave 8 FAIL; passing 44 of 44 on the first run proves nothing alone.
smoke: PASS
smoke_artifact: _docs/loops/loop78/smoke78.md
assessment_artifact: _docs/loops/loop78/assessment78.md
loop_end_merge: main
