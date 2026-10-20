# Feature assessment — loop 51

loop: 51
feature: rust-nostd-core (wave A: AZ-2752, AZ-2753)
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-20
**Implement pass**: batches 01..02, `batch_01_loop51_report.md`, `batch_02_loop51_report.md`, `implementation_completeness_loop51_report.md`
**Verdict**: COMPLETE — 9 covered / 2 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| R3 | untrusted bytes with flags, bits, rounds and lists | covered | AZ-2752 AC-3, AZ-2753 AC-4; `nostd_bits_when_tests::ac3_*`, `nostd_rounds_tests::ac4_*`; `rust/src/nostd/unpack.rs` | intake |
| R5 | scheme invalid at construction (when source, order, nesting, empty bodies) | covered | AZ-2752 AC-2, AZ-2753 AC-2; `ac2_*` in both test files; `rust/src/nostd/check.rs` | intake |
| R11 | default features: whole suite | covered | `run-suite.sh rust` 829 pass | intake |
| R12 | device image | covered | embedded stage PASS (13,844 B, 472 B) | intake |
| R13 | over the size limits | covered | the stage failed at 12,108 B against 8,192 B; owner raised the base limit to 16,384 B | intake, batch_01 #1 |
| B1-#2 | an empty top-level `when` | covered | accepted as std; round bodies of empty `when`s refused (`ac2_schemes_std_refuses_are_scheme_invalid`) | batch_01 #2 |
| B1-#4..6 | another number kind, flag byte sources, `boolean` | covered | batch 1 rows 4 to 6; differential tests | batch_01 |
| B2-#3,#4,#6 | list id, empty group, empty list element | covered | `ac2_tables_only_the_core_can_write_are_refused`, differential | batch_02 |
| D4 | round limit per container (std: per field per call) | covered | `ac2_rounds_at_the_limit_*`; `Scheme::max_rounds` doc | batch_02 #2 |
| D3 | dictionaries | out-of-scope | moved to AZ-2754 (spec scope line, AC-5) | batch_02 #1 |
| D5 | C++ `when` of a skipped source | out-of-scope | another package; leftover in the loop record | batch_01 #3 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None. D6 (a nested stack probe) is deferred to AZ-2757, already in `todo/`.

### Not walked

- Strings in any position (AZ-2754), ECC (AZ-2755), session (AZ-2756).
