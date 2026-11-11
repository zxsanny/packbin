# Test Specification — Dart package

Added in loop 99 (AZ-4133; tasks AZ-4134 to AZ-4148). The criteria are DT-1 to DT-20 of `_docs/02_task_plans/dart-package/acceptance_criteria.md`, which make Dart the ninth language for the project criteria AC-1 to AC-16 and for the contracts `compact-text.md`, `message-ecc.md` (1.1.0) and `pack-session.md` (3.0.0). Every test reads the shared fixtures as files; no fixture is copied into test code.

Run: `dart test -r expanded` in `dart/` (the whole suite runs in parallel isolates), or the CI form, `docker compose -f docker-compose.test.yml run --rm dart` (`run-suite.sh dart`: `pub get`, `dart format --set-exit-if-changed`, `dart analyze --fatal-infos`, `dart test -r expanded`, the 60 s seeded run, the compiled speed bounds, the dependency check).

## Criteria and tests

| ID | Criterion | Tests |
|----|-----------|-------|
| DT-1 | golden bytes `4001000065cd1d00a3e1110100`, five fields, no motion field | `test/core/golden_test.dart` (typed and map rows, heading 90 writes `5a 00`) |
| DT-2 | every README data-type example, short buffers at every cut, trailing bytes, no throw on input | `test/core/readme_scalars_test.dart`, `test/collections/readme_collections_test.dart`, `test/rounds/readme_rounds_test.dart`, `test/core/unpack_errors_test.dart` |
| DT-3 | TypeScript parity rows | `test/parity/` (27 TypeScript tables as `ParityRow`s, `parity_support.dart`); `parity_doc_test.dart` checks `parity_differences.md` against the tests |
| DT-4 | hostile vectors (`fixtures/hostile/cases.txt`, 75 cases: 15 unpack, 2 limit, 15 construct, 43 pack) | `test/hostile/hostile_test.dart`; `fixtures/hostile/check-cases.sh` and `cases.test.sh` count nine packages |
| DT-5 | default limits, lowered and raised limits, the byte budget, the seeded random unpack run | `test/limits/` (`limits_surface_test.dart`, `unpack_limits_test.dart`, `pack_limits_test.dart`, `slot_width_test.dart`, `seeded_run_test.dart`, which reads `PACKBIN_FUZZ_SECONDS`); `test/rounds/limits_test.dart` |
| DT-6 | frame mode: 157 rows of `fixtures/frame/vectors.txt`, the replay window, the previous key, `close()`, refusals as values | `test/frame/` (`frame_vectors_test.dart`, `frame_refusals_test.dart`, `frame_replay_close_test.dart`, `replay_window_test.dart`, `frame_compare_alias_test.dart`) |
| DT-7 | rings: language-pair hand-offs, the ECC ring, the frame ring, the position driver | `.github/workflows/ring-dart.sh`, `drivers/handoff-dart/`, `ring-wiring-dart.test.sh`; a real run with all nine languages in loop 99 |
| DT-8 | speed: 100,000 round trips and 1,000 frame unpacks in a compiled build | `dart/tool/speed.dart` (run by `run-suite.sh dart`); `test/core/speed_rows_test.dart` (the measured rows are right) |
| DT-9 | CI: format, analyze, test, the `dart` service, the `loop-tests.sh` stage | `run-suite-dart.sh`, `run-suite-dart.test.sh`, `docker-compose.test.yml`, `scripts/loop-tests.sh` |
| DT-10 | release: Dart in the golden gate, the pub.dev target, a dry run with 0 errors | `publish-dart.test.sh`, `publish-dart-package.test.sh`, the publish gate tests (AZ-4147, ADR-011) |
| DT-11 | 0 runtime dependencies, no `dart:mirrors`, `dart:ffi` or `dart:io` under `lib/` | `dart_deps` in `run-suite-dart.sh`; `test/core/purity_test.dart` |
| DT-12 | `null` is no value, an empty list is a value, nested-map groups | `test/core/no_value_test.dart`, `test/rounds/zero_and_short_test.dart`, `test/rounds/zero_rounds_places_test.dart`, `test/checks/group_rows_test.dart`, `test/collections/nested_scopes_test.dart`, `test/collections/empty_nested_test.dart` |
| DT-13 | the README Dart section and the pub.dev files | `test/readme/readme_examples_test.dart` (every ```` ```dart ```` block of `README.md` and `dart/README.md` is compiled, run and compared with its output block; a changed hex fails; `dart/example/packbin_example.dart` prints the golden hex), `test/readme/frame_readme_test.dart` (the frame example, compared with the README by `scripts/frame/readme-examples.sh`) |
| DT-14 | isolates: 4 isolates times 10,000 round trips on one scheme | `test/core/isolates_test.dart`, `test/collections/isolates_test.dart` |
| DT-15 | invalid Dart values: a pack error naming the field, no bytes | `test/core/invalid_values_test.dart`, `test/parity/value_rows_test.dart` |
| DT-16 | 64-bit integers: the six boundary values, `-1` as `ff` x 8, a count above 2^63 - 1 | `test/core/int64_test.dart`, `test/parity/count_rows_test.dart` |
| DT-17 | compact text: 418 rows of `fixtures/text/vectors.txt`, the emitted tables | `test/text/` (`text_vectors_test.dart`, `text_hostile_test.dart`); `scripts/text/check-emitted.sh` |
| DT-18 | error correction: `fixtures/ecc/vectors.txt` and `percent-vectors.txt`, repair, `uncorrectable`, `tooLong` | `test/ecc/` (`count_vectors_test.dart`, `percent_vectors_test.dart`, `scheme_vectors_test.dart`, `scheme_limits_test.dart`, `scheme_repair_test.dart`) |
| DT-19 | crypto: 27 rows of `fixtures/crypto/vectors.txt` | `test/crypto/` (`crypto_vectors_test.dart`, `crypto_edges_test.dart`, `crypto_guards_test.dart`) |
| DT-20 | the documents name nine | this specification, `architecture.md`, `module-layout.md`, `glossary.md`, the three contracts, `fixtures/*/README.md`; the README tests above |

Test areas without a DT row of their own: `test/checks/` (construction refusals, `eq` ranges, reference scope, typed groups, the hostile construct cases), `test/rounds/` and `test/collections/` (rounds, `bits`, `packed`, `list`, `dict`, `nested`, typed rounds and rows, count bounds before allocation), `test/support/` (hex, the position row, the repository root).

## Results

Loop 99 (before this task): 1,877 tests pass in about 6 s (peak 1.24 GB resident, the tests run in parallel isolates); `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues. Seeded run (10 s): 1.5 million unpack calls, 0 failures, slowest 8.3 ms. Compiled speed: 45 ms for 100,000 round trips (bound 1,000 ms), 0.37 ms for 1,000 frame unpacks (bound 10 ms). Rings on the Mac with all nine languages: the language-pair hand-offs pass; the ECC ring 81 pairs, 66,825 rows, 0 mismatched; the frame ring 81 pairs, 0 mismatched. The container suite on `dart:3.13.7` passed its 7 steps in batch 2 (the host run counted 459 tests then).

## Known limits

- Only Dart 3.13.7 (the CI image) and the local Dart 3.13.5 have run the suite; a claim about another version is not made.
- The web (Dart compiled to JavaScript) is not supported and not tested (D-4).
- `max_slots_test.dart` peaks near 815 MB resident; the CI container's memory limit is unchecked.
