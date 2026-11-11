---
loop: 100
branch: dev
---

# Loop 100 — Dart aligned with TypeScript

Loop 100 (on `dev`; no worktree). Intake: the owner's choice of 2026-11-11 ("Dart: align with TypeScript"), then "Accept all recommended" on the row list built from `_docs/02_task_plans/dart-package/parity_differences.md` and `_docs/loops/loop99/assessment99.md`.

Five Dart-only choices of loop 99 move to TypeScript's behaviour (TypeScript is the reference, A-1 of loop 99):

| row | today in Dart | after this loop (TypeScript) |
|-----|---------------|------------------------------|
| D1 | a text with a lone surrogate is refused at pack | the lone surrogate is written as U+FFFD |
| D7 | a clear message too long for its parity throws kind `tooLong` at pack | a plain pack error (TypeScript `RangeError`, Go and Swift pack error kind) |
| D8 | a repeated or out-of-order dictionary key, and a text unpack refuses, are `bad_value` | a short read with `needed` 0 (TypeScript, Go, Swift) |
| D6 | zero rounds of a map-row `repeat`/`times` unpack to an empty list per name | no key for the names of the round (typed rows keep `[]`) |
| D10 | an empty `nested` row is refused when the scheme is built | it builds, as TypeScript's empty group |

Kept as built (owner, 2026-11-11): D9 `Uint8List` for `bits`/`packed`, the D3 helper names, the shared rules Go-1, Go-2 and Go-4, and the rows the Dart language forces (`u64` -1, no `bigint`, the `bool`/`utf8`/`group` names).

Stub written at the claim; the full text follows in the same loop.

## Code sections / UI locations for this loop

Owner (2026-11-11): the Dart package `dart/` (the option "Dart: align with TypeScript"), measured against the TypeScript package `typescript/`; plus the Dart rows of `_docs/02_task_plans/dart-package/parity_differences.md` and any shared fixture that lists Dart's result for these rows.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| D6 and D10 change the API shape of a package not yet on pub.dev; after the first publish such a change breaks callers | owner chose it before the first publish (2026-11-11) | accepted-risk | Low |
