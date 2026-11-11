# Feature assessment — loop 99

loop: 99
feature: dart-package
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-11-11
**Implement pass**: batches 01..07 (`_docs/03_implementation/batch_01_loop99_report.md` to `batch_07_loop99_report.md`); no `implementation_report_dart-package_loop99.md`, no completeness report and no review report exist yet (owner rule: one total review at the end of the loop).
**Verdict**: CLARIFY — 30 covered / 1 out-of-scope / 2 gap-clear / 23 gap-unclear

Read-only checks run for this round (nothing written to the repo except this file and `scenarios.md`): `dart compile exe tool/speed.dart` then run (round trips 100,000 in 47.93 ms, bound 1,000 ms; 1,000 frame unpacks in 0.362 ms, bound 10 ms; PASS); `dart analyze --fatal-infos` (no issues); `dart format --output=none --set-exit-if-changed .` (149 files, 0 changed); `dart test` on `test/readme/readme_examples_test.dart` (9 pass), `test/core/purity_test.dart` (2 pass), `test/core/int64_test.dart` (8 pass); `dart pub publish --dry-run` on a scratch copy of the package files (0 warnings); `fixtures/hostile/check-cases.sh` (75 cases ok); `scripts/text/check-emitted.sh` (9 of 9, dart ok); `test.yml` job count by matrix expansion (20). The whole suite, Docker and the rings were not run.

### DT verification (each criterion: quoted AC, test, production path)

