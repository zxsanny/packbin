# Autodev loop record — loop 81

loop: 81
branch: dev
plan_artifact: _docs/loops/loop81/plan81.md
tasks_shipped: [AZ-3378_frame_ring_key_id_length]
decisions:
  - owner (2026-10-29, intake): the candidate is "ring key and msg_id length refusals" (U1 of loop 77), not the stage-stamp refresh the handoff recommended: the stamps are files in the gitignored `test-results/` of the owner's Mac, none exists on this Linux clone (`loop-tests.sh --plan`: 14 stages "never passed here"), and a run here would change nothing in git
  - owner (2026-10-29): U1 is reopened with the Rust (key, msg_id) and C++ (msg_id) drivers printing `BadValue` themselves where the package cannot receive the value, documented in `fixtures/frame/README.md`, as for Rust directions 0 and 4 (loop 78). Not taken: a `skip=` field in the row, and leaving U1 out
  - owner (2026-10-29): a Temurin JDK 26.0.2.1 tarball under `~/.local/share/packbin-jdk26` (SHA-256 checked against the Adoptium API) instead of the apt package, which needs a sudo password; `npm ci` in `typescript/` from the lockfile
  - owner (2026-10-29): waiver, the host has no `ruby` and no sudo: `report-row.test.sh`, `run-suite.test.sh`, `ring-wiring.test.sh` and `ring-wiring-swift.test.sh` (scaffold stage) are NOT RUN here; the other 20 scaffold commands were run one by one
  - owner (2026-10-29): second waiver, same cause: the publish-gate checks `publish-workflow.test.sh` (AZ-2095) and `publish-pins.test.sh` (AZ-2214) in share 7 are NOT RUN here; CI's `scaffold` and `publish-gate-rest` jobs run all six on a runner with Ruby
  - owner (2026-10-29): replace Ruby with Python in the CI scripts, as loop 82 (a feature of about 8 points, not a side edit); the size estimate given first (29 lines) was wrong, the measured size is in `handoff82.md`
  - agent: Jira AZ-3378 created by new-task (Task, Medium, 3 points); In Progress, then In Testing after the batch commit. The first two In Testing transitions did not run (a host PreToolUse hook timed out before the call was sent): leftover written with the replay payload, replayed successfully later in the loop, leftover deleted
  - agent: no per-batch code review (owner preference since loop 70); the parent read the diff of the two drivers, the loader, the rows and both scripts; shellcheck (koalaman/shellcheck:stable) on the two edited scripts exit 0
  - agent: `verify` with a wrong-length key is checked by the driver test in all 8 languages (the probe showed all 8 print `BadValue`), though the spec only promised the Rust path; no ring row carries it (a verify row answers valid or invalid)
  - agent: `smoke81.sh` names the waived scripts in its output; step 8 (`loop-tests.sh --only ring,publish-gate`) failed on the two waived checks only, and the owner accepted it
measurements:
  - probe on HEAD 489d291 (Linux, Ubuntu 26.04; python 3.14.4, dotnet 10.0.400, node 22.23.1, rustc 1.97.1, g++ 15.2, JDK 26.0.2.1, Go and Swift in containers): real ring `64 pairs, mismatched: 0`, `refusals <lang>: 43 rows, 0 mismatched` x 8
  - same ring with 12 extra rows (key of 31 and 33 bytes in seal, open, mac; msg_id of 7, 9, 16 bytes in seal, open): C#, TypeScript, Python, Java, Go, Swift `0 mismatched`; C++ `55 rows, 6 mismatched` (seal returned a body, open `TagMismatch`); Rust ended the seal phase on `frame line 42: key must be 32 bytes`
  - empty key or msg_id (`-`): the HEAD loader wrote `key.hex()` (an empty string), the line lost a field and 8 of 8 drivers refused it as malformed (`frame line 42: bad hex: 3`)
  - HEAD C++ driver cut a 9-byte id to 8: `R.open.id9 open gave 84b357fa5b0b53ff90710727, wanted BadValue` (a frame sealed under another id opened)
  - after the change, C++ in `gcc:16` (`-std=c++17 -O2 -Wall -Wextra -Werror`), Rust on 1.99.1 and 1.97.0 without a warning: `ring-frame: 64 pairs, mismatched: 0`, `refusals <lang>: 58 rows, 0 mismatched` x 8; `ring-frame-drivers.test.sh` `all passed (8 languages, 276 checks)` (132 on HEAD); `ring-frame.test.sh` 37 PASS (34 on HEAD)
  - non-vacuity, scratch copies: HEAD drivers: 18 Rust and 6 C++ driver checks fail; HEAD rows: 3 failures; HEAD loader: the empty-token case fails
  - step 11 through `scripts/loop-tests.sh --only scaffold,ring`: ring PASS (46 s); scaffold stopped after 1 s on `ruby: command not found` (exit 127, `report-row.test.sh` line 14); the 20 scaffold commands without the four Ruby scripts passed in 123 s (`fixtures/hostile/cases.test.sh` 43 s, `ring-prepare.test.sh` 24 s, `scripts/loop-tests.test.sh` 17 s, every other command 6 s or less)
  - official smoke `smoke81.sh` at ed7d144 (395 s, host load 1.3 to 21): steps 1 to 7 and 9 PASS; step 8: ring PASS (42 s), publish-gate FAIL (194 s): 7 of 8 shares PASS, share 7 `readonly-full,static,crates-token,registry,vcpkg,go,manifest,npm,position,workflow,pins` 9 of 11 checks pass and 2 print `ruby is required to parse the workflow YAML`; NOT RUN lines of the gate: swift consumer resolve (no swift on PATH), vcpkg consumer and supports checks (no vcpkg tool), as on the Mac
  - CI of the loop 80 push, read at the start of this loop: dev 3 min 44 s and main 8 min 32 s, all green
