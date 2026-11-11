# Feature assessment — loop 101

loop: 101
feature: typescript-colliding-dict-keys
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-11-11
**Implement pass**: batch 01 (`_docs/03_implementation/batch_01_loop101_report.md`), commit d8dcf0b
**Verdict**: COMPLETE — 6 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A dictionary whose keys differ only in unpaired surrogates is packed | covered | AC-1 (TC-1); `typescript/tests/dict-colliding-keys.test.ts` (4 collisions, message equal to Dart's); `typescript/src/pack-fields.ts` `dict` case | intake |
| S2 | A dictionary with no collision, a lone half, or keys that need the swap to sort | covered | AC-2 (TC-2); the same test file (4 packets equal to the bytes of before and of Dart), the existing 3,634 tests | intake |
| S3 | The same dictionary is a list element | covered | AC-1; `dict-colliding-keys.test.ts` `refuses a colliding dictionary that is a list element`; one code path (`Object.keys` appears once in `typescript/src`) | intake |
| S4 | Another package writes the same unreadable packet | out-of-scope | spec `### Excluded` line: "The other six packages, the npm version, any release." | intake |
| D1 | The check runs after the sort so neighbours are adjacent | covered | AC-3 (TC-3); the 20,000-dictionary property test, which fails against the old source (6 of 10 tests fail without the change) | batch_01 discoveries |
| D2 | Never unreadable: every returned packet unpacks | covered | AC-3; `dict-colliding-keys.test.ts` property test | batch_01 discoveries |
| D3 | Dart and TypeScript agree | covered | AC-4 (TC-4); the 7 report cases and a differential run of 5,000 seeded dictionaries (5,000 same, 280 refused, 0 different; scratchpad `diff101/`) | assess-round-1 |

### Gaps that need a decision (gap-unclear)

None. (The other six packages are recorded as a leftover because they were not measured; the spec excludes them.)

### Gaps that are clear (gap-clear)

None.

### Not walked

- none

### Harness gaps

- The Dart-against-TypeScript differential run is a scratchpad program (`gen.ts`, `diff.dart`), not committed; both packages commit the same 7 packets and the same message, which keeps them in step.
