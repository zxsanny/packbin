# Batch 2 report — loop 99 (Dart package)

Tasks: AZ-4135 dart_scheme_checks (5), AZ-4136 dart_rounds (5), AZ-4145 dart_ci_suite (3). 13 points.

| task | result | tests |
|------|--------|-------|
| AZ-4135 | done: duplicate names, `eq` ranges, references, anchored group `groupOf`, nested-map groups (Go-4), 7 of 15 hostile construct cases | 198 new |
| AZ-4136 | done: `repeat`, `times`, `sized`, `u2`/`slot`, `bits`, `packed`, typed and map rounds, default limits enforced, 7 more hostile construct cases | 147 new |
| AZ-4145 | done: `dart` compose service on `dart:3.13.7`, `run-suite-dart.sh`, self-tests, pin, `loop-tests.sh` stage, `test.yml` job count 20 | container run exit 0 (7 steps), host run 459 tests |

Whole Dart suite: 606 tests pass; `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues. CI-parity: PASS (format, analyze, test as the suite runs them; the container run passed at 459 tests). Review: one total review at the end of the loop.

## Discovered during implementation

| spec ref | finding | handling | clear/unclear |
|----------|---------|----------|---------------|
| AZ-4135 | `group` clashes with `package:test`; anchored group is `groupOf` | README spelling line | unclear: name |
| AZ-4135 | `eq(u64, -1)` builds as the 64-bit pattern; `eq` with 5.0 or BigInt refused | `parity_differences.md` | unclear: owner |
| AZ-4135 | typed anchored group binds its members to the row around it | design choice | unclear |
| AZ-4136 | zero rounds unpack to empty lists; TypeScript leaves the key out | `parity_differences.md` | unclear: owner |
| AZ-4136 | `bits`/`packed` unpack as `Uint8List` | compact | unclear: AZ-4144 |
| AZ-4136 | `maxBytes` refusal names no field | AZ-4139 | unclear |
| AZ-4145 | edited `publish-jobs-layout.py` (3 lines) and `publish-pins.test.sh` (1 word), outside its list | accepted by the parent; AZ-4147 keeps them | clear |
| AZ-4145 | seeded run reads `PACKBIN_FUZZ_SECONDS` | AZ-4139 must use that name | clear |
| AZ-4145 | `loop-tests.test.sh` "dart source" row expects only `dart` | AZ-4146 changes it to `dart ring` | clear |
