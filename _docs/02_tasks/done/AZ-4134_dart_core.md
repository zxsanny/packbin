---
loop: 99
branch: dev
---

# Dart core: package, scalars, flags, `when`, errors, dispatch, typed and map rows

**Task**: AZ-4134_dart_core
**Name**: Dart core: package, scalars, flags, `when`, errors, dispatch, typed and map rows
**Description**: The `dart/` package and the pack/unpack walker for the scalar kinds, flags and `when`, with typed rows and map rows.
**Complexity**: 5 points
**Dependencies**: None
**Component**: dart
**Tracker**: AZ-4134
**Epic**: AZ-4133

## Problem

Dart and Flutter apps cannot pack or unpack packbin. The first slice gives them the package (`dart/pubspec.yaml`, library `packbin`, MIT) and the walker for the AC-1 position row and the scalar data types. Unpack returns a result with an error value and never throws on input; pack throws a typed error naming the field.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- Dart packs and unpacks the AC-1 row and the README integer, float, fixed-bytes, big-endian, bool, flags and `when` examples with 0 mismatched bytes.
- Rows are typed objects bound by getter and setter closures, or `Map<String, Object?>`; `null` is no value, a stored 0 is a value.
- Short, trailing and unknown-type buffers give an error value and no row; exceptions 0.
- A scheme is immutable and works from several isolates.

## Scope

### Included

- `dart/pubspec.yaml` (name `packbin`, placeholder version, SDK `^3.13.0`, 0 runtime dependencies, dev dependencies `test` and `lints`), `dart/analysis_options.yaml`, `dart/LICENSE` (equal to the root `LICENSE`), `dart/lib/packbin.dart` exporting the public names, sources under `dart/lib/src/`, tests under `dart/test/`. The `.gitignore` lines for `.dart_tool/` and `dart/pubspec.lock` policy (a library does not commit its lock file).
- The public API skeleton: scheme, fields by order id, `pack`, `unpack` with first-byte dispatch over a list of schemes and handlers.
- Kinds: u8 to u64, i8 to i64, f32, f64, fixed bytes, big-endian integers, bool (under flags or a flag-byte bit only), `flags`, flag-byte `bit`, `when` with `eq`.
- The error kinds, one per hostile outcome term (`short`, `trailing`, `unknown_type`, `bad_value`, `too_many`, `scheme_error`, `pack_error`); later tasks add kinds, they do not rename.
- The speed test and the isolate test.
- Owns (exclusive write): `dart/**` created here, `.gitignore` (Dart lines only).

### Excluded

- Construction checks beyond what the walker needs (AZ-4135)
- Rounds and counted kinds (AZ-4136)
- `utf8`, list, dict (AZ-4137, AZ-4138)
- Limits (AZ-4139)
- Error correction, crypto, frame mode (AZ-4140 to AZ-4142)
- The web target (owner decision D-4; scenario S13)

## Acceptance Criteria

**AC-1: Golden bytes (DT-1)**
Given the AC-1 row (type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear) as a typed row and as a map
When packed
Then the bytes are `4001000065cd1d00a3e1110100` (`fixtures/golden.hex`, read as a file); unpack gives the five fields and 0 motion fields

**AC-2: README scalar examples (DT-2)**
Given each README example for integers, floats, fixed bytes, big-endian, bool, flags and `when`
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-3: Short, trailing, unknown type (DT-2, S2, S3)**
Given a buffer that ends inside a field, one with 1 trailing byte, one whose first byte names no scheme, and an empty buffer
When unpacked
Then a result whose error names the field, needed and left (short), trailing, or the unknown type byte; no row; exceptions thrown 0

**AC-4: No value and zero (DT-12)**
Given a flags member whose getter returns `null`, a map with that key absent, a map whose key holds `null`, and the same member given as 0
When packed
Then the first three clear the bit and write no bytes for the member; the 0 sets the bit and writes the value

**AC-5: Invalid Dart values (DT-15, S5)**
Given a getter returning 300 for a u8, a `double` 5.0 or a `String` for an integer field in a map, a `bool` for a number, a missing required key, and a row whose third field is out of range
When packed
Then a thrown pack error naming the field id; bytes returned 0

