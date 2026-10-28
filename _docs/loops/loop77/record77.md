# Autodev loop record — loop 77

loop: 77
branch: dev
plan_artifact: _docs/loops/loop77/plan77.md
tasks_shipped: [AZ-3338_frame_ring, AZ-3341_frame_ring_tamper_wide]
decisions:
  - owner (2026-10-27, assessment round 1): U1 = A, key and msg_id length refusals stay out of the ring (Rust takes `&[u8; 32]` and Rust and C++ an 8-byte msg_id, so the package cannot receive them); scope = tamper rows and wider values now, refusal rows (TooLong, BadValue, BufferFull, bad direction; G2, G3) to a later loop because `fixtures/frame/vectors.txt` holds 64 of them and all 8 packages read it
  - owner (2026-10-27, assessment round 2): G8e = add MAC rows at the SHA-256 padding edges (55, 56, 119, 120, 255 bytes)
  - agent: the ring rows stay explicit hex, validated against `framefmt.py` on every load, with no generator (a second source of truth); two new row kinds, `open` and `verify`, are sent to every reader once, after the lines built on the writers' output
  - agent: the round-2 gaps (MAC epochs, a stricter self-test, a loader that needs tampered rows) went into AZ-3341 as AC-4, AC-8 and AC-12, not into a third ticket
  - agent: no push between assessment rounds (feature-reentry); `main` was fast-forwarded only at the close, so it carried the red 1e2bb45 for the loop
  - agent: Jira AZ-3338 had been set to Done by the earlier session while CI was red; both tasks go to In Testing at close
measurements:
  - 1e2bb45 (the AZ-3338 ring, pushed to dev and main by the earlier session) was red in CI on both: `ring`, `scaffold` and three `publish-gate-readonly*` jobs; the ring had only run against stand-in drivers
  - six defects in it: Swift 6 on Linux refuses the `stderr` global (CI); `run-suite.test.sh` still counted 13 cargo runs and 11 step lines, now 14 and 12 (CI); the C++ driver did not link `frame.cpp` (found by compiling with gcc:16); the TypeScript and Java drivers called `FrameDirections` wrongly (found by the first real ring run, 21 s); `ring-frame.test.sh` ran in no CI job
  - d0b8525 (the fix, dev only): CI run 40526577512, 20 of 20 jobs green, the `ring` job `64 pairs, mismatched: 0` on Linux
  - 5e48211 (the close, pushed to dev and main as fast-forwards): CI runs 40543757930 (dev) and 40543763854 (main), 20 of 20 jobs green each; the `ring` job on Linux printed `64 pairs, mismatched: 0` and 8 lines `refusals <lang>: 16 rows, 0 mismatched`, and the scaffold job ran the frame ring self-test
  - the ring now has 23 seal, 19 mac, 11 open and 5 verify rows (was 8 and 4): bodies up to 255 bytes, epochs 0 / 65535 / 16777215 for seal and MAC, kinds 0 / 8 / 15, ids of 00 and ff bytes, associated data empty and 255 bytes, MAC n = 32, labels of 1 and 32 bytes, messages of 0 to 255 bytes; all 8 languages refuse the 16 tampered rows alike
  - the new `E3.short` row caught a real defect: the TypeScript driver printed `error` for a short packet (its value has `field`, not `kind`); without the fix the ring exits 1 and names the row (smoke77 step 4)
  - step 11 `scripts/loop-tests.sh --all` at 11a82d2, host load 4 to 35: typescript 30 s, csharp 57 s, rust 94 s, go 176 s, java 25 s, python 159 s, cpp 65 s, scaffold 318 s, swift 430 s, cpp-embedded-arm 16 s, rust-embedded 3 s, ring 51 s, ac10 5 s, publish-gate 322 s: 14 passed, 0 failed, 1,005 s (a first run was stopped after seven suites to wait for assessment round 2)
  - smoke `smoke77.sh` 7 of 7 at 11a82d2 (two trials failed step 4 on script bugs, fixed)
review: "two independent read-only agents (assessment round 1: CLARIFY 8 covered / 2 out-of-scope / 9 gap-clear / 1 gap-unclear; round 2: CLARIFY 17 / 6 / 2 / 1), then the parent for round 3: COMPLETE 20 / 6 / 0 / 0 (assessment77.md); no per-batch code review (owner preference)"
retro: not due (last: loop 74; next due after loop 79)
leftovers:
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port should drop `supports: linux | osx`
  - ring, deferred by the owner: refusal rows by name (G2: TooLong, ShortPacket, BadValue; G3: a direction not loaded or bad, BufferFull; they need `dirs` and `out_len` columns and drivers that stop aborting on a bad direction); multi-part MAC messages (a new driver line format)
  - ring, open and not in AZ-3341: L-1 (lenient hex in the ts, swift, cpp and java drivers), L-2 (a writer's non-hex line crashes the readers instead of being blamed on the writer), L-3 (the Go driver discards parse errors), the Python driver does not answer `open-skip` / `verify-skip` with `skip` (the other seven do), the refusal display shows five lines a reader
  - candidates from loop 76 still open: a public-key pairing step; the AVR runtime check of `chacha20_xor`; a cfg-only cleanup of the 4 dead-code warnings in `cfg(test)` items of the `frame` test builds
  - open: the cause of the `publish-timing.selftest.sh` broken-pipe flake (L75-2) is unproven; Go intermittent failure L74-3 did not show in step 11
  - Jira: AZ-3338 and AZ-3341 In Testing (read back at close); AZ-3329..AZ-3334 and earlier AZ-3280..AZ-3295, AZ-3322 In Testing; epic AZ-2645
lessons:
  - A self-test with stand-in drivers proves the script and the checker only: run the real ring and every `test.yml` step in order before the first push, and read CI on `dev` before `main`.
  - A comparison harness with only good rows passes a package that accepts forgeries: add rows that must be refused and a stand-in reader that accepts them.
smoke: PASS
smoke_artifact: _docs/loops/loop77/smoke77.md
assessment_artifact: _docs/loops/loop77/assessment77.md
loop_end_merge: main
