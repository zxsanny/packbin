# Autodev loop record - loop 95

loop: 95
branch: dev
plan_artifact: _docs/loops/loop95/plan95.md
tasks_shipped: [AZ-3483_arm_no_text_no_ecc_run]
decisions:
  - owner (2026-10-31, hopper empty): chose "ARM run, no-text/no-ECC" from the loop 94 leftovers; core Cortex-M33F; run-only (no flash or stack pin); place: the arm test stage and its docs
  - agent: the run is a step at the end of `target_m33f` (`m33f_small_image`), not a new row, so the row tables and their two stage tests did not change
  - agent: the two host tests (`no_text_tests.cpp`, `no_ecc_tests.cpp`) are compiled unchanged with `-Dmain=` renamed and run as one image through `arm/small_main.cpp`; both compile with both flags together
  - agent: the image links newlib stdio (one heap symbol, as `vectors.elf`), so the heap and exception checks read the core objects; `check-objects.sh` takes `NM` and `SIZE` for the cross binutils (AC-3 and AC-5 (b) reworded to match)
  - agent: Jira AZ-3483 created at intake (Task, Medium, no story points, no epic); In Progress, then In Testing after the batch commit (read back from the transition results)
measurements:
  - arm stage on HEAD before the edit: 16 s, all rows PASS (M33F 315 of 315, flash 25,760 B, stack 724 B, frame 8,416 B / 912 B); after: 18 s, same figures; the new image is 21,688 B of flash, not pinned
  - `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded`: 2 passed, 0 failed, 20 s
  - scratch proofs (AC-5): changed expected value, `malloc` in `values.cpp`, core objects built without `-DPACKBIN_NO_TEXT` each fail the `cpp-m33f` row with the cause named; the unchanged copy passes
  - `lib.test.sh`, `run-parts.test.sh`, `rust/embedded/checks.test.sh` pass; `make object-check` in `gcc:16` passes with the edited script
review: "code-review (low): 0 findings; feature assessment COMPLETE (assessment95.md)"
retro: none (3 points, no incident; next retro due after loop 97)
leftovers:
  - not run locally this loop: go, typescript, csharp, python, rust, java, cpp host, swift, ring, ac10, scaffold and the publish gate (no source they build changed except `cpp/tests/core/check-objects.sh`, run through `make object-check`); CI runs them on the close push
  - the reduced image's flash and stack are not pinned (accepted-risk, Low)
  - `shellcheck` is not installed on this host (`bash -n` only)
  - `_docs/04_deploy/release_notes_0.4.0.md` has uncommitted edits that are not from this loop
  - owner: apply the F44 ruleset; close the epic AZ-2750; U24; meshbell `FrameSession` rename; vcpkg `supports`; a public-key pairing step; multi-part MAC rows in the ring (`v0.4.0` is tagged: `arduino-0.4.0` and `go/v0.4.0` exist on origin)
  - Jira: AZ-3483 In Testing
smoke: PASS (owner, 2026-10-31: answered PASS to the smoke gate; no UI, no local deploy; checks in smoke95.md)
smoke_artifact: _docs/loops/loop95/smoke95.md
assessment_artifact: _docs/loops/loop95/assessment95.md
loop_end_merge: main
