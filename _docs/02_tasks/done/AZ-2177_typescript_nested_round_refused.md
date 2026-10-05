# TypeScript refuses a `repeat` / `times` nested inside a round; pin `-0`

**Task**: AZ-2177_typescript_nested_round_refused
**Name**: TypeScript nested rounds refused at construction
**Description**: A `repeat` or `times` inside a `repeat` / `times` round fails `Scheme` construction (both `new Scheme` and `scheme()`), as Java and Rust already do; plus a test that pins `-0` into integer fields.
**Complexity**: 3 points
**Dependencies**: AZ-2091_typescript_nested_flags_names (round slicing and the member-name check), AZ-2090_typescript_reference_scope (construction checks live in the `Scheme` constructor)
**Component**: typescript
**Tracker**: AZ-2177
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (T28, T2, X8), owner scope A on 2026-10-05.

- In TypeScript a `repeat` or `times` nested inside a `repeat` / `times` round builds, but the outer round does not slice the inner values. A flat inner list is re-read from item 0 every round: `repeat(u8 n, times(u8 v))` with `{n: [2, 1], v: [1, 2, 3]}` packs `010201020101` (the value 3 became 1, silently); the per-round nested form throws; and the scheme's own unpack always returns an error.
- Java refuses all four nested shapes at construction (loop 12 owner decision; per-round nested lists wait for AZ-2127). Rust refuses three of them. C# is fixed in AZ-2176.
- Separately, no test pins that `-0` packs as 0 in integer fields (AZ-2084 Outcome 1: a safe-integer number is accepted). Production already conforms.

## Outcome

- The four nested shapes fail at construction with a `RangeError` that names the nested container.
- `-0` into `u8`, `i8` and `u64` is pinned by a test.

## Scope

### Included
- A construction check in the `Scheme` constructor (so `new Scheme` and `scheme()` agree) for `repeat` / `times` nested directly or through `when` / `flags` / groups inside a `repeat` / `times` body.
- The `-0` test.

### Excluded
- Per-round nested lists (AZ-2127 defines them for Java; other packages follow it).
- A `repeat` / `times` inside a list or dict element that sits in a round: the element is its own row and keeps working.
- Rust's allowance of a `times` inside a `repeat` round.

## Acceptance Criteria

**AC-1: Nested rounds are refused**
Given a scheme with a `repeat` inside a `repeat`, a `times` inside a `repeat`, a `repeat` inside a `times` or a `times` inside a `times`
When `scheme(...)` or `new Scheme(...)` is called
Then it throws `RangeError` naming the nested container.

**AC-2: Elements keep building**
Given a `repeat` or `times` inside a list or dict element that sits in a round (only an unanchored group element can hold one: a direct `repeat` / `times` element is already refused)
When it is built, and packed with empty collections
Then it builds through `scheme()` and `new Scheme()`, and the empty collections round-trip. Non-empty collections of group elements do not pack per item in TypeScript today (`list(rows, group(row, [u8 c]))` throws `missing c` even outside a round; owned by AZ-2102), so a non-empty round trip is not part of this task.

**AC-3: Existing schemes unchanged**
Given every scheme in the tests, README examples and `.github/workflows/drivers/handoff.ts`
When they are built
Then they build, and the golden, route and ring bytes are identical.

**AC-4: `-0` packs as 0**
Given `u8`, `i8` and `u64` fields and the value `-0`
When packed
Then the bytes are `0100`, `0100` and `010000000000000000`.

## Non-Functional Requirements

**Compatibility**
- Packet bytes of valid schemes do not change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the four nested shapes, also through `when`, `flags` and a group, via `scheme()` and `new Scheme()` | `RangeError` names the nested container |
| AC-2 | list inside a round holding a `repeat` | builds; bytes round-trip |
| AC-3 | existing suite, handoff driver | green; bytes unchanged |
| AC-4 | `-0` into `u8`, `i8`, `u64` | `0100`, `0100`, `010000000000000000` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `language-pair.sh` rings | TypeScript producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: TypeScript keeps its own checker; mirror Java's rule (refuse all four).
- The check lives in the `Scheme` constructor, not only in `scheme(...)` (AZ-2129, AZ-2090 flagged concerns).
- No public API change (`index.d.ts` identical).

## Risks & Mitigation

**Risk 1: A caller scheme that nests rounds stops building**
- *Risk*: such a scheme built before but packed wrong values.
- *Mitigation*: the message says nested rounds are not supported; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rust allows a `times` inside a `repeat` round while the other packages refuse it | owner (parity decision, with AZ-2127) | open | Low |
| Loop 13 review (batch 4): AC-2 as first written asked for a round trip of non-empty group elements, which TypeScript cannot do on HEAD either (list/dict group elements, AZ-2102). AC-2 now states what is provable: builds, empty collections round-trip | coordinator | resolved | Medium |
