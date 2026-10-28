# Feature assessment — loop 78

loop: 78
feature: frame-ring-refusals (AZ-3354, AZ-3355)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-28
**Implement pass**: commits a53fa8f (AZ-3354), 2f40de0 and the MAC self-test commit (AZ-3355); batch report `_docs/03_implementation/batch_01_loop78_report.md`
**Verdict**: CLARIFY — 14 covered / 2 out-of-scope / 0 gap-clear / 1 gap-unclear; answered the same turn (below), final COMPLETE — 15 covered / 2 out-of-scope / 0 / 0

The assessment is by the parent from the code at HEAD and the runs recorded in the batch report (no independent read-only agent, owner preference for one total review).

### Coverage matrix

| id | scenario | status | evidence |
|----|----------|--------|----------|
| R1 | the ring with the 22 refusal rows passes in 8 languages | covered | AZ-3354 AC-1, AC-6; `ring-cases.txt` 22 rows; `ring_frame.py` `Rows._add`; real ring `refusals <lang>: 38 rows, 0 mismatched` x 8 |
| R2 | lines without `dirs` / `out_len` answer as before | covered | AZ-3354 AC-5; `tail()` writes nothing for the defaults; 64 pairs still `mismatched: 0` |
| R3 | concurrent drivers | out-of-scope | `scenarios.md` R3 |
| R4 | a writer prints a word for a good row (seal) | covered | AZ-3355 AC-1; `usable()` in `ring_frame.py`; `writer-prints-word` case |
| R4m | the same for a MAC writer | covered | found during assessment: no test for the MAC side; case `mac-writer-prints-word` added, same commit chain (spec text of AC-1 names the seal row only) |
| R5 | direction 0, 4, not loaded | covered | AZ-3354 AC-3; rows `R.seal.dir0/dir4/unloaded`, `R.open.unloaded`; `dir0-aborts`, `unloaded-direction-accepted` cases; Rust: see U1 below |
| R6 | malformed line | covered | AZ-3355 AC-2, AC-3; `ring-frame-drivers.test.sh` 44 runs; mutation check with the old TypeScript and Swift drivers gave 8 FAIL |
| R7 | `out_len` at the boundary | covered | AZ-3354 AC-4; rows `R.seal.outshort`, `R.open.buffer`, `fit.tag4`, `fit.clear`; `fit-refused` case |
| R8 | the 16 tampered rows still refused | covered | total 38 = 16 + 22; `open-permissive`, `verify-permissive` cases |
| R9 | a bad driver turns the ring red | covered | AZ-3354 AC-6; three new cases |
| R10 | `skip` from all 8 | covered | AZ-3355 AC-4; `skip` case in the driver script, 8 of 8 |
| R11 | a row the reference names otherwise stops the run | covered | AZ-3354 AC-2; `refuse-seal-name-changed`, `refuse-mac-name-changed` |
| R12 | overlap with `vectors.txt` | out-of-scope | accepted-risk, owner 2026-10-28 |
| D3 | `refuse.open.short` not added as a row | covered | `E3.short` is an open row already (batch report discovery 3) |
| D4 | `seal` rows with `out_len` | covered | batch report discovery 4 |
| D2 | `loop-tests.sh` never ran the frame ring | covered | wired (batch report discovery 2); step 11 will run it |
| U1 | Rust has no direction value for 0 and 4; its driver prints `BadValue` itself | covered | owner 2026-10-28, option A (keep, documented in `fixtures/frame/README.md`); batch report discovery 1 |

### Question for the owner (U1) — answered A, keep, 2026-10-28

Java and Swift hand the direction to the package (a `null` and `FrameDirection(number:)`), and the package answers `BadValue`. C#, C++, Go, Python and TypeScript pass the number. Rust cannot: its enum has only Up, Down and Group, so the driver says `BadValue` where it has no value to pass. That is the same step `rust/tests/frame_vectors_tests.rs` takes for the same two rows, but in the ring it is the driver, not the package, that gives the answer for those two rows in one language. Options: (A) keep, documented in `fixtures/frame/README.md`; (B) the Rust driver prints `skip` for them and the checker accepts `skip` for direction 0 and 4 in Rust only; (C) drop the two rows from the ring and leave direction 0 and 4 to `vectors.txt`.

### Latent edges not turned into gaps (Low)

- A direction above 255 wraps in the C#, C++ and Go drivers (257 is Up). No row uses it; the ring cases are fixed text.
- The refusal display shows five lines a reader (out of scope, problem.md).
