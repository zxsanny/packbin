# C# refuses a `repeat` / `times` nested inside a round

**Task**: AZ-2176_csharp_nested_round_refused
**Name**: C# nested rounds refused at construction
**Description**: A `repeat` or `times` inside a `repeat` / `times` round fails `Scheme<T>` construction, as Java and Rust already do, until per-round nested lists are designed.
**Complexity**: 2 points
**Dependencies**: AZ-2175_csharp_when_on_written_values (same package and walker files; land in order), AZ-2087_csharp_forward_refs, AZ-2088_csharp_pack_fails_loudly
**Component**: csharp
**Tracker**: AZ-2176
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (C16, X8), owner scope A on 2026-10-05.

- In C# a `repeat` or `times` nested inside a `repeat` / `times` round builds, but the inner values are not packed from the outer round. `repeat` in `repeat` silently drops the inner values (`010101` for K = [1, 2], V = [7, 8]); a `times` inside a `repeat` throws a misleading `'V' has no value` (since AZ-2088).
- Java refuses all four shapes at construction (loop 12 owner decision; per-round nested lists wait for AZ-2127). Rust refuses `repeat` in `repeat`, `repeat` in `times` and `times` in `times`, and still allows a `times` inside a `repeat` round.
- TypeScript has the same gap and is fixed in AZ-2177.

## Outcome

- The four nested shapes fail at construction with a message that names the nested container.
- Nothing else changes: valid schemes keep their bytes and still build.

## Scope

### Included
- A construction check for `repeat` / `times` nested directly or through `when` / `flags` / groups inside a `repeat` / `times` body.

### Excluded
- Per-round nested lists (AZ-2127 defines them for Java; other packages follow it).
- A `repeat` / `times` inside a list or dict element that sits in a round: the element is its own row and keeps working.
- Rust's allowance of a `times` inside a `repeat` round: stays a documented difference.

## Acceptance Criteria

**AC-1: Nested rounds are refused**
Given a scheme with a `repeat` inside a `repeat`, a `times` inside a `repeat`, a `repeat` inside a `times` or a `times` inside a `times`
When `new Scheme<T>(...)` is called
Then it throws `ArgumentException` naming the nested container.

**AC-2: Elements keep working**
Given a `repeat` or `times` inside a list or dict element, and that list inside a `repeat` round
When it is built, packed, read and repacked
Then it builds and the bytes round-trip (for example `01010200070802010009`).

**AC-3: Existing schemes unchanged**
Given every scheme in the tests, README examples and `.github/workflows/drivers/csharp`
When they are built
Then they build, and the golden, route and ring bytes are identical.

## Non-Functional Requirements

**Compatibility**
- Packet bytes of valid schemes do not change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the four nested shapes, also through `when`, `flags` and a group | `ArgumentException` names the nested container |
| AC-2 | list inside a round holding a `repeat` | builds; bytes round-trip |
| AC-3 | existing suite, handoff driver | green; bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `language-pair.sh` rings | C# producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: C# keeps its own checker; mirror Java's rule (refuse all four), do not share code.
- `ArgumentException` stays the construction error type.

## Risks & Mitigation

**Risk 1: A caller scheme that nests rounds stops building**
- *Risk*: such a scheme built before but did not pack the inner values correctly.
- *Mitigation*: the message says nested rounds are not supported; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rust allows a `times` inside a `repeat` round while Java and (after this task) C# and TypeScript refuse it | owner (parity decision, with AZ-2127) | open | Low |
