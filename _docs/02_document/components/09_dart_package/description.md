# Dart package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Dart programs (the Archangel Flutter app's background isolate is the planned first consumer), with the same bytes as the other eight packages.

**Architectural Pattern**: stateless clear pack and unpack over an immutable scheme, plus frame mode (`FrameSession`), the one session, which the caller holds (ADR 008, ADR 009). Hand-written walkers, no code generation, no `dart:mirrors`, no FFI (ADR-001).

**Upstream dependencies**: none, inside the repo or outside. The package imports only `dart:typed_data`; SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 are written in the package (`dart/lib/src/crypto/`) and checked on the 27 rows of `fixtures/crypto/vectors.txt`. Development dependencies: `test` and `lints`.

**Downstream consumers**: Dart programs, added with `dart pub add packbin` from pub.dev (ADR-011; the owner publishes the first version by hand, then the release run publishes each tag). The Archangel Android app (Flutter) is the planned first consumer: its live-socket parsers become schemes.

**Layout**: package `packbin` in `dart/` (`pubspec.yaml`, `environment: sdk: ^3.13.0`), library `dart/lib/packbin.dart`, sources `dart/lib/src/`, tests `dart/test/`, `dart/example/packbin_example.dart`, `dart/tool/speed.dart` (the speed bounds), `dart/README.md`, `dart/CHANGELOG.md`, MIT `dart/LICENSE`. Native targets only (the Dart VM and ahead-of-time builds); the web is not supported and not tested (D-4).

## 2. Interfaces

Same shape as TypeScript (`components/02_typescript_package/description.md` §2), Go and Swift: a scheme built from fields by order id, `pack`, `unpack` over a handler list with first-byte dispatch, a typed error, and frame mode (below, `contracts/library/pack-session.md` 3.0.0). The exact differences from TypeScript, row by row with the Dart test of each, are in `_docs/02_task_plans/dart-package/parity_differences.md` (checked by `dart/test/parity/parity_doc_test.dart`).

| Name | Meaning |
|------|---------|
| `scheme(type, fields)` | a `Scheme<Map<String, Object?>>`: a row is a map keyed by the field names |
| `rowScheme<R>(type, create, fields)` | a `Scheme<R>` of typed rows: each value field is bound with `field.bind<R>(get:, set:)`; every value field must be bound |
| `pack(scheme, row)` | the bytes (`Uint8List`), or a thrown `PackbinException` (`packError` naming the field; `tooLong` above `254 - n` bytes with parity) |
| `unpackRow(bytes, scheme)`, `unpack(bytes, handlers)` | an `Unpacked` with `row` or `error` (`PackbinError`), never a throw on input bytes; `scheme.on(handler)` makes a `SchemeHandler`; an empty handler list, a duplicate type number or a mix of parity settings throws `schemeError` |
| `scheme.withLimits({maxRounds, maxSlots, maxBytes})` | a copy; a limit left out takes its default; a value below 1 throws `schemeError`; `Scheme.defaultMaxRounds`, `defaultMaxSlots`, `defaultMaxBytes` |
| `ErrorKind` | `short`, `trailing`, `unknownType`, `badValue`, `tooMany`, `schemeError`, `packError`, `uncorrectable`, `tooLong`; `kind.term` is the shared outcome term |

Field helpers: `u8` to `u64`, `i8` to `i64`, `f32`, `f64`, `bytes`, `be`, `utf8Field`, `list`, `dict`, `flags`, `flagBool`, `when` with `eq`, `repeat`, `times`, `sized`, `u2` with `slot`, `bits`, `packed`, `groupOf` (the anchored group), `nested` and `nestedRow` (the group without an anchor), `flagByte` with `.bit(field)`. The Dart names differ from the other packages for `utf8` (taken by `dart:convert`), `bool` (a core type) and `group` (a function of `package:test`).

Rows: a typed class bound by getter and setter closures, or `Map<String, Object?>`. `null` is no value; an empty list, map or string is a value with count 0. A `u64` is an `int`: a value above 2^63 - 1 is the negative `int` with the same bits (A-3). A `double` (a whole one too), a `BigInt` and an enum case for an integer field, and a non-`bool` for a `flagBool`, are refused (owner decisions Go-1 and Go-2).

### Interface: Error correction (ADR-007, ADR-010, `contracts/library/message-ecc.md` 1.1.0)

| Name | Meaning |
|------|---------|
| `scheme.withParity(n)`, `scheme.parity` | `n` parity bytes, 0 to 32 (0 is off); replaces a percentage; out of range throws `schemeError` naming `parity` |
| `scheme.withParityPercent(p)`, `scheme.parityPercent` | the count is `p` percent (0 to 100) of the clear length, rounded up, at most 32; replaces a count |
| `scheme.withParitySettings({parity, parityPercent})` | one declaration; both above 0 throws `schemeError`; neither given keeps the settings |
| `unpackRepair(bytes, handlers, t)`, `unpackRowRepair(bytes, scheme, t)` | repair up to `t` wrong bytes (0 to `n / 2`; 0 to 16 under a percentage) before the type byte picks the handler; `Unpacked.repaired` is the count; `unpack` and `unpackRow` are `t` = 0; a limit out of range throws `schemeError` naming `limit` before any byte is read |
| `ErrorKind.uncorrectable`, `ErrorKind.tooLong` | too many wrong bytes (names no field); a buffer above 254 bytes (`left` the length), and at pack a clear message above `254 - n` bytes, which throws |

