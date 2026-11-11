# Batch 3 report — loop 99 (Dart package)

Tasks: AZ-4138 dart_collections (5), AZ-4140 dart_ecc (5). 10 points.

| task | result | tests |
|------|--------|-------|
| AZ-4138 | done: `utf8Field`, `list`, `dict`, `nested`/`nestedRow`, dictionary keys ascending by UTF-8 bytes, count bound before allocation, the 4 `ref` text rows through the real scheme, the last deferred hostile construct case | 128 new |
| AZ-4140 | done: GF(256) codec, parity by count and by percentage, `withParity`, `withParityPercent`, `withParitySettings` (a mix is refused when declared), `unpackRepair`, `unpackRowRepair`, `Unpacked.repaired`; 2,372 vector rows run | 69 new |

Whole Dart suite: 807 tests pass; `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues. CI-parity: PASS (same commands as the suite). Review: one total review at the end of the loop.

Owner instruction in session (2026-11-11): the mix of a count and a percentage must be refused when set, not by last setter wins: `withParitySettings` added (as Swift's `withLimits`); the single setters keep the contract's last-wins rule.

## Discovered during implementation

| spec ref | finding | handling | clear/unclear |
|----------|---------|----------|---------------|
| AZ-4138 | helper names `utf8Field` (a top-level `utf8` would clash with dart:convert), `nested`, `nestedRow` | `parity_differences.md` | unclear: names |
| AZ-4138 | repeated or out-of-order dictionary keys and text refusals give `bad_value` (TypeScript, Go, Swift: short with needed 0) | hostile README allows `bad_value` | unclear: owner |
| AZ-4138 | an empty `nested` is refused (TypeScript builds it, Swift makes a presence mark) | refused | unclear: owner |
| AZ-4138 | element and key errors have `field: null` and name the list plus index or key | a list has no id | unclear: DT-3 wants a field id |
| AZ-4138 | `needed` for a count over the bytes left = count times the fewest bytes an item takes | TypeScript reports the first short item | clear |
| AZ-4138 | a `flags` as a direct list element does not compile (type-level); use `nested(name, [flags(...)])` | | clear |
| AZ-4138 | lone surrogate still a thrown pack error (TypeScript writes U+FFFD) | one line in `text_encode.dart` | unclear: owner |
| AZ-4140 | pack of a clear message above `254 - n` bytes is `ErrorKind.tooLong` (Swift/Go use their pack error kind) | one line to switch | unclear: owner |
| AZ-4140 | `unpackRepair`/`unpackRowRepair` take the repair limit; plain `unpack` is detect only | spelling table row for the README | clear |
| AZ-4140 | the worker added two terms to the expected `ErrorKind` list in `dart/test/core/unpack_errors_test.dart` | accepted | clear |
