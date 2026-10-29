# Feature assessment — loop 81

loop: 81
feature: ring-key-id-length-refusals
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-29
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop81_report.md` (commit ed7d144; no `implementation_report_*` or completeness report: test-infrastructure task, as in loops 78 to 80)
**Verdict**: COMPLETE — 9 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | `seal` row with a key of 31 bytes: all 8 drivers print `BadValue` | covered | AC-1, AC-2, AC-3; row `R.seal.key31`; real ring `refusals <lang>: 58 rows, 0 mismatched` x 8, driver test `seal-key-31`; `handoff-rust/src/frame.rs` `seal` (the other seven: the package) | intake |
| S2 | `open` and `mac` rows with a key of 33 bytes | covered | AC-1, AC-2, AC-3; rows `R.open.key33`, `R.mac.key33`; same ring run, driver tests `open-key-33`, `mac-key-33`; `frame.rs` `open`, `mac` | intake |
| S3 | `seal` row with a `msg_id` of 7 bytes (short): no zero padding in Rust, no padding in C++ | covered | AC-1, AC-3, AC-4; row `R.seal.id7`; ring run and driver test `seal-id-7`; `frame.rs` `msg_id8`, `handoff.cpp` `frame_seal` | intake |
| S4 | `open` row with a `msg_id` of 9 bytes (long): C++ no longer cuts it to 8 | covered | AC-1, AC-4; row `R.open.id9`; ring run and driver test `open-id-9`; `handoff.cpp` `frame_open` | intake |
| S5 | key or `msg_id` empty (`-`) reaches the drivers as one token | covered | AC-1, AC-5; rows `R.seal.key0`, `R.seal.id0`, `R.open.key0`, `R.open.id0`, `R.mac.key0`; `ring-frame.test.sh` `empty-key-and-id-keep-fields`; `scripts/frame/ring_frame.py` `hx(key)`, `hx(msg_id)` | intake |
| S6 | the 64 pairs of good rows (32-byte key, 8-byte id) are unchanged | covered | AC-2; real ring `ring-frame: 64 pairs, mismatched: 0`; no change to a good row | intake |
| S7 | a driver that pads or cuts the id, or ends on a wrong key, is put back: the ring is red and names the row | covered | AC-6; `ring-frame.test.sh` `id-padded` (`go: R.seal.id7 seal gave`) and `key-aborts`; scratch copies with the HEAD drivers, rows and loader (`batch_01_loop81_report.md`) | intake |
| S8 | `verify` row with a key of the wrong length | out-of-scope | spec `### Excluded`: "A `verify` row with a wrong-length key: a `verify` row answers `valid` or `invalid`." | intake |
| D1 | `verify` line with a key of 31, 33 or 0 bytes: all 8 drivers print `BadValue` | covered | AC-3, AC-7; `ring-frame-drivers.test.sh` `verify-key-31/33/0` x 8 (276 checks); `frame.rs` `verify` | batch_01 discoveries #1 |
| D2 | HEAD C++ driver opened a frame under another 9-byte id (cut to 8) | covered | AC-4; row `R.open.id9` (HEAD: `open gave 84b357fa..., wanted BadValue`); `handoff.cpp` `frame_open` | batch_01 discoveries #2 |
| D3 | a row combining a wrong-length key or id with a second refusal: error order in the 8 drivers | out-of-scope | spec `### Excluded`: "Rows that combine a wrong-length value with another refusal (which error comes first)" | batch_01 discoveries #3 |
| N1 | a `prev_key` of the wrong length | out-of-scope | spec `### Excluded`: "any field the row format does not carry (`prev_key`)" | scenarios.md Not walked |

Batch discovery #4 (JDK and `typescript/node_modules` missing on a fresh Linux clone) is an environment fact, not a usage angle of the feature; it is in the batch report and the loop record.

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- none (the matrix has 12 rows; the cap is 12)

### Harness gaps

- none (the batch report has the `## Discovered during implementation` table)
- Step 2 re-walk: no new configuration key, persisted field, caller or default; a wrong key or id on a line that also holds a malformed number is still a malformed line in Rust and C++ (the numbers are parsed before the key and id are checked; read in the code, not run), unchanged from HEAD.
