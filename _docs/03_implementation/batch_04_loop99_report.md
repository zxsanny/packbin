# Batch 4 report — loop 99 (Dart package)

Tasks: AZ-4139 dart_limits (3), AZ-4143 dart_hostile_vectors (3), AZ-4146 dart_ring (5). 11 points.

| task | result | tests |
|------|--------|-------|
| AZ-4139 | done: `withLimits`, `maxRounds`/`maxSlots`/`maxBytes` on pack and unpack, the `maxBytes` refusal names the field, seeded run `dart/test/limits/seeded_run_test.dart` (10 s run: 1.5 million unpack calls, 0 failures, slowest 8.3 ms) | 97 new |
| AZ-4143 | done: all 75 hostile cases run at their stage (15 unpack, 2 limit, 15 construct, 43 pack), 0 not run; `check-cases.sh` and `cases.test.sh` count nine packages; 45 `Run by` lines gained Dart | 16 new |
| AZ-4146 | done: Dart driver, `ring-dart.sh`, Dart in the language-pair, ECC and frame rings; real run on the Mac with all nine languages: language-pair handoffs all pass, ECC ring 81 pairs 66,825 rows 0 mismatched, frame ring 81 pairs 0 mismatched, frame driver malformed lines 382 checks pass | wiring tests pass |

Whole Dart suite: 920 tests pass; `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues. `test.yml` stays at 20 jobs. CI-parity: PASS (suite commands; ring and wiring tests above). Review: one total review at the end of the loop.

Open before a push: `publish-position.sh dart` answers `absent dart` until `publish-lib.sh` `language_present` has a `dart` case (AZ-4147); the scaffold step "frame mode README examples" fails until AZ-4148 writes `dart/test/readme/frame_readme_test.dart`.

## Discovered during implementation

| spec ref | finding | handling | clear/unclear |
|----------|---------|----------|---------------|
| AZ-4139 | a real bug found by the seeded run: `Writer.byte` and `float64` wrote into the old buffer when they triggered growth (an `IndexError` out of `pack` at offsets 64, 128, ...) | fixed; 12 regression tests | clear |
| AZ-4139 | a nested row in a round now counts the width of its own members (README, Go, Swift) instead of 1 slot (Java) | parity row | unclear: owner |
| AZ-4139 | a limit of 0 or below is refused when set; no upper bound | copied from TypeScript | clear |
| AZ-4143 | `count_behind_clear_flag*` gave `short_packet`; a count with no value or a negative count is now `ErrorKind.badValue` (an item or round that reads no byte stays `short` with needed 0) | decided by the parent: the lines list `bad_value` first | clear |
| AZ-4143 | `check-cases.sh` checks `Run by` only for stage `pack` | left | unclear: could be extended |
| AZ-4146 | `publish-lib.sh` has no `dart` case | AZ-4147 adds it | unclear until then |
| AZ-4146 | the Dart driver build cache has little value (a restored stamp is older than the checkout) | read the first CI timing, drop it if useless | unclear |
| AZ-4146 | `fixtures/frame/README.md` and `fixtures/ecc/README.md` still say eight | AZ-4148 | clear |