review: "no per-batch code review (owner preference); feature assessment by the parent: round 1 COMPLETE, 9 covered / 3 out-of-scope (assessment81.md); security lite diff-scoped, 0 findings (_docs/05_security/lite_loop81.md)"
retro: not due (loops 75 to 79 done in loop 79; next after loop 84)
leftovers:
  - loop 82, owner decision: replace Ruby with Python in the CI scripts (`handoff82.md`: 10 scripts, about 555 lines of embedded Ruby, `publish-precheck.sh` on the release path, PyYAML pin in `tool-pins.txt` and a CI install step)
  - owner (unchanged): CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session` to `FrameSession`; whether the vcpkg port should drop `supports: linux | osx`; a public-key pairing step
  - ring, open: multi-part MAC messages (G8m of loop 77, owner-declined then; needs an owner opt-in like U1); which error comes first for a row that combines a wrong-length key or id with a second refusal (not walked, no such row)
  - Mac: the stage stamps of `scripts/loop-tests.sh` are stale (b7b8140); one clean run on the Mac refreshes them (this Linux clone has none)
  - this host: the documented path for the JDK (`apt install openjdk-26-jdk-headless`) and for Ruby (`apt install ruby`) is still open; the ring here ran on a user-directory JDK; CI pins Node 24, GCC 16, Rust 1.98 and this host ran Node 22, GCC 15 (C++ in `gcc:16`), Rust 1.99.1 and 1.97.0, so CI's `ring` job on the push is the first run on the pinned toolchains
  - `handoff.cpp` is 639 lines (631 at loop 79), over the 500-line cap before this loop; splitting it is excluded from AZ-3356 and AZ-3378
  - open: L76-1 (timing-selftest flake cause unproven); Go intermittent failure L74-3
  - Jira: AZ-3378 In Testing; AZ-3369, AZ-3356, AZ-3357, AZ-3354, AZ-3355 and earlier In Testing
lessons:
  - A handoff candidate that names a per-host artifact (stage stamps in the gitignored `test-results/`) is checked on the host that will do the work before the loop is built around it: the first pick of this loop described the owner's Mac, and this clone had no stamps at all.
  - A size quoted for a replacement is measured before it is said: "29 lines of Ruby" was 555 lines of embedded programs in 10 scripts (an `if:` evaluator, mutation tests written as Ruby, one script on the release path) and a new pinned dependency in CI.
  - A fresh host needs its prerequisites listed before the loop starts: this one lacked a JDK, `typescript/node_modules` and Ruby, and a `docker pull` timed out once; the code change itself took far less wall time than the setup.
smoke: PASS (owner waiver of 2026-10-29: 8 of 9 steps; step 8 failed only on the two Ruby checks of the publish gate; with the four scaffold scripts, 6 Ruby scripts NOT RUN here)
smoke_artifact: _docs/loops/loop81/smoke81.md
assessment_artifact: _docs/loops/loop81/assessment81.md
loop_end_merge: main
