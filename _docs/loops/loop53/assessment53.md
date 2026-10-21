# Feature assessment — loop 53

loop: 53
feature: rust-nostd-core (wave C: AZ-2756, AZ-2757)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-21
**Implement pass**: batches 01..02, `_docs/03_implementation/batch_01_loop53_report.md`, `batch_02_loop53_report.md`
**Verdict**: COMPLETE — 9 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| R4 | hostile corpus | covered | AZ-2757 AC-1; `nostd_hostile_tests::*` (15 unpack, 2 limit, 14 construct, corpus and mutations), `nostd_hostile_pack_tests::*` (20 run, 18 skipped with reasons); `nostd/present.rs` | intake |
| R10 | session seal and open, caller nonce | covered | AZ-2756 AC-1, AC-3; `nostd_session_tests::against_std::*` (same bytes with parity 0, 2, 4, 8, 32, cross-open both ways); `nostd/session.rs`, `session_core/` | intake |
| R11 | default features, whole existing suite | covered | full `cargo test` (539 lib tests) and the ring wiring unchanged; std `PackSession` runs on `session_core` | intake |
| D6 | stack of a nested scheme on the device | covered | embedded stage: `text` set 2,760 B with a `repeat` of strings, a dictionary and a group; `embedded/probe/src/lib.rs::nested_roundtrip` | assess-round-1 (loop 51) |
| X5 | a repeat of long raw strings | covered | measured 5.96 s against 1 s nominal, memo ported, 14 ms; `nostd_raw_repeat_tests::*`; `nostd/text/raw.rs` | assess-round-1 (loop 52) |
| S1 | session: refusals (seed and nonce size, not open, already open, full buffer, tampered type, `Uncorrectable`, `TooLong`) with no partial output and a kept send position | covered | AZ-2756 AC-3; `nostd_session_tests::ac3_*`, `protected::ac3_*` | batch_01 |
| S2 | session: no allocation, no panic path | covered | AZ-2756 AC-2; embedded stage `session` set (no heap or panic symbol) | batch_01 |
| S3 | every fixture file read alike by both walkers | covered | AZ-2757 AC-2; `nostd_fixture_differential_tests::*` | batch_02 |
| S4 | publish and docs | covered | AZ-2757 AC-3, AC-4; `cargo publish --dry-run` from a staged copy, `nostd_docs_tests` | batch_02 |
| X4 | size limits of `text`, `ecc`, `session` | out-of-scope | owner input (handoff53 "Owner input needed"); figures now exist for all three sets (text 26,592 B / 2,760 B, ecc 17,932 B / 760 B, session 18,196 B / 1,776 B) | batch_01 #2, batch_02 #5 |
| D5 | the C++ core matches a `when` whose source sits in a false `when` | out-of-scope | the C++ package, not this epic ("C++ fix outside the epic"); still no ticket | handoff53 |
| S5 | frame mode, 4-byte tag, replay window, epoch keys | out-of-scope | spec `### Excluded` line of AZ-2756: "Frame mode, the 4-byte tag, the replay window and epoch keys (meshbell PB-04)" | intake |

### Gaps that need a decision (gap-unclear)

None.