| DT | quoted AC | test | production code | result |
|----|-----------|------|-----------------|--------|
| DT-1 | "packs the AC-1 row to `4001000065cd1d00a3e1110100`" | `dart/test/core/golden_test.dart` (typed, map, heading 90) | `dart/lib/src/pack.dart`, `unpack.dart`, `scheme.dart` | covered |
| DT-2 | "Exceptions thrown by unpack on any input: 0" | `test/core/readme_scalars_test.dart`, `unpack_errors_test.dart`, `dispatch_test.dart`, `limits/seeded_run_test.dart` | `unpack.dart`, `errors.dart` (`Unpacked.error`) | covered |
| DT-3 | "Refusal-vs-bytes disagreements not listed in `parity_differences.md`: 0" | `test/parity/*` (27 tables, 957 tests), `parity_doc_test.dart` (every row names an existing Dart test) | `pack.dart`, `checks.dart`, `rounds_*.dart` | covered; "Every refusal names the field id": list/dict element errors have `field: null` (see D16) |
| DT-4 | "All cases in `fixtures/hostile/cases.txt` (75 today) give an allowed outcome" | `test/hostile/hostile_test.dart` (a line not run, or a handler with no case, fails); `check-cases.sh` printed "hostile cases ok: 75" | `unpack.dart`, `limits.dart`, `build.dart`, `pack.dart` | covered |
| DT-5 | "seeded random unpack run ... runs >= 60 seconds in CI with 0 uncaught exceptions" | `test/limits/seeded_run_test.dart` (10 s run in the batch: 1.5 million calls, 0 failures, slowest 8.3 ms); `run-suite-dart.sh` `dart_seeded` fails a run shorter than 60 s | `limits.dart`, `item_size.dart`, `rounds_unpack.dart` | covered (the 60 s CI run has not happened yet) |
| DT-6 | "All 157 rows of `fixtures/frame/vectors.txt` ... pass in Dart" | `test/frame/frame_vectors_test.dart` ("157 of 157"), `frame_replay_close_test.dart` (zeroed keys after close), `frame_compare_alias_test.dart` ("reads all n bytes of a tag wrong in byte 0 or last") | `lib/src/frame/*`, exports in `lib/packbin.dart` (`FrameSession`, `FrameConfig`, `FrameDirection(s)`, `FrameSlot`, `FrameOpened`, `MsgContext`, `Freshness`, `MacKey`; `ReplayWindow` is in `frame/replay_window.dart`) | covered; a 7th refusal kind `short_packet` was added (D2) |
| DT-7 | "Dart joins that kind's existing ring in both directions with every member" | `language-pair.sh` (Dart loop for the 10 kinds, `-short` kinds), `ring-wiring-dart.test.sh`, `ring-ecc.test.sh` (81 pairs, dart-writer-lies, dart-reader-lies), `ring-frame.test.sh` (81 pairs, two Dart liars) | `.github/workflows/ring-dart.sh`, `drivers/handoff-dart/bin/{handoff_dart,position}.dart`, `publish-position.sh dart` | covered (batch 4 ran the real nine-language rings on the Mac; the CI ring has not run) |
| DT-8 | "100,000 pack-then-unpack round trips ... <= 1 second ... in a compiled build"; "1,000 unpacks of a 40-byte target frame take <= 10 ms" | `test/core/speed_rows_test.dart` (rows are right); `dart/tool/speed.dart` run by `run-suite-dart.sh` `dart_speed` (compile exe, exit 1 over a bound) | `pack.dart`, `unpack.dart`, `writer.dart` | covered: measured here 47.93 ms and 0.362 ms; the CI number is not measured yet |
| DT-9 | "`test.yml` still makes <= 20 jobs" | `test.yml` expanded: 14 job keys, `suites` has 7 entries (`lang: go dart` shares a job), total 20; `docker-compose.test.yml` service `dart` on `dart:3.13.7`; `scripts/loop-tests.sh` stage `dart` with `loop-tests.test.sh` rows ("dart test", "dart manifest", "dart source" = `dart ring`, "dart suite steps") | `run-suite.sh` case `dart`, `run-suite-dart.sh` (format, analyze `--fatal-infos`, test, seeded, speed, deps) | covered. Harness note: batch 7 says "14 jobs"; that counts job keys, the matrix makes 20 (the limit) |
| DT-10 | "a tag whose Dart golden check fails publishes 0 packages of any language"; "`dart pub publish --dry-run` ... 0 errors and 0 warnings" | `publish-dart.test.sh` AC-1 (`golden mismatch in: dart`, "publishing 0 packages"), AC-3 (already published), AC-4 (no `dart/pubspec.yaml` skips), AC-5, AC-6; `publish-dart-package.test.sh` (version from tag, dry run, consumer prints golden hex); `dart/LICENSE` equals root `LICENSE` (diff clean); my dry run on a scratch copy: "Package has 0 warnings" | `publish-gate.sh`, `publish-lib.sh` (`PACKBIN_LANGS` has dart; `pubdev dart required`), `publish-pubdev.sh`, `publish-dart-prepare.sh`, `publish-check.py` | covered; the warnings rule is only enforced with `PACKBIN_DART_STRICT=1` (D12) |
| DT-11 | "0 runtime dependencies ... Imports of `dart:mirrors`, `dart:ffi` and `dart:io` under `dart/lib/`: 0. The SDK constraint is `^3.13.0`" | `test/core/purity_test.dart` (pass); `run-suite-dart.sh` `dart_deps`; `pubspec.yaml` has `environment: sdk: ^3.13.0`, dev deps `lints`, `test` only; grep of `lib/` found no such import | `dart/lib/**` | covered |
| DT-12 | "`null` is no value ...; an empty list is a value with 0 items (count 0 written)" | `test/core/no_value_test.dart`, `test/checks/group_rows_test.dart`, `test/rounds/zero_and_short_test.dart` | `pack.dart`, `rounds_pack.dart`, `group_rows.dart` | covered |
| DT-13 | "Every Dart example in the README is compiled and run in CI and prints the README hex" | `test/readme/readme_examples_test.dart` (9 pass here, with negative tests for a changed hex, a missing output block, a block that does not compile), `frame_readme_test.dart`; `scripts/frame/readme-examples.sh` 9 of 9 (batch 6); `dart/README.md`, `dart/CHANGELOG.md`, `dart/example/packbin_example.dart` exist | `dart/example/packbin_example.dart` | covered; "install from pub.dev" reads "once the first version is published" (D11) |
| DT-14 | "4 isolates x 10,000 round trips on one scheme (sent to isolates spawned with `Isolate.run`)" | `test/core/isolates_test.dart` (4 x 10,000, wrong = [0,0,0,0]); `test/collections/isolates_test.dart` (map and typed, 4 x 2,000) | `scheme.dart` (immutable), `pack.dart`, `unpack.dart` | covered |
| DT-15 | "gives a thrown pack error naming the field id, with no bytes returned" | `test/core/invalid_values_test.dart`, `test/parity/value_rows_test.dart`, `test/collections/element_errors_test.dart` | `pack.dart`, `writer.dart`, `errors.dart` (`PackbinException`) | covered; list/dict items name the list and the index (D16) |
| DT-16 | "Mismatched bytes over the 6 boundary values (0, 1, 2^63 - 1, 2^63, 2^64 - 2, 2^64 - 1): 0" | `test/core/int64_test.dart` (6 wire values, run here: 8 pass); `test/parity/count_rows_test.dart` (a count above 2^63 - 1 is refused) | `pack.dart`, `unpack.dart`, `item_size.dart`, `counted_unpack.dart` | covered |
| DT-17 | "Every row of `fixtures/text/vectors.txt` (`enc`, `alt`, `bad`, `ref`, `flip`)" (418 data rows: enc 346, alt 10, bad 32, ref 4, flip 26) | `test/text/text_vectors_test.dart` (the kinds in the file must equal the five; minimum counts), `text_hostile_test.dart`, `test/collections/ring_refs_test.dart` (the 4 `ref` rows through a scheme); `check-emitted.sh` printed "dart ok" | `lib/src/text/*` (`text_tables.dart` emitted by `scripts/text/emit_tables.py`) | covered |
| DT-18 | "Every row of `fixtures/ecc/vectors.txt` and `fixtures/ecc/percent-vectors.txt` passes in Dart" (1,328 + 1,032 data rows) | `test/ecc/count_vectors_test.dart`, `percent_vectors_test.dart`, `scheme_vectors_test.dart`, `scheme_limits_test.dart`, `scheme_repair_test.dart` | `lib/src/ecc/*`, `scheme.dart` (`withParity`, `withParityPercent`, `withParitySettings`, `unpackRepair`) | covered |
| DT-19 | "All 27 rows of `fixtures/crypto/vectors.txt` ... pass in Dart" | `test/crypto/crypto_vectors_test.dart`, `crypto_edges_test.dart`, `crypto_guards_test.dart` | `lib/src/crypto/*` | covered (edge rows are not in the shared file: D19) |
| DT-20 | "Places that still say "eight packages" where nine is meant: 0" | the listed documents name Dart (`architecture.md`, `module-layout.md` `### Component: dart` at line 233, `components/09_dart_package/`, `glossary.md` 7 mentions, the three contracts, `fixtures/*/README.md` (text says "all nine packages"), `_docs/04_deploy/packages.md`, ADR-011 and its index row) | n/a (documents) | covered for the listed documents; stale "eight" wording remains in places outside the list (G1) |

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | A Flutter app packs a row and a server unpacks it | covered | DT-1, DT-7; `test/core/golden_test.dart`, ring `language-pair.sh` dart both ways; `pack.dart`, `ring-dart.sh` | intake |
| S2 | The phone unpacks a hostile or truncated frame | covered | DT-2, DT-4; `test/core/unpack_errors_test.dart` (short at every cut), `test/hostile/hostile_test.dart`; `unpack.dart` returns `Unpacked.error` | intake |
| S3 | A first byte that names no scheme | covered | DT-2; `test/core/dispatch_test.dart`; `scheme.dart` `unpack` (`ErrorKind.unknownType`) | intake |
| S4 | One scheme used from several isolates | covered | DT-14; `test/core/isolates_test.dart`, `test/collections/isolates_test.dart`; immutable `Scheme` | intake |
| S5 | Pack fails halfway, or a getter returns a wrong type | covered | DT-15; `test/core/invalid_values_test.dart`; `pack.dart` throws before any bytes are returned | intake |
| S6 | Rows at the limits and one past | covered | DT-5, DT-16; `test/limits/pack_limits_test.dart`, `unpack_limits_test.dart`, `test/parity/count_rows_test.dart`, `max_slots_test.dart`; `limits.dart` | intake |
| S7 | A `u64` above 2^63 - 1 | covered | DT-16; `test/core/int64_test.dart` (6 values); `pack.dart`, `unpack.dart` | intake |
| S8 | Same values as typed row and as map | covered | DT-12; `test/core/no_value_test.dart`, `test/checks/group_rows_test.dart`, `test/collections/typed_rows_test.dart`; `group_rows.dart` | intake |
| S9 | A message with parity arrives with flipped bytes | covered | DT-18; `test/ecc/scheme_repair_test.dart`, `scheme_vectors_test.dart`; `lib/src/ecc/codec.dart`, `scheme.dart` | intake |
| S10 | A sealed frame is replayed or arrives after `close()` | covered | DT-6; `test/frame/frame_replay_close_test.dart`, `replay_window_test.dart`; `frame/frame_session.dart`, `replay_window.dart` | intake |
| S11 | A new app adds `packbin: ^X.Y.Z` | covered | DT-10, DT-11; `publish-dart-package.test.sh` (path-dependency consumer prints the golden hex), dry run 0 warnings; `pubspec.yaml` has no runtime dependency (resolve from pub.dev itself is the owner's first publish: D11) | intake |
| S12 | Release run with a failing Dart golden check, or a version pub.dev already has | covered | DT-10; `publish-dart.test.sh` AC-1 and AC-3; `publish-gate.sh`, `publish-query.sh`, `publish-pubdev.sh` | intake |
| S13 | Compiled for the web | out-of-scope | `scenarios.md` row S13 and `problem.md` D-4: "Native targets only ... The web ... is not supported and not tested." | intake |
| D1 | Text with a lone surrogate | gap-unclear | question below | batch_01, batch_03 discoveries |
| D2 | Frame refusal term `short_packet` | gap-unclear | question below | batch_01 |
| D3 | Dart helper names (`flagBool`, `groupOf`, `utf8Field`, `nested`, `nestedRow`, `scheme` vs `rowScheme`, `bind<Row>`) | gap-unclear | question below | batch_01, 02, 03 |
| D4 | `eq(u64, -1)` builds as 2^64 - 1 | gap-unclear | question below | batch_02, AZ-4135 flagged concern |
| D5 | `eq` with a `BigInt` or `5.0` is refused | gap-unclear | question below | batch_01, 02 |
| D6 | Zero rounds unpack to empty lists (TypeScript: key missing) | gap-unclear | question below | batch_02 |
| D7 | Pack refusal kind `tooLong` for a message too long for its parity | gap-unclear | question below | batch_03 |
| D8 | `bad_value` for repeated dictionary keys and text refusals | gap-unclear | question below | batch_03 |
| D9 | `bits` and `packed` unpack as `Uint8List` | gap-unclear | question below | batch_02 |
| D10 | An empty `nested` is refused | gap-unclear | question below | batch_03 |
| D11 | `pubdev` required tier blocks the other eight languages until the first publish; README lines saying "once the first version is published" | gap-unclear | question below | batch_07, batch_06, AZ-4147 flagged concern |
| D12 | `PACKBIN_DART_STRICT` defaults to 0 | gap-unclear | question below | batch_07 |
| D13 | Dart driver build cache in the ring | gap-unclear | question below | batch_04 |
| D14 | pub.dev package polish: `.pubignore`, `public_member_api_docs` | gap-unclear | question below | batch_06, batch_07 |
| D15 | CI container memory for `max_slots_test.dart` | gap-unclear | question below | batch_05 |
| D16 | List/dict element errors carry no field id | gap-unclear | question below | batch_03 vs DT-3 |
| D17 | A flat key that names a member of a nested row is ignored (TypeScript refuses) | gap-unclear | question below | batch_05 |
| D18 | Text decode table of about 512 KB per isolate | gap-unclear | question below | batch_01 |
| D19 | No all-ones key, counter 2^32 - 1 or empty-HMAC rows in the shared crypto file | gap-unclear | question below | batch_01 |
| D20 | pub.dev OIDC token lifetime and the answer to a re-publish are unproven | gap-unclear | question below | batch_07 |
| D21 | Frame direction is an `int` extension type, not an enum | gap-unclear | question below | batch_01 |
| D22 | Typed-row design choices (map scheme ignores bindings; typed anchored group binds its members to the row around it; `bytes` takes only an exact-size `Uint8List`) | gap-unclear | question below | batch_01, 02 |
| D23 | `check-cases.sh` checks `Run by` lines only for stage `pack` | gap-unclear | question below | batch_04 |
| D24 | Stale "eight packages" wording outside the listed documents | gap-clear | quote: "Places that still say "eight packages" where nine is meant: 0." (DT-20, `acceptance_criteria.md`) -> see table below | batch_04, batch_06, assess-round-1 |
| D25 | `parity_differences.md` row 12 says a set group bit with no value unpacks as `{}`; a member-less `groupOf` mark unpacks as `true` | gap-clear | quote: "A flag bit with no payload. The bit is set only for `true`; ... unpack gives `true` only for a set bit." (`glossary.md` line 12) -> see table below | batch_06 |
| D26 | `Writer.byte` and `float64` wrote into the old buffer on growth (found by the seeded run) | covered | AZ-4139; `test/core/writer_growth_test.dart` (12 regression tests); `lib/src/writer.dart` | batch_04 |
| D27 | `dart:convert` drops a leading U+FEFF, so the package has its own strict UTF-8 reader | covered | AZ-4137; `test/text/text_hostile_test.dart`, `test/collections/utf8_field_test.dart`; `lib/src/text/text_decode.dart` | batch_01 |
| D28 | `ref` text rows run through the real scheme | covered | AZ-4138; `test/collections/ring_refs_test.dart`; `collections_unpack.dart` | batch_01, batch_03 |
| D29 | Frame counters and replay window use `BigInt` | covered | AZ-4142; `test/frame/replay_window_test.dart`; `frame/replay_window.dart` (the TypeScript bigint rule) | batch_01 |
| D30 | A count behind a clear flag or a negative count is `bad_value` | covered | AZ-4143; hostile cases `count_behind_clear_flag*` (they list `bad_value`), `test/hostile/hostile_test.dart`, `test/parity/count_rows_test.dart`; `counted_unpack.dart` | batch_04 |
| D31 | A limit of 0 or below is refused when set; no upper bound | covered | AZ-4139; `test/limits/limits_surface_test.dart`; `limits.dart` (as TypeScript) | batch_04 |
| D32 | A nested row in a round charges the width of its own members | covered | AZ-4139; `test/limits/slot_width_test.dart`; `round_shape.dart`; README Untrusted input rule (Java charges 1 slot: a pre-existing cross-package difference, recorded in `parity_differences.md`) | batch_04 |
| D33 | `needed` for a list count over the bytes left = count times the fewest bytes an item takes | covered | AZ-4138 AC-5; `test/collections/count_bounds_test.dart`; `item_size.dart` | batch_03 |
| D34 | `times` inside an anchored group under flags was packed with the group bit clear (fixed) | covered | AZ-4144; `test/parity/flags_times_member_test.dart`; `lib/src/pack.dart` | batch_05 |
| D35 | Shared CI files edited outside AZ-4145's list (`publish-jobs-layout.py`, `publish-pins.test.sh`) and a third compose file `docker-compose.publish-dart.yml` | covered | accepted by the parent; `publish-readonly.test.sh` checks the merged config; `publish-lib.sh` line 134 | batch_02, batch_07 |
| D36 | The seeded run reads `PACKBIN_FUZZ_SECONDS` | covered | AZ-4145/AZ-4139; `run-suite-dart.sh` `dart_seeded`, `test/limits/seeded_run_test.dart` | batch_02 |
| D37 | `loop-tests.test.sh` row "dart source" expects `dart ring` | covered | `scripts/loop-tests.test.sh` line 92, `loop-tests.sh` `covers` (ring covers `dart/lib/*`) | batch_02 |
| D38 | `unpackRepair` takes the repair limit; the `ErrorKind` list in `unpack_errors_test.dart` gained two terms | covered | AZ-4140; `test/ecc/scheme_repair_test.dart`, `test/core/unpack_errors_test.dart`; `scheme.dart` | batch_03 |
| D39 | Eleven new differences recorded; tables not ported listed with reasons | covered | AZ-4144; `test/parity/parity_doc_test.dart`; `_docs/02_task_plans/dart-package/parity_differences.md` (108 lines) | batch_05 |
| N1 | Dart `int` wraps silently: a size or count from input overflowing (flagged concern, High) | covered | `problem.md` flagged concern; `test/limits/seeded_run_test.dart`, `test/parity/count_rows_test.dart`, `test/hostile/hostile_test.dart`; `limits.dart`, `item_size.dart` | assess-round-1 |
| N2 | Keys are wiped on `close()` only, not at garbage collection (accepted-risk, Low) | covered | `problem.md` flagged concern; `test/frame/frame_replay_close_test.dart` (zeroed key buffers); `frame/frame_session.dart`, `mac_key.dart` | assess-round-1 |
| N3 | The committed version in `pubspec.yaml` is a placeholder; the release writes the tag's version | covered | A-7; `publish-dart-package.test.sh` ("pubspec version"); `publish-dart-prepare.sh` | assess-round-1 |
| N4 | A real CI first run of the Dart suite, rings and speed bound has not happened | covered (by design) | DT-8, DT-5 and DT-7 are wired (`run-suite-dart.sh`, `test.yml`) and were proven on the Mac; the CI timing is the step 11 job, not a missing scenario | assess-round-1 |

### Gaps that need a decision (gap-unclear)

#### D1: Text with a lone surrogate

**What is not decided**
A Dart string can hold half of an emoji (a lone surrogate) that is not valid text. TypeScript writes the replacement character U+FFFD for it and carries on; Go refuses. Dart refuses today (a thrown pack error naming the field), copying Go, because the spec line (AZ-4137 AC-3) assumed TypeScript refuses too.

**Options**
- **A - Refuse (today)**: a bad string is an error, as Go. Trade-off: the same text packs in TypeScript and not in Dart.
- **B - Write U+FFFD**: as TypeScript, one line in `text_encode.dart`. Trade-off: the damaged text is silently changed.

**Recommendation**: A - the rule "never change a value silently" is the package's habit; document the difference.

#### D2: Frame refusal term `short_packet`

**What is not decided**
The frame contract names a short-packet result, but DT-6 lists six refusal kinds without it. Dart added a seventh kind `FrameRefusalKind.shortPacket` with the wire term `short_packet`. Go uses the same term (`go/frame_names_test.go`); the contract spells it `ShortPacket`.

**Options**
- **A - Keep `short_packet`**: matches Go and the contract. Trade-off: DT-6's list of six kinds is out of date.
- **B - Rename or fold into `bad_value`**: six kinds as DT-6 says. Trade-off: loses the contract's separate result.

**Recommendation**: A - then add the seventh kind to DT-6 on the next criteria edit.

#### D3: Helper names that differ from the other eight

**What is not decided**
Dart cannot use some names: top-level `bool` and `utf8` clash with `dart:core` / `dart:convert`, `group` with `package:test`. Dart uses `flagBool`, `utf8Field`, `groupOf`, `nested` / `nestedRow` (the unanchored group), two scheme makers (`scheme` for map rows, `rowScheme` for typed rows) and a typed `bind<Row>`. They are in the README spelling lines and `parity_differences.md`.

**Options**
- **A - Keep (today)**: no clash for any Dart user.
- **B - Different names** (for example `boolFlag`, `utf8Text`): the owner picks before 0.1.0, because names cannot change after pub.dev takes the version.

**Recommendation**: A, but decide before the first publish; this is the last cheap moment.

#### D4: `eq(u64, -1)`

**What is not decided**
In TypeScript a `when` condition with a negative value on a `u64` is refused. In Dart -1 and 2^64 - 1 are the same 64 bits, so Dart builds it and the condition matches the all-ones value on the wire.

**Options**
- **A - Build it (today)**: Dart cannot tell the two apart. Trade-off: a typo `-1` is not caught.
- **B - Refuse every negative `eq` on a `u64`**: catches the typo. Trade-off: `eq(u64, 0xFFFFFFFFFFFFFFFF)` is the same `int` and is refused too, so the all-ones value cannot be written.

**Recommendation**: A - B refuses a legal value (AZ-4135 flagged concern, accepted-risk Low).

#### D5: `eq` with a `BigInt` or a whole `5.0`

**What is not decided**
TypeScript accepts `eq(u8, 5.0)` and `eq(u8, 5n)`. Dart refuses both (a `double` is not an `int`, as Go, Swift, Java, Python and Rust; a `BigInt` has no use in a 64-bit `int` field).

**Options**
- **A - Refuse (today)**: same as the rest of the Dart rules for `5.0` (owner decision Go-2).
- **B - Accept a whole `5.0` and a `BigInt` in range**: closer to TypeScript. Trade-off: two more spellings of one value.

**Recommendation**: A.

#### D6: Zero rounds unpack to empty lists

**What is not decided**
When a `repeat` or `times` has 0 rounds, TypeScript's unpacked map has no key for the names of the round; Dart gives an empty list for each name. DT-12 says an empty list is a value with 0 items, and it packs back to the same bytes.

**Options**
- **A - Empty lists (today)**: a Dart caller never tests for a missing key.
- **B - No key**: as TypeScript. Trade-off: `row['pt']!` fails on a valid packet.

**Recommendation**: A.

#### D7: Pack refusal kind `tooLong` for a message too long for its parity

**What is not decided**
A clear message above 254 minus the parity bytes cannot be protected. Dart throws a `PackbinException` of kind `tooLong`, the same kind unpack uses; Swift and Go throw their general pack error kind.

**Options**
- **A - `tooLong` (today)**: one kind to test on both sides, as AZ-4140 AC-5 names it.
- **B - `packError`**: as Swift and Go. One line to switch.

**Recommendation**: A.

#### D8: `bad_value` for repeated or unordered dictionary keys and for refused text

**What is not decided**
TypeScript, Go and Swift report these unpack failures as a short packet with `needed` 0. Dart reports `bad_value` naming the dictionary or field, with the reason in `reason`. The hostile README allows both.

**Options**
- **A - `bad_value` (today)**: a more exact kind.
- **B - short packet with `needed` 0**: identical to the other three. Trade-off: a caller cannot tell a damaged text from a cut packet.

**Recommendation**: A.

#### D9: `bits` and `packed` unpack as `Uint8List`

**What is not decided**
TypeScript gives a `number[]`; Dart gives one compact `Uint8List` of 0..3 per field (pack accepts any `List<int>`).

**Options**
- **A - `Uint8List` (today)**: less memory on a phone.
- **B - `List<int>`**: the same type that pack takes. Trade-off: one boxed `int` per item.

**Recommendation**: A.

#### D10: An empty `nested` row

**What is not decided**
TypeScript builds a `group` with no members; Swift makes a presence mark of it. Dart refuses an empty `nested` (a mark is the member-less `groupOf`).

**Options**
- **A - Refuse (today)**: one spelling for a mark.
- **B - Allow as a mark**: as Swift.

**Recommendation**: A.

#### D11: The first publish blocks the other eight languages

**What is not decided**
`pubdev` is a required target (ADR-011, cut 2 of the fit decisions). pub.dev only automates versions after the first one, so until the owner publishes the first Dart version by hand, a release run stops at the plan for all nine languages (the preflight reads 404). The README says "once the first version is published" and "from the repository until"; the owner edits those two lines after the first publish. The git install form works only after the push.

**Options**
- **A - Keep required (today)**: no tag can skip Dart by mistake. Trade-off: no release at all before the owner's first publish.
- **B - `optional` until the first publish**: the other eight can release; switch to required after. Trade-off: a Dart failure is then only a warning.

**Recommendation**: A if the owner publishes the first version before the next tag; otherwise B.

#### D12: `PACKBIN_DART_STRICT` defaults to 0

**What is not decided**
DT-10 wants the dry run to report 0 warnings. With the default 0 a warning (for example a missing CHANGELOG entry for the tagged version) does not stop the release; `PACKBIN_DART_STRICT=1` makes it fail but forces a CHANGELOG edit for every tag.

**Options**
- **A - Default 0 (today)**: the tag never fails on a note.
- **B - Default 1**: DT-10 holds on every tag. Trade-off: the CHANGELOG entry becomes part of releasing.

**Recommendation**: B once the CHANGELOG habit exists; the scratch dry run is clean today.

#### D13: Dart driver cache in the ring

**What is not decided**
`test.yml` caches the Dart driver build, but a restored stamp is older than the checkout, so the cache may save nothing.

**Options**
- **A - Keep until the first CI timing, then drop if useless**.
- **B - Drop now**: one step fewer.

**Recommendation**: A.

#### D14: pub.dev package polish

**What is not decided**
The published archive includes `test/` and `tool/` (161 to 195 KB; the dry run of the package files alone is 62 KB). A `.pubignore` would drop them. `public_member_api_docs` is not on (about 165 internal members would be flagged).

**Options**
- **A - Ship as is (today)**: consumers can read the tests.
- **B - Add `.pubignore` for `test/` and `tool/`** (and optionally enable the lint on the exported names only).

**Recommendation**: B - a smaller package for the phone build; no behavior change.

#### D15: CI container memory for `max_slots_test.dart`

**What is not decided**
The raised-limit packet test peaks near 815 MB (TypeScript 1,070 MB) on the Mac; the Dart suite shares a CI job with Go and has no memory limit set. Not known whether the CI container holds it.

**Options**
- **A - Look at the first CI run, then decide**.
- **B - Own job or a lower packet for Dart**: needs a spare job slot (20 of 20 today).

**Recommendation**: A.

#### D16: List and dictionary element errors carry no field id

**What is not decided**
DT-3 says "Every refusal names the field id". A list or dictionary has no id (README rule), so an error for an item has `field: null` and names the list plus index or key (`xs[2]: ...`, `m[b]: ...`).

**Options**
- **A - Keep, and amend DT-3 to say "names the field, or the list and the index"**.
- **B - Give the error the id of the member that holds the list's element**: needs an id the scheme does not have.

**Recommendation**: A.

#### D17: A flat key that names a member of a nested row

**What is not decided**
In a map row a flat key `a` while `a` is a member of a `nested` row is refused by TypeScript (`missing a`), ignored by Dart, Go and Swift (owner decision Go-4 refuses it only for an anchored group).

**Options**
- **A - Ignore (today)**: as Go and Swift.
- **B - Refuse, naming the member**: as TypeScript and the anchored group.

**Recommendation**: B - the anchored group already refuses, and a dropped value is silent.

#### D18: Text decode table of about 512 KB per isolate

**What is not decided**
The compact-text decoder keeps a 4 x 65,536 `Uint16` table (TypeScript's shape), built on first use in each isolate. Swift's tables are small.

**Options**
- **A - Keep**: fastest decode.
- **B - Swift-style small tables**: about 8 KB; a little slower decode.

**Recommendation**: A until the Archangel phone shows a memory problem; the speed numbers do not use text.

#### D19: Crypto edge rows are not in the shared file

**What is not decided**
`fixtures/crypto/vectors.txt` has no all-ones key, counter 2^32 - 1 or empty-HMAC row. Dart covers them with constants cross-checked against OpenSSL and Python (`test/crypto/crypto_edges_test.dart`). Adding rows to the shared file changes what the other eight assert.

**Options**
- **A - Keep in Dart only (today)**.
- **B - Add the rows to the shared file** and run them in all nine.

**Recommendation**: B in a later short loop; it hardens all nine.

#### D20: pub.dev token lifetime and re-publish are unproven

**What is not decided**
The OIDC token is made once before the uploads; its lifetime is not documented, and the Maven wait could outlive it (a guard fails the run 30 s before expiry with "run the tag again"). pub.dev's answer to a re-publish of an existing version, and whether it accepts this workflow's token, are unknown until the first real tag.

**Options**
- **A - Accept: learn at the first tag** (the version query before upload is the guard).
- **B - Create the token after the slow uploads**: reorders `publish.yml`.

**Recommendation**: A.

#### D21: Frame direction is an `int` extension type

**What is not decided**
Other packages use an enum; Dart's `FrameDirection` is an `int` extension type with constants, and an out-of-range value gives `bad_value` as TypeScript does.

**Options**
- **A - Keep (today)**: no allocation; same refusal as TypeScript.
- **B - A real enum**: cannot hold an invalid value at all.

**Recommendation**: A.

#### D22: Typed-row design choices

**What is not decided**
Three choices the spec did not name: a map scheme ignores bindings (Swift refuses a half-bound row); a typed anchored group binds its members to the row around it; `bytes` takes only an exact-size `Uint8List` (not a `List<int>`).

**Options**
- **A - Keep (today)**.
- **B - Adopt Swift's all-or-none binding rule and accept a `List<int>` for `bytes`**.

**Recommendation**: A for 0.1.0; B can follow without breaking a valid program.

#### D23: `check-cases.sh` checks `Run by` for stage `pack` only

**What is not decided**
The checker proves that every `pack` section names nine packages in its `Run by` / `Not run by` lines; sections of the other stages are not checked.

**Options**
- **A - Leave**.
- **B - Extend to all stages**: a small change in `check-cases.sh` and `cases.test.sh`.

**Recommendation**: B in the next hygiene loop.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| D24 | Given the nine packages exist, When `grep` runs over the package docstrings and the module layout for "eight packages", Then no line that means all packages says eight: `python/tests/test_compact_text.py:21`, `ecc_support.py:3`, `percent_support.py:3`, `text_vectors.py:1` ("shared by the eight packages") and `_docs/02_document/module-layout.md:349` ("the eight ECC drivers"; the ECC ring has nine drivers with `handoff-dart`) say nine. Historical loop entries ("Loop 26 ... eight") stay. | "Places that still say "eight packages" where nine is meant: 0." (`_docs/02_task_plans/dart-package/acceptance_criteria.md`, DT-20) | new short hygiene task (docs and docstrings only; Python test files are comments) |
| D25 | Given a map scheme has a member-less `groupOf` mark under `flags`, When the bit is set and unpacked, Then `parity_differences.md` row 12 says the mark unpacks as `true` (the code and the README already do; the row says `{}`). | "A flag bit with no payload. The bit is set only for `true`; `false` and a missing value leave it clear, and unpack gives `true` only for a set bit." (`_docs/02_document/glossary.md` line 12); test `dart/test/checks/group_rows_test.dart` "empty group mark set" expects `{'mark': true}` | same hygiene task (one table cell) |

### Not walked

- `dart/pubspec.lock` is ignored, so `test` and `lints` float inside their caret ranges between CI runs; the pinned image fixes the SDK only.
- The registry constants of four parity tables can drift if tests are added (`parity_doc_test.dart` checks the names, not the counts).
- A real Flutter AOT build and a background-isolate run of the package (DT-14 covers `Isolate.run` on the VM only).
- `vcpkg supports check` and `vcpkg consumer check` NOT RUN on this host (no vcpkg; they run in CI) - not a Dart item.
- `architecture.md` line 107 says the ring installs "the toolchains of the eight other suites"; Dart is compiled in its image, so the number may be right; check at the D24 task.

### Harness gaps

- No `implementation_report_dart-package_loop99.md`, `implementation_completeness_loop99_report.md`, `batch_*_loop99_review.md` or cumulative review exist (one total review is planned for the end of the loop), so Step 1 items 2 to 4 had no input beyond the batch reports and the specs' `## Flagged concerns` tables (only AZ-4147's pub.dev first publish is `open`, High; AZ-4135's `eq(u64, negative)` is `accepted-risk`).
- Batch 7 says `test.yml` "has 14 jobs"; the file has 14 job keys and 20 matrix instances. The 20-job limit holds with no room left.
- Batch 6's list of stale "eight" places (python docstrings, `fixtures/hostile/README.md:295`, four workflow lines, `_dependencies_table.md`) is only partly confirmed: the four python docstrings and `module-layout.md:349` are stale; `hostile/README.md:295` ("all seven packages pack `0100`") and `_dependencies_table.md` are historical; no stale workflow line was found (`publish-readonly.test.sh:392` "8 languages without java" is correct with nine).

## Round 1 resolution (owner, 2026-11-11: "accept all recommended")

Changed: D11 the `pubdev` target is optional until the first publish; D17 a flat key naming a member of a nested row is refused; D20 the pub.dev token is minted right before the upload; D14 `.pubignore` and `platforms:` added; D16 DT-3 amended for list and dict element errors. D24 and D25 (the two gap-clear rows) were fixed by the parent. Kept as built: D1 to D10, D12, D13, D15, D18, D19, D21, D22, D23. All three review slices and the security audit are folded in AZ-4149; the verdict is COMPLETE after round 1 (assess_round 1).

