---
loop: 26
branch: dev
---

# Swift core: manifest, scalars, flags, when, errors, dispatch, typed and map rows

**Task**: AZ-2513_swift_core
**Name**: Swift core: manifest, scalars, flags, when, errors, dispatch, typed and map rows
**Description**: The root `Package.swift`, the `Packbin` library target and the clear pack/unpack walker for the scalar kinds, flags and `when`, with typed-struct and `[String: Any]` rows.
**Complexity**: 5 points
**Dependencies**: None
**Component**: swift
**Tracker**: AZ-2513
**Epic**: AZ-2223

## Problem

Swift apps and services cannot pack or unpack packbin. The first slice gives them the package (root `Package.swift`, library target `Packbin` at `swift/Sources/Packbin`, MIT through the repository `LICENSE`) and the walker for the AC-1 position row and the scalar data types, with a typed thrown error and no trap on any input.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-1, SW-8, SW-14, SW-15 and the scalar part of SW-2; contributes to SW-10 (manifest), SW-11 (no unsafe flags or C targets), SW-12 (scalars); scenarios S3, S4, S5 owned; S1, S2, S7, S8 in part).

## Outcome

- Swift packs and unpacks the AC-1 row and the README integer, float, fixed-bytes, big-endian, bool, flags and `when` examples with 0 mismatched bytes.
- Rows are typed structs bound by getter/setter closures, or `[String: Any]`; `nil` = no value, a stored 0 is a value (S-5 defaults, as Go G-4, G-5).
- Short, trailing and unknown-type buffers throw a `PackbinError` and give no row; traps 0.

## Scope

### Included

- Root `Package.swift`: `// swift-tools-version: 5.9`, platforms iOS 15 and macOS 12, one library product and target `Packbin` at `swift/Sources/Packbin`, tests at `swift/Tests/PackbinTests`; no package dependency yet (AZ-2518 adds `swift-crypto` for non-Apple platforms, SW-11). The `.gitignore` lines for the SwiftPM build outputs at the root.
- No `swift/LICENSE`: the package root is the repository root, so the root `LICENSE` (MIT) is the package's license (Go needed `go/LICENSE` because its module root is `go/`).
- Language mode (S-4, decided here): Swift 5 language mode, which `swift-tools-version: 5.9` fixes; `Sendable` is compiler-checked with complete strict-concurrency checking on the `Packbin` targets in CI, by a means that adds no unsafe flag to the manifest.
- The `Packbin` public API skeleton: scheme, fields by order id, `pack`, `unpack` with first-byte dispatch over a scheme list; package documentation listing the public names.
- Kinds: u8..u64, i8..i64, f32, f64, fixed bytes, big-endian integers, bool (under flags/flag-byte bit only), `flags`, `flagByte(...).bit`, `when` with `eq`.
- `PackbinError` kinds: short packet (field, needed, left), trailing bytes, unknown type number, bad value; pack refusals naming the field id. The kinds map one-to-one to the hostile outcome terms (`short`, `trailing`, `unknown_type`, `bad_value`, `too_many`, `scheme_error`, `pack_error`); later tasks add cases, they do not rename.
- Speed test (AC-10) and the concurrency test.
- Owns (exclusive write): `swift/**`, `Package.swift`, `.gitignore` (Swift build-output lines only)

### Excluded

- Construction checks beyond what the walker needs to run (AZ-2514)
- Rounds, counted kinds (AZ-2515)
- utf8, list, dict (AZ-2516)
- Limits (AZ-2517)
- Session and the `swift-crypto` dependency (AZ-2518)

## Acceptance Criteria

**AC-1: Golden bytes (SW-1)**
Given the AC-1 row (type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear) as a typed struct and as a `[String: Any]`
When packed
Then the bytes are `4001000065cd1d00a3e1110100` (`fixtures/golden.hex`, read as a file); unpack gives the five fields and 0 motion fields

**AC-2: README scalar examples (SW-2)**
Given each README example for integers, floats, fixed bytes, big-endian, bool, flags and `when`
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-3: Short and trailing (SW-2, S2)**
Given a buffer that ends inside a field, one with 1 trailing byte, and one whose first byte names no scheme
When unpacked
Then a thrown `PackbinError` naming the field, needed and left (short), trailing, or unknown type; no row; traps 0

**AC-4: No value and zero (SW-12)**
Given a flags member whose getter returns `nil`, a map with that key absent, a map whose key holds a boxed `nil`, and the same member given as 0
When packed
Then the `nil`/absent member's bit is clear and adds 0 bytes; the 0 member's bit is set and the 0 is written

**AC-5: Invalid Swift values (SW-15, S4, S5)**
Given a getter returning a value outside its field's range, a dictionary value of the wrong Swift type, a missing key for a field that must hold a value, and a row whose third field is out of range after two valid fields
When packed
Then a thrown pack error naming the field id; no bytes returned (partial output 0 bytes); traps 0

