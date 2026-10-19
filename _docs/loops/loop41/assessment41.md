# Feature assessment — loop 41

loop: 41
feature: compact-text-ecc-security-audit
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-19
**Implement pass**: one batch (the audit's fixes F52 to F55 and the probes); no batch report (one total review and one step 11 run per loop, owner rule 2026-10-06). The evidence is the addendum in `_docs/05_security/security_report.md` ("Loop 41 addendum") and the four arm reports it consolidates.
**Verdict**: COMPLETE — 15 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | AC-1: reads past the payload, all eight text decoders | covered | AC-1; addendum summary and arm rows (ASan/UBSan C++, bounds-checked TypeScript copy, every 1-3 byte payload in C# and Java); decoders `*_text_decode*`, `TextDecoder.*`, `decode.rs`, `TextDecode.swift` | intake |
| S2 | AC-1: sizes from untrusted numbers (count up to 2,097,151) | covered | AC-1; count checked before sizing in all eight (addendum); F54 test `test_a_raw_payload_of_the_largest_count_is_refused_without_a_copy`; `python/src/packbin/_text_decode.py` | intake |
| S3 | AC-1: UTF-8 checks on the escape and raw paths | covered | AC-1; `bad.esc_utf8_*`, `bad.raw_*` vectors plus each arm's edge rows | intake |
| S4 | AC-1: the 65,535-byte limit | covered | AC-1; the same boundaries in all eight (addendum); F54 test `test_a_raw_payload_above_65535_bytes_is_refused_for_its_length_before_its_utf8` | intake |
| S5 | AC-1: expansion 6N + 8 | covered | AC-1; worst 5.333 per payload byte in every arm; F60 (Rust capacity) recorded | intake |
| S6 | AC-1: C++ `Packed` (HD-5) | covered | AC-1; count bounded on unpack and pack, every accepted `Packed` inside the input (Swift + C++ arm) | intake |
| S7 | AC-1: dictionary keys | covered | AC-1; repeated keys refused in all eight bound dicts; F51 (cost) and F56 (unbound C++) recorded with the owner's decision | intake |
| S8 | AC-2: lengths and the 254-byte limit | covered | AC-2; refused before arithmetic in all eight (addendum) | intake |
| S9 | AC-2: syndrome and repair work on hostile bytes | covered | AC-2; exhaustive n x N sweeps, worst-case timings table; F55 contract bound restated | intake |
| S10 | AC-2: Uncorrectable results | covered | AC-2; no buffer of t + 1 to n - t wrong bytes accepted in any arm | intake |
| S11 | AC-2: dispatch on untrusted type numbers | covered | AC-2; no table indexed by the type byte; F52 fix, tests `a_hand_written_handler_above_32_parity_bytes_is_refused_without_reading`, `a_session_handler_above_32_parity_bytes_is_refused_before_the_receive_index_advances`; `rust/src/ecc.rs` | intake |
| S12 | Unit-test row: every High or Critical finding fixed | covered | 0 Critical; 0 High after the owner's rating of F51 (Medium, 2026-10-19) | intake |
| S13 | Session receive index under refused payloads | covered | about 3 M session payloads per arm set, 0 desyncs; F53 fix, test `SessionPack_WithoutParity_TakesAClearMessageAbove254Bytes`; `csharp/Ecc.cs` | assess-round-1 |
| S14 | Probes kept for the next decoder change (AGENT_GOTCHAS line 1) | covered | `fixtures/hostile/fuzz/<language>/`, README table | assess-round-1 |
| S15 | Docs that quote the old work bound | covered | contract, README, 8 component descriptions, `csharp/EccRepair.cs` comment updated | assess-round-1 |
| S16 | The session cipher and the publish path | out-of-scope | spec `### Excluded`: "The session cipher, publish path." | intake |
| S17 | A linear dict-key check (F51, F56) and the open Lows F57 to F60, F19 instances | out-of-scope | owner 2026-10-19: next loop, AZ-2713 in `todo/` | assess-round-1 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None.

### Not walked

- none

### Harness gaps

- No batch report and no `## Discovered during implementation` table this loop (owner rule of one total review and one test run per loop); the arm reports in the scratchpad were consolidated into the addendum instead.
- `scenarios.md` absent (the spec predates step 4.7).
