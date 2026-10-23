# Feature assessment — loop 63

loop: 63
feature: pack-flash-saving
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-23
**Implement pass**: batch 01, `_docs/03_implementation/batch_01_loop63_report.md`
**Verdict**: COMPLETE — 8 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A saving of at least 72 B is found: kept, pin lowered, part 2 runs | covered | AC-2, AC-5, AC-6; arm stage `cpp-m4f` PASS at 7,724 B (-84 B) with the pin at 7,724 B (`cpp/embedded/lib.sh`); part 2 figures for shapes A and D in the batch report; `pack_u2`, `bad` in `cpp/src/core/pack.cpp` | intake |
| S2 | A saving of 1 to 71 B: kept as a pure reduction, part 2 skipped | covered | AC-2; not triggered (the saving is 84 B); the rule is recorded in the spec and `problem.md` flagged concerns | intake |
| S3 | No saving in any shape tried: source stays at HEAD | covered | AC-2; not triggered; the shapes tried (11 variants) are listed in the batch report | intake |
| S4 | `held_of` ends above the part 1 figure: dropped | covered | AC-7; shapes D (+44 B) and A (+72 B) measured on the kept shape, both above 7,724 B; the owner chose "drop" in chat; source has no `held_of` | intake |
| S5 | A saving grows a stack figure | covered | AC-3; `put_le` shapes grew the flag chain 440 B to 456 B and were rejected; the kept shape measures 404 / 440 / 492 B and the deepest 496 B, as at HEAD (arm stage log) | intake |
| S6 | A refused value or a full buffer: same `Error`, offset, field id | covered | AC-4; `tests/core/counted_tests.cpp` `two_bit_values` (new cases: second child 4, fourth child 7, buffer of 1 byte), HEAD vs new differential over 12 buffer and value cases identical; hostile and dict-order host tests unchanged and green; `pack_u2`, `bad` | intake |
| S7 | GCC 16 `-Werror` or avr-gcc 7.3 rejects a construct | covered | AC-9; `gcc:16 make test` pass; arm stage `cpp-avr-uno` PASS and 0 compile warnings on M0+, M3, M4F | intake |
| S8 | The other seven packages read bytes the C++ pack wrote | covered | AC-4; wire output unchanged (M3 and s390x 287 of 287 vectors equal, all-kinds packet equal across targets); the shared corpus and ring run at step 11 | intake |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- Stack on an error path through the out-of-line `bad`: the stage measures success paths only. Bound by arithmetic: `bad` has an 8 B frame (`core-pack.su`) plus a return address, and the deepest pack stack is 480 B net (raw 544 B less 64 B meter overhead), so an error at the deepest point is about 492 B, under 512 B. Not a measurement.
- An output buffer holding bytes past `w.len` after a refused `u2`: `pack_small` already wrote past `w.len` before a refusal, so the contract is that only `[0, offset)` is defined.
