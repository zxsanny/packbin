# Autodev loop record - loop 84

loop: 84
branch: dev
plan_artifact: _docs/loops/loop84/plan84.md
tasks_shipped: [AZ-3390_scaffold_requires_helper_test_steps, AZ-3391_split_all_kinds_cpp, AZ-3392_loop83_review_cleanups, AZ-3393_python_version_one_place]
decisions:
  - owner (2026-10-30, hopper empty): took all four candidates of handoff84: the wiring check for the helper tests, the split of all_kinds.cpp, the loop 83 review cleanups, one place for the Python version
  - owner (2026-10-30): raise `m33f_flash_pin` 25720 -> 25760 (the second translation unit of AZ-3391 costs 40 B on the Cortex-M33F image); the other options were to drop the split or to buy the 40 B back
  - agent: probes on HEAD changed the specs: `kMax` is read by two parts and `frame_hex` wraps `hex_of` on purpose (not defects); `arm.sh` links `all_kinds.o` in 3 more places than the spec counted
  - agent: three workers in parallel in tree copies (W1 AZ-3390 then AZ-3393 on the same two files, W2 AZ-3391, W3 AZ-3392); the parent compared each owned path with HEAD before copying it back, and ran the union; W2 built the project's embedded image (3.5 min) and found the pin failure
  - agent: Jira AZ-3390 to AZ-3393 created at new-task (Task, Medium, 3 / 3 / 2 / 3 points, no epic); In Progress, then In Testing after the batch commit (read back)
  - agent: parent edits beyond the workers: `ring-frame.sh` header (RING_FRAME_SHOWN), `ci_cd_pipeline.md` lines 21 and 37 (RING_PYTHON in the workflow env), `lib.sh` pin and the gotcha line
  - agent: loop-end retrospective written (loops 80 to 84), 3 lessons added to LESSONS.md
measurements:
  - HEAD a925aa7 baselines: `ring-wiring.test.sh` 49 lines / 38 `rejects:`, rows 25 / 19, swift 67 / 53; `test.yml` names 3.14 three times; `all_kinds.cpp` 560 lines; M4F flash probe 7,712 B, stack 540 B; M33F image 25,720 B, `ac2` image 25,268 B
  - after: wiring tests 53 / 42 (rows and swift byte-identical); `test.yml` 3.14 once; `all_kinds.cpp` 314 + `all_kinds_rounds.cpp` 246 + `all_kinds_internal.hpp` 25; M4F flash probe and stack unchanged, `ac2` image 25,300 B (+32), M33F image 25,760 B (+40), M33F stack 724 B and frame image 8,416 B unchanged
  - C++ driver (W3): 1,705 invocations byte-identical (stdout, stderr, exit code); `ring-frame.sh` 64 pairs, 0 mismatched, 72 refusal rows x 8 on HEAD and after; with 10 extra rows ahead of the needle HEAD's `id-padded` test FAILS and the changed one passes
  - `loop-tests.sh --only cpp,scaffold,cpp-embedded-arm,ring,publish-gate --all`: cpp 58 s, scaffold 156 s, cpp-embedded-arm 258 s, ring 46 s, publish-gate 145 s: 5 passed, 0 failed, 605 s; `smoke84.sh` 7 of 7
review: "parent review of every diff PASS_WITH_WARNINGS (4 Low, 0 bugs); feature assessment round 1 COMPLETE (assessment84.md, 14 covered); no security audit in plan (no auth, secret or untrusted input)"
retro: _docs/06_metrics/retro_2026-10-30_loop84.md (loops 80 to 84); next retro due after loop 89
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port drops `supports: linux | osx` and claims Windows; a public-key pairing step
  - ring, open: multi-part MAC rows (G8m of loop 77, owner-declined then; need an owner opt-in like U1)
  - ESP-IDF stage (`embedded-esp-core`, `embedded-esp-packages`) has not run on the new `all_kinds_rounds.cpp` source list: the first run is the CI of the loop 84 push
  - review, Low, not applied: a job-level `RING_PYTHON` override in a non-ring job is not compared with the compose image; a non-numeric `RING_FRAME_SHOWN` gives a Python traceback; `m33f_flash_pin` again has zero margin
  - host: the worker-built docker image `packbin-embedded:w2` (4.9 GB) is still on this host; `docker rmi packbin-embedded:w2` when the owner agrees
  - candidates left from handoff84: the AVR `chacha20_xor` count-down loop on a 16-bit `size_t` (needs an emulator; complexity check first); stage stamps on the owner's Mac; a Go window floor of 10 s; removing the `item` pointer; `session_core` clippy; a ring driver for `nostd`; a non-secure 128 KiB image; cycle timing on a real part
  - open: L76-1, L74-3 (see handoff82)
  - Jira: AZ-3390 to AZ-3393 In Testing; AZ-3381 to AZ-3389 and earlier In Testing
lessons:
  - A zero-margin byte pin makes a no-behaviour file split an owner decision (+32 B on the M4F image, +40 B on the M33F one for a second translation unit): run the arm stage at intake when a task touches a pinned image.
  - A worker told to build the project's own embedded image found the pin failure no host build shows; "NOT RUN, no toolchain" is the wrong stop when the stage has a documented image.
  - A review cleanup in a handoff is a lead, not a defect: two of four did not exist on HEAD and the include prune removed nothing.
  - Tree copies for workers (`git archive HEAD`, a pristine `head` and a `work` copy each) worked without disk trouble this time because the copies were deleted before `loop-tests.sh` ran.
smoke: PASS (agent run, owner rule 2026-10-12: 7 of 7 steps)
ci: pending (the CI of the loop 84 push is read after the push; its result goes into the first commit of loop 85)
smoke_artifact: _docs/loops/loop84/smoke84.md
assessment_artifact: _docs/loops/loop84/assessment84.md
loop_end_merge: main
