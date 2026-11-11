# Batch 5 report — loop 99 (Dart package)

Task: AZ-4144 dart_parity_rows (3).

27 TypeScript parity tables run in Dart (957 new tests in `dart/test/parity/`); `parity_differences.md` is complete (108 lines) and checked by `parity_doc_test.dart`: every row names a Dart test file that exists and a test name that occurs in it. The check order of unpack with error correction (no handler, duplicate type, parity mix, limit, then per packet: too long, uncorrectable, empty buffer, unknown type, body) matches TypeScript on every loop 40 row.

One bug found and fixed in `dart/lib/src/pack.dart` (419 lines): a `times` inside an anchored group under flags, count 1 and the group's map not given, packed `0101025a00` (the group bit clear, a count promising a round never written); TypeScript and Go refuse it (`missing pt`). A group not given is now still on when a member such as `times` is on by its own rule.

Whole Dart suite: 1,877 tests pass in 6.4 s wall (peak 1.24 GB resident, tests run in parallel isolates); `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues. CI-parity: PASS (suite commands). Review: one total review at the end of the loop.

## Discovered during implementation

| finding | handling | clear/unclear |
|---------|----------|---------------|
| `max_slots_test.dart` (the raised-limit packet) peaks near 815 MB resident (TypeScript 1,070 MB) | same packet and default as TypeScript's row | unclear: check the CI container memory on the first run |
| 11 new differences recorded (Go-1, Go-2, Go-4, A-3, error text, round naming, U6 split, empty handler list) | all in `parity_differences.md` with tests | clear |
| a flat key that names a member of a nested row is ignored (TypeScript refuses `missing a`; Dart, Go, Swift ignore) | row 17 | unclear: owner |
| tables not ported on their own (text, crypto, frame, ecc, hostile, limits, list/dict, scheme constructor and binding) | covered by earlier tasks or no Dart counterpart; listed with reasons | clear |
| row counts of four tables are constants in the registry | can drift if tests are added | unclear: low risk |
