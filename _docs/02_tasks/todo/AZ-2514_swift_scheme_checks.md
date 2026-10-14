---
loop: 26
branch: dev
---

# Swift scheme construction checks and the anchored group

**Task**: AZ-2514_swift_scheme_checks
**Name**: Swift scheme construction checks
**Description**: Swift refuses every scheme the TypeScript package refuses at construction, with a thrown error naming the field, and builds the anchored group.
**Complexity**: 5 points
**Dependencies**: AZ-2513
**Component**: swift
**Tracker**: AZ-2514
**Epic**: AZ-2223

## Problem

A scheme that the other packages refuse at construction (gaps, repeated ids, a flag bit read before its byte, a `when` naming a later field, ...) must not build in Swift, or Swift would pack bytes no other language reads.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (contributes to SW-2 and SW-3 (construction rows); no scenario owned).

## Outcome

- Every construction refusal of TypeScript (`components/02_typescript_package/description.md` §2, `scheme`) is a thrown construction error in Swift naming the id.
- Every README scheme builds.

## Scope

AZ-2513 already has the checks the walker needs to run (eq id declared earlier in the same scope, flag bit with no flag byte earlier, ninth bit, constructor refusals): extend these, do not rewrite.

### Included

- The anchored `group` kind (`group(anchor, name, members...)`): pack and unpack as a `flags` member, a flag-byte bit and wherever TypeScript allows it, typed and map rows, flag-group presence (TypeScript `flag-group-presence`, the `nested-group` rows that need no rounds or collections). The D1 empty anchored group as a flags member (`Flags(0, Group(0,"mark")), U8(0,"n")`) gives TypeScript's rows (D1b A).
- Type number outside 0..255; id gap, repeated id, negative id (U25, Swift `Int` ids); anchor that is not the next value id; flag bit whose byte is not read earlier in the same scope; bool or empty group outside flags/flag-byte bit; `eq`/count id that is not an earlier field of the same scope; `eq` value its source can never hold; member-name collisions; a `repeat`/`times` inside a round; anchored group as list/dict element (the check only; elements come in AZ-2516); nine `flags` members; a `when` on a mark refused or built exactly as TypeScript (D1b A).
- Owns (exclusive write): `swift/**`

### Excluded

- Rounds and collection walking (AZ-2515, AZ-2516)

## Acceptance Criteria

**AC-1: Refusals (SW-3)**
Given each refusal row of the TypeScript construct tests (`scheme`, `scheme-constructor`, `reference-scope`, `flag-scope`, `split-bits-field-order`, `duplicate-names`, `eq-source-kinds`, `eq-value-checked`, `int-range` construct rows)
When the Swift scheme is built
Then a thrown error naming the field id; traps 0; refused-vs-built disagreements with TypeScript 0

**AC-2: README schemes build (SW-2)**
Given every scheme in README.md
When built in Swift
Then built; errors 0

**AC-3: Negative ids (SW-3, U25)**
Given a field id, count id or `eq` id below 0
When built
Then refused naming the id (U25 A for Swift `Int` ids); traps 0

**AC-4: Anchored group (SW-3)**
Given the TypeScript `flag-group-presence` rows, the `nested-group` rows without rounds or collections, and the D1 empty anchored group row
When packed and unpacked in Swift (typed and map)
Then the same hex or refusal as TypeScript; an empty group outside flags/flag-byte bit is refused at construction

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | ported construct rows | same refused/built outcome as TypeScript |
| AC-2 | README schemes | build |
| AC-3 | negative ids | refused |
| AC-4 | group rows, D1 row | TypeScript outcome |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | hostile `construct` cases (run fully in AZ-2519) | build | scheme_error | — |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Swift follows the others (C#, Python, Rust, Java, Go). The D1b rows (empty anchored group, `when` on a mark) stay as documented: Swift copies TypeScript. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import or wrapper of another package. Standard library only in the walker. Unsafe flags 0, C targets 0.
- Local runs are `swift test` at the repository root on the owner's Mac (Swift 6.3.3); Linux runs use `swift:6`. No language feature newer than Swift 5.9.
- Errors are thrown as the typed `PackbinError`; no trap escapes `pack`, `unpack` or scheme construction on any input; every input-derived size and index uses checked or wrapping arithmetic.

## Risks & Mitigation

**Risk 1: TypeScript rule order**
- *Risk*: Two rules can fire on one scheme; the message differs by rule.
- *Mitigation*: Swift checks in the TypeScript order; AZ-2519 pins the rule per hostile case.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (traps, size, `problem.md`) | parent | resolved | Low |
