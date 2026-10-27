# Loop 74 smoke — the stream session removed, one set of frame names

LOCAL_URL: none (library; no site). Branch: dev at 11fbea7. Script: `bash _docs/loops/loop74/smoke74.sh`. Run by the agent on 2026-10-27 at host load about 6 to 15, under the owner rule of 2026-10-12: one paste script, with the agent auto-passing the gate when every step passes. The Mac was held awake (a sleep of about 2.5 hours had run through the earlier step 11).

## Checks

- [x] 1. No application source is dirty
- [x] 2. No stream session name in any package, driver, script or probe; Cargo refuses the `session` feature (AC-1, AC-7)
- [x] 3. Rust frame builds alone and with `text,ecc`; 157 frame rows; 27 crypto rows in the default build; the docs test; the D1 names exported (26 Rust test results ok) (AC-2, AC-3, AC-4)
- [x] 4. Rust embedded rows pass with the loop 73 figures and no `session` set: M4F `frame` 20,332 B of 20,480, M33F 20,404 / 1,728; `base`, `text`, `ecc` unchanged (AC-7)
- [x] 5. C# (37 tests), Java (9,725 checks, `api-check` PASS), Swift (17 tests) frame and crypto rows; the 4 README frame examples equal their tests (AC-2, AC-4, AC-10)
- [x] 6. Python (119 passed) and TypeScript (45 passed, 0 failed) crypto rows; no session export; `@noble/hashes` the only dependency (AC-5, AC-6)
- [x] 7. C++ host suite (27 of 27 crypto rows, 6 of 6 one-digit copies caught) and Go (`gofmt`, `go vet`, `go test -race`) (AC-5, AC-8)
- [x] 8. The ring (64 pairs, ECC) and the C++ embedded targets: `cpp-m4f` 7,712 / 540 B, `cpp-m33f` 25,720 / 724 B (AC-3, AC-8)
- [x] 9. Frame, crypto, ECC and golden fixtures equal their loop 73 bytes (SHA-256 equal) (AC-2, AC-3)
- [x] 10. Contract 3.0.0 frame only, ADR-009 accepted and indexed, README and live docs clean (AC-9, AC-10)
- [x] 11. No touched source file grew past 500 lines

## Agent walk

11 PASS, 0 FAIL, 0 NOT RUN (`smoke74: 0 failed`, exit 0), on the fourth full run.

- Run 1 (trial) failed 4 steps, all in the script or its environment: step 2 matched the contract's file name `pack-session.md` as a removed ring command; step 7 ran `make -C cpp test` on top of ELF objects a container stage had left in the shared `cpp/build` (it now cleans first); step 9 diffed the fixture README that the docs task changed; step 10 counted ADR-003 and the history records.
- Run 2 failed step 2 on the wording of the Cargo error for an unknown feature (the host's default Cargo is 1.79; the check now needs a failing build that names the feature).
- Run 3 failed step 7 on Go: `FAIL github.com/zxsanny/packbin/go 87.215s`, the failing test unknown. Reruns of Go alone (verbose, 325 tests) and three repeats of the whole step 7 sequence all passed. Owner decision (2026-10-27, "Rerun, keep failure logs"): the script now keeps all step logs in `$TMPDIR/smoke74-failed-logs` on a failure and names failing Go tests.
- Run 4: 11 of 11.

## For the operator

Nothing: every check ran in the script. The Go intermittent failure (run 3) is an open item in the loop record and the handoff.