**AC-6: Isolates (DT-14, S4)**
Given one built scheme
When 4 isolates started with `Isolate.run` each do 10,000 round trips of the AC-1 row
Then mismatches 0, errors 0

**AC-7: 64-bit integers (DT-16, S7)**
Given a u64 field and the values 0, 1, 2^63 - 1, 2^63, 2^64 - 2, 2^64 - 1 as wire bytes
When unpacked and packed back
Then `ffffffffffffffff` reads as -1; all six pack back to the same 8 bytes; an i64 keeps its sign

**AC-8: Speed (DT-8)**
Given the AC-1 fixture and a compiled build (`dart compile exe`)
When 100,000 pack-then-unpack round trips run on one core; 1,000 unpacks of a 40-byte frame run
Then ≤ 1 second for the first; ≤ 10 ms for the second on the Mac

**AC-9: Purity (DT-11)**
Given the files under `dart/lib/`
When searched for imports
Then `dart:mirrors`, `dart:ffi`, `dart:io`: 0; runtime dependencies in `pubspec.yaml`: 0

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Golden bytes: the AC-1 row (type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear) as a typed row and as a map | the bytes are `4001000065cd1d00a3e1110100` (`fixtures/golden.hex`, read as a file); unpack gives the five fields and 0 motion fields |
| AC-2 | README scalar examples: each README example for integers, floats, fixed bytes, big-endian, bool, flags and `when` | the README hex both ways; mismatched bytes 0 |
| AC-3 | Short, trailing, unknown type: a buffer that ends inside a field, one with 1 trailing byte, one whose first byte names no scheme, and an empty buffer | a result whose error names the field, needed and left (short), trailing, or the unknown type byte; no row; exceptions thrown 0 |
| AC-4 | No value and zero: a flags member whose getter returns `null`, a map with that key absent, a map whose key holds `null`, and the same member given as 0 | the first three clear the bit and write no bytes for the member; the 0 sets the bit and writes the value |
| AC-5 | Invalid Dart values: a getter returning 300 for a u8, a `double` 5.0 or a `String` for an integer field in a map, a `bool` for a number, a missing required key, and a row whose third field is out of range | a thrown pack error naming the field id; bytes returned 0 |
| AC-6 | Isolates: one built scheme | mismatches 0, errors 0 |
| AC-7 | 64-bit integers: a u64 field and the values 0, 1, 2^63 - 1, 2^63, 2^64 - 2, 2^64 - 1 as wire bytes | `ffffffffffffffff` reads as -1; all six pack back to the same 8 bytes; an i64 keeps its sign |
| AC-8 | Speed: the AC-1 fixture and a compiled build (`dart compile exe`) | ≤ 1 second for the first; ≤ 10 ms for the second on the Mac |
| AC-9 | Purity: the files under `dart/lib/` | `dart:mirrors`, `dart:ffi`, `dart:io`: 0; runtime dependencies in `pubspec.yaml`: 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- Reference for behavior: the TypeScript package at HEAD (A-1); for the file split and the test list: the Swift package.
- Unpack never throws on input (fit decision 7): every error is a value. Pack and scheme construction throw.
- `u64` and `i64` are `int`; no `BigInt` (A-3).
- Every size and index computed from input is range-checked before use: a Dart `int` wraps silently.
- No file over 500 lines.
- `dart format` clean and `dart analyze --fatal-infos` with 0 issues.

## Risks & Mitigation

**Risk 1: Hidden exceptions**
- *Risk*: A `RangeError` from a typed-data read escapes unpack as an exception.
- *Mitigation*: Bounds are checked before each read; the short-buffer tests cut the golden packet at every length from 0 to 12 and expect an error value each time.

**Risk 2: Speed in JIT versus compiled**
- *Risk*: `dart test` runs in the JIT and may miss the bound.
- *Mitigation*: The bound is measured on a compiled executable; the test run only checks correctness.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the feature's concerns in `problem.md` | — | resolved | Low |
