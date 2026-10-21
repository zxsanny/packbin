# Feature assessment — loop 54

loop: 54
feature: csharp-repeat-cache-and-cpp-when
rounds: 2
verdict: COMPLETE
report_of_round: 2

## Round 1

**Date**: 2026-10-21
**Implement pass**: batches 01..02, `_docs/03_implementation/batch_01_loop54_report.md`, `batch_02_loop54_report.md`
**Verdict**: EXTEND — 12 covered / 1 out-of-scope / 1 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| C1 | one long text in 200 rounds of a `times` | covered | AC-C1; `RepeatedTextSpeed` (24 to 36 ms idle, 20 of 20 runs); `PackOut.EncodeText`, `Walker.Counted.cs` `PackUtf8` | intake |
| C2 | the text changes mid-run, alternates, or differs in the last character | covered | AC-C3; `RepeatedTextReuse.Ac3_*` (5 plans; mutant fails 5); `PackOut.EncodeText` | intake |
| C3 | two calls in a row, or two threads at once | covered | AC-C4; `RepeatedTextReuse.Ac4_*`, `CompactTextTests.Concurrency`; the cache lives in `PackOut`, one per call | intake |
| C4 | a text of 65,536 UTF-8 bytes | covered | AC-C5; `CompactTextTests.Limits.Ac5_*`; the length check runs before `EncodeText` in `PackUtf8` | intake |
| W1 | source in a clear `when`, row value differs | covered | AC-W1; `when_skipped_source_host_tests.cpp` `ac1_*`, corpus `pack_when_of_skipped_source` in 8 packages; `source_skipped`, `when_matches` | intake |
| W2 | same, value 0 | covered | AC-W2; `ac2_*` and `ac2_plain_*` (unpack of a plain source), corpus `..._zero`; `when_matches` | intake |
| W3 | source written | covered | AC-W3; `ac3_*`; same code path | intake |
| W4 | source two `when`s deep | covered | AC-W4; `ac4_nested_skip`; `source_skipped` chain | intake |
| W5 | one `when` holds both | covered | AC-W5; `ac5_one_when_holds_both`; `mark_held` stop rule | intake |
| W6 | the other seven packages | covered | AC-W6; corpus cases in Python, TypeScript, Java, C#, Rust (std and no-heap), Go, Swift; all give `0100` | intake |
| W7 | Cortex-M4F, AVR, no-text | covered | AC-W7; `cpp-embedded` stage EXIT 0: 7,952 B and 504 B | intake |
| W8 | no skipped source | covered | AC-W8; C++ suite on `gcc:16`, hostile corpus; step 11 repeats it with the ring | intake |
| W9 | closing row U24 | out-of-scope | AZ-2816 `### Excluded`: "Row U24 (the three `pack_novalue_count_clear_when_*` skips)" | intake |
| D2 | a `when` source more than 255 entries behind its holding `when` | gap-clear | quote: "`Field::bit` ... distance back to the nearest `when` that holds it" with `if (k - w > 255) { c.fail_at(id); }` in `order.hpp`, and loop 20 C3 "the 255-entry limit" → Given a `when` source 255 / 256 / 301 entries behind its `when`, When the scheme is checked, Then valid / refused / refused | batch_02 discoveries #2 |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| D2 | Given a `when` source 255 entries behind its holding `when`, When the scheme is checked, Then it builds; at 256 and 301 it is refused | "the 255-entry limit" (`held_count_nested_late_host_tests.cpp`, C3); `order.hpp` `mark_held` | new: AZ-2823 (1 point) |

### Not walked

- The repeated-text tests of the other seven packages were not timed against their CI bound in this loop (batch_01 discoveries #1). Past `main` and `dev` runs of those suites were green in every pair since loop 46 except the two C# failures; the speed numbers are not printed by passing tests. Candidate for the handoff, not a gap of this feature.
- A `when` source that is a bool or a group presence bit behind a clear `when` (the existing rule for those sources stays).

### Harness gaps

- none

## Round 2

**Date**: 2026-10-21
**Implement pass**: batch 03, `_docs/03_implementation/batch_03_loop54_report.md`
**Verdict**: COMPLETE — 13 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| D2 | a `when` source more than 255 entries behind its holding `when` | covered | AC-1 of AZ-2823 (AC-W9); `ac6_source_link_is_limited_to_255_entries` (valid at 255, refused at 256 and 301); `mark_held` in `order.hpp` | assess-round-1 |

Rows C1 to C4, W1 to W8 are unchanged from round 1; W9 stays out-of-scope.

### Not walked

- as in round 1.

### Harness gaps

- none