The handlers of one `unpack` call declare the same setting; a mix is refused. The check order of a call (no handler, duplicate type, parity mix, limit, then per packet too long, uncorrectable, empty buffer, unknown type, body) is the one of loop 40.

### Interface: Frame mode (`contracts/library/pack-session.md` 3.0.0)

Public types (the D1 names shared by every package with frame mode; Dart and Java also have `FrameSealed`): `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`, and the result types `FrameSealed`, `FrameRefusal` (with `FrameRefusalKind`), `MacTag`.

| Name | Meaning |
|------|---------|
| `FrameSession.load(key, epoch, config)` | `null` for a key not 32 bytes, an epoch above 0xFFFFFF, a tag length other than 4, 8, 16 or a direction bit outside the set; with `FrameDirections.none` every `seal` and `open` is a bad value; `setPrevious`, `clearPrevious`, `close()` |
| `seal(direction, message, ad, clear, plain, output)` | a `FrameSealed` (`length`) or a `FrameRefusal`; nothing is written on a refusal |
| `open(direction, message, ad, body, clearLength, plain, {window, counter})` | a `FrameOpened` (`slot`, `clearLength`, `plainLength`) or a `FrameRefusal`; the counter is a `BigInt` (unsigned 64 bits) |
| `FrameRefusalKind` | `badValue`, `tooLong`, `bufferFull`, `shortPacket`, `tagMismatch`, `duplicate`, `tooOld`; `term` is the shared snake_case name |
| `ReplayWindow` | `check(counter)` (a `Freshness`), `commit(counter)`, `top`, `bits`; the constructor, `check` and `commit` throw a `RangeError` for a value outside 0 to 2^64 - 1 |
| `MacKey.derive(key, epoch, label)`, `tag(parts, length)`, `verify(parts, tag)`, `close()` | tags of 4, 8, 16 or 32 bytes; `derive` is `null` for a bad key, epoch or label |

No frame call throws for an argument or for wire bytes. `FrameSession` and `MacKey` are used by one isolate at a time: sending one copies it, and `close()` wipes only the copy it is called on. Dart cannot wipe at garbage collection, so keys are wiped by `close()` only (best effort); the tag compare folds every byte with no early exit, and the Dart VM promises no constant time. The `MacKey` holds the 32-byte `K_label`, not the pad states.

## 3. Rules

Dart copies TypeScript row for row (A-1), with the owner's Go decisions Go-1 to Go-4 as Swift took them; a difference is a refusal or a row shape, never bytes.

- A built scheme is immutable and can be sent to any number of isolates (DT-14: 4 isolates times 10,000 round trips).
- A Dart `int` is 64 bits and wraps silently, so every size, count and index computed from input is range-checked before use (the hostile vectors and the seeded run cover it).
- Groups are nested maps both ways (Go-4): a flat key that names a member of a group whose map is not given is refused.
- Limits: 65,535 rounds, 1,048,576 slots, 16,777,216 bytes by default, on pack and on unpack; a nested row in a round charges the width of its own members.
- Unpack refuses a text with a bad code or invalid UTF-8, a repeated or out-of-order dictionary key and a count that is negative or has no value as `badValue`, a round past a limit as `tooMany`, and a count over the bytes left as `short` before anything is made.
- Compact text, error correction and frame mode are the contracts' bytes (`compact-text.md`, `message-ecc.md`, `pack-session.md`), run on the shared vectors as files.

## 4. Decisions

`_docs/02_task_plans/dart-package/problem.md`: D-1 full parity in one loop; D-2 published on pub.dev as `packbin`, first publish by the owner (ADR-011); D-3 Dart 3.13 and newer, one CI image; D-4 native targets only; D-5 the state file is tracked. Agent defaults A-1 to A-7: copy TypeScript row for row; errors as values on unpack and thrown on pack and construction; `u64` as `int`; no dependency; typed rows by getter and setter closures plus the map form; the Dart suite shares a CI job so `test.yml` stays at 20 jobs; the committed version is a placeholder that the release run replaces. Open owner questions recorded in the batch reports: an unpaired surrogate is refused (TypeScript writes U+FFFD); a clear message above `254 - n` bytes is `tooLong`.

## 5. Tests

`dart test -r expanded` in `dart/`: 1,877 tests before the docs task (the suite adds the README tests since), plus the 60 s seeded unpack run, the compiled speed bounds (`dart/tool/speed.dart`, 100,000 round trips and 1,000 frame unpacks under their bounds) and the dependency check, all steps of `run-suite.sh dart` (the `dart` service of `docker-compose.test.yml`, image `dart:3.13.7`). The test specification is [tests.md](tests.md) (DT-1 to DT-20); the README examples are run by `dart/test/readme/`.

## Deferred

The first pub.dev version (owner step of ADR-011); a doc comment on 27 exported names of the frame result and type classes and the `Condition` constructor, which the lint `public_member_api_docs` would flag (`analysis_options.yaml` does not enable it); the CI first-run timing of the `dart:3.13.7` suite.
