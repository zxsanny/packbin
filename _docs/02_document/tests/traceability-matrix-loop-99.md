# Traceability matrix — loop 99 (Dart package, AZ-4133)

Dart is the ninth language. The criteria are DT-1 to DT-20 of `_docs/02_task_plans/dart-package/acceptance_criteria.md` (they restate the project criteria AC-1 to AC-16 and the contracts for Dart); each row names the Dart test files, listed in full in `components/09_dart_package/tests.md`. Status comes from the batch reports `_docs/03_implementation/batch_01_loop99_report.md` to `batch_05_loop99_report.md` and from the AZ-4148 run.

| DT | Project AC or contract | Task | Tests | Status |
|----|------------------------|------|-------|--------|
| DT-1 | AC-1, AC-2, AC-3 | AZ-4134 | `dart/test/core/golden_test.dart` | Covered |
| DT-2 | AC-4 to AC-9 | AZ-4134, AZ-4136, AZ-4138 | `test/core/readme_scalars_test.dart`, `test/collections/readme_collections_test.dart`, `test/rounds/readme_rounds_test.dart`, `test/core/unpack_errors_test.dart` | Covered |
| DT-3 | TypeScript parity | AZ-4144 | `test/parity/` (27 tables), `parity_doc_test.dart` | Covered |
| DT-4 | hostile vectors | AZ-4143 | `test/hostile/hostile_test.dart`; `fixtures/hostile/check-cases.sh` | Covered (75 cases) |
| DT-5 | limits, seeded run | AZ-4139 | `test/limits/` | Covered (the 60 s run is a CI step; a 10 s run passed locally) |
| DT-6 | `pack-session.md` 3.0.0 | AZ-4142 | `test/frame/` | Covered (157 of 157 rows) |
| DT-7 | rings | AZ-4146 | `ring-dart.sh`, `drivers/handoff-dart/`, `ring-wiring-dart.test.sh` | Covered on the Mac with all nine languages; the first CI run (dev and main, 2026-11-11, commit ada1e00) passed |
| DT-8 | AC-10 | AZ-4134 | `dart/tool/speed.dart`, `test/core/speed_rows_test.dart` | Covered (compiled build: 45 ms for 100,000 round trips) |
| DT-9 | AC-11 | AZ-4145 | `run-suite-dart.sh`, `run-suite-dart.test.sh` | Covered in the container; the first CI run (dev and main, 2026-11-11, commit ada1e00) passed |
| DT-10 | AC-12, AC-14, AC-15, AC-16 | AZ-4147 | `publish-dart.test.sh`, `publish-dart-package.test.sh`, the publish gate tests | Owned by AZ-4147 (ADR-011); the real publish is an owner step |
| DT-11 | purity | AZ-4134, AZ-4145 | `dart_deps` in `run-suite-dart.sh`, `test/core/purity_test.dart` | Covered |
| DT-12 | no value | AZ-4138 | `test/core/no_value_test.dart`, `test/rounds/zero_and_short_test.dart`, `test/checks/group_rows_test.dart` | Covered |
| DT-13 | README | AZ-4148 | `test/readme/readme_examples_test.dart`, `test/readme/frame_readme_test.dart`, `scripts/frame/readme-examples.sh` | Covered |
| DT-14 | isolates | AZ-4134 | `test/core/isolates_test.dart`, `test/collections/isolates_test.dart` | Covered |
| DT-15 | invalid values | AZ-4134 | `test/core/invalid_values_test.dart`, `test/parity/value_rows_test.dart` | Covered |
| DT-16 | 64-bit integers | AZ-4134 | `test/core/int64_test.dart`, `test/parity/count_rows_test.dart` | Covered |
| DT-17 | `compact-text.md` | AZ-4137 | `test/text/`; `scripts/text/check-emitted.sh` | Covered (418 rows) |
| DT-18 | `message-ecc.md` 1.1.0 | AZ-4140 | `test/ecc/` | Covered |
| DT-19 | crypto vectors | AZ-4141 | `test/crypto/` | Covered (27 of 27 rows) |
| DT-20 | docs name nine | AZ-4148 | the documents named in the task; `dart/test/readme/` for the README | Covered |

AC-3 (every language writes the golden bytes) now covers nine languages: Dart joins through DT-1 and DT-7, and the golden gate through DT-10.
