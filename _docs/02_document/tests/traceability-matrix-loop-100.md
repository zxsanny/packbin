# Traceability matrix — loop 100 (Dart aligned with TypeScript, AZ-4153)

The criteria are AL-1 to AL-10 of `_docs/02_task_plans/dart-typescript-alignment/acceptance_criteria.md`; they amend DT-3, DT-4, DT-12, DT-17 and DT-18 of loop 99. Each value in them was read by running TypeScript (`node`) and Dart on HEAD 0a678be; the observed packets are in `input_data/expected_results/results_report.md` next to them. Tests are under `dart/`.

| AL | Amends | Task AC | Tests | Status |
|----|--------|---------|-------|--------|
| AL-1 | DT-17 | AZ-4153 AC-1 | `test/collections/lone_surrogate_test.dart` (12 text and 4 key packets, all equal to TypeScript's), `test/text/text_hostile_test.dart` | Covered |
| AL-2 | DT-17 | AC-1 | `lone_surrogate_test.dart` (3 key orders after the swap, a round trip of every dictionary packed) | Covered |
| AL-3 | DT-3 | AC-2 | `lone_surrogate_test.dart` `two keys that are the same once the halves are U+FFFD are refused` | Covered (TypeScript refuses the same way since loop 101, AZ-4168: `typescript/tests/dict-colliding-keys.test.ts`) |
| AL-4 | DT-18 | AC-3 | `test/ecc/pack_too_long_test.dart` (3 counts, 4 percentages, at and one over, `maxBytes` first, unpack `too_long`), `count_vectors_test.dart`, `percent_vectors_test.dart`, `scheme_vectors_test.dart` | Covered |
| AL-5 | DT-3, DT-4 | AC-4 | `test/collections/dict_order_test.dart`, `hostile_collections_test.dart`, `test/hostile/hostile_test.dart` | Covered |
| AL-6 | DT-12 | AC-6 | `test/rounds/zero_rounds_places_test.dart` (15 places, repack), `zero_and_short_test.dart`, `typed_rounds_test.dart` | Covered |
| AL-7 | DT-3 | AC-7 | `test/collections/empty_nested_test.dart` (flags, a flag bit, the typed mark) | Covered |
| AL-8 | DT-3 | AC-8 | `empty_nested_test.dart` (5 refused places, a bound empty nested, an empty `nestedRow`), `construction_test.dart` | Covered |
| AL-9 | DT-4, DT-17 | AC-5 | `test/collections/text_refusal_short_test.dart` (29 fixture rows as a field and a key, 5 hand-made packets, the cut buffer), `hostile_test.dart` (7 rule texts) | Covered |
| AL-10 | DT-9 | AC-9 | `dart test` 2,001 of 2,001; `scripts/loop-tests.sh` stages typescript, csharp, python, java, rust, go, cpp, dart, swift, scaffold, ring and publish-gate passed; `dart format` and `dart analyze --fatal-infos` clean | Covered |

The security pass added a hostile-bytes run over every touched scheme shape (`_docs/05_security/security_report_loop100.md`).