**AC-6: Concurrent use (SW-14, S3)**
Given one built scheme (declared `Sendable`, compiler-checked)
When 8 tasks run 10 000 pack-then-unpack round trips each under `swift test --sanitize=thread`
Then data races 0; mismatches 0

**AC-7: Speed (SW-8)**
Given the AC-1 row
When 100 000 pack-then-unpack round trips run on one core in a release build
Then ≤ 1 second (AC-10); a debug-build timing does not count

**AC-8: Manifest (SW-10 part, SW-11 part)**
Given `Package.swift`, the root `LICENSE` and the `Packbin` target
When inspected and `swift build -c release` runs with warnings treated as errors
Then `swift-tools-version: 5.9`, iOS 15, macOS 12, one library product `Packbin`; package dependencies 0 in this task; unsafe flags 0; C targets 0; `LICENSE` MIT; warnings 0

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | golden row typed and map | golden hex both ways |
| AC-2 | README scalar table | README hex |
| AC-3 | short/trailing/unknown | thrown error, no row |
| AC-4 | `nil`/absent/boxed `nil` vs 0 flags member | bit clear vs set |
| AC-5 | out-of-range getter, wrong type, missing key, third field bad | error naming id, 0 bytes |
| AC-6 | 8 tasks x 10 000 | 0 races |
| AC-7 | AC-10 loop, release build | ≤ 1 s |
| AC-8 | manifest, LICENSE, release build | as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `fixtures/golden.hex` | Swift suite on the owner's Mac (`swift test`) and in `swift:6` | golden hex | AC-1, AC-3 |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). The D1b rows (empty anchored group, `when` on a mark) stay as documented: Swift copies TypeScript. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import or wrapper of another package (not the C++ core). The walker uses the Swift standard library only; CryptoKit / `swift-crypto` are for the session's HKDF (S-2). Unsafe flags 0, C targets 0.
- Swift 6.3.3 is installed on the owner's Mac: local runs are `swift test` at the repository root (where `Package.swift` is); Linux runs use the `swift:6` image (S-4). The manifest admits 5.9 toolchains, so the code uses no language feature newer than Swift 5.9 (for example typed throws).
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input. Swift traps on arithmetic overflow, out-of-range index, force unwrap and a failing `Int` conversion: every size, count, offset and index computed from input or from a row value uses checked or wrapping arithmetic and bounds-checked reads (problem.md concern, High).

## Risks & Mitigation

**Risk 1: API shape fixed early**
- *Risk*: AZ-2514 to AZ-2520 build on this API; a late change ripples through every Swift test.
- *Mitigation*: This task writes the public API for every kind it builds (stubs that refuse are not allowed: kinds not built yet are simply absent) and documents it; later tasks add kinds, they do not rename.

**Risk 2: A trap instead of a thrown error**
- *Risk*: One unchecked `+`, subscript, `!` or `Int(...)` on an input-derived value kills the host process; a trap cannot be caught by the caller.
- *Mitigation*: Reads go through one bounds-checked reader that throws `short`; conversions from wire integers use exact or checked forms; the hostile and fuzz runs (AZ-2519, AZ-2517) count traps.

**Risk 3: Map value types**
- *Risk*: `[String: Any]` can hold any integer type, a `Double`, a `Bool`, or a Foundation `NSNumber` that casts to both `Bool` and `Int` on Apple platforms.
- *Mitigation*: Accept Swift integer types whose value fits the field; refuse a `Bool` for an integer field, an integer for a bool, and a `Double` for an integer field naming the field (as Go-1 B and Go-2 A); the rule is in the package docs. A Foundation `NSNumber` follows the same rule (owner ruling 2026-10-14): a `Bool` for an integer field and an integer for a `Bool` are refused.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Swift traps (not throws) on overflow, out-of-range index, force unwrap and `Int` conversion; a trap on hostile input kills the process | checked/wrapping arithmetic on every input-derived size and index (Constraints); AC-3, AC-5 count traps; AZ-2519 and AZ-2517 prove it | open | High |
| The manifest admits 5.9 toolchains but CI builds only with Swift 6 (SW-9); a Swift-6-only feature compiles everywhere we test and fails for a 5.9 consumer | no feature newer than 5.9 (Constraints); owner ruling 2026-10-14: AZ-2521 adds a 5.9 compile step (AC-4) | resolved | Medium |
| A map value bridged from Foundation (`NSNumber` from `JSONSerialization`) casts to both `Bool` and `Int` on Apple platforms | owner ruling 2026-10-14: refuse a `Bool` for an integer and an integer for a `Bool`, as Go-1 B / Go-2 A | resolved | Low |
