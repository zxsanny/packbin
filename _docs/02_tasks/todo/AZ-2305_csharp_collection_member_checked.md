---
loop: 18
branch: dev
---

# C# refuses collection members that do not match their field at scheme construction

**Task**: AZ-2305_csharp_collection_member_checked
**Name**: C# collection member check
**Description**: A typed row member whose collection type cannot hold its element field, or is not an array, `List<E>` or `Dictionary<string,E>`, is refused with `ArgumentException` naming the member when the scheme is built.
**Complexity**: 2 points
**Dependencies**: AZ-2092_csharp_scoped_binding (done)
**Component**: csharp
**Tracker**: AZ-2305
**Epic**: AZ-2069

## Problem

Owner decision 2 of loop 18 (2026-10-10, option A). Found in loop 17 (assessment D4, security F25 and F26, review R1 and R4):

- A member of type `List<int>` for a `u32` field lets one hostile 7-byte packet throw `OverflowException` out of `Unpack`; the library promises unpack never throws on hostile bytes.
- A member of an unsupported collection type (`Stack<int>`) builds and throws `InvalidCastException` when unpacking.

## Outcome

- Both shapes fail at scheme construction with `ArgumentException` naming the member, so no packet can trigger them.
- Matching members and every existing scheme behave as before.

## Scope

### Included
- Typed row binding in `csharp/`: element-width check against the field kind (every integer and float width, signed and unsigned, `Be()`), and the collection-type check for arrays, `List<E>`, `Dictionary<string,E>` and nested element types.
- README upgrade note (one line) is done by the parent in the docs step.

### Excluded
- Dictionary rows (they hold boxed values and are unaffected); other packages.

## Acceptance Criteria

**AC-1: a narrower element type is refused**
Given a typed row with `List<int>` (and `int[]`, `Dictionary<string,int>`) for a `u32` list or dict field, and `List<byte>` for a `u16` field
When the scheme is built
Then `ArgumentException` names the member and the element type

**AC-2: an unsupported collection type is refused**
Given a member of type `Stack<int>`, `HashSet<int>` or `IEnumerable<int>` for a list field
When the scheme is built
Then `ArgumentException` names the member

**AC-3: the hostile packet no longer throws**
Given the 7-byte packet of the F25 probe against the corresponding wide-enough scheme (`List<long>` for `u32`)
When it is unpacked
Then the result is a value or an unpack failure result, never an exception

**AC-4: matching members unchanged**
Given every typed scheme in the existing suite, the README example and the golden fixtures
When they are built, packed and unpacked
Then bytes and results are unchanged; the suite passes on net10.0 and netstandard2.0

## Non-Functional Requirements

**Compatibility**
- No wire change. A scheme that only packed with a mismatched member now fails at build (noted in the upgrade notes).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | each width pair, signed and unsigned | `ArgumentException` naming the member |
| AC-2 | the three unsupported types | `ArgumentException` |
| AC-3 | the F25 packet | no exception from `Unpack` |
| AC-4 | existing suite | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | built scheme, hostile bytes | `Unpack` | no throw | project hostile-input rule |

## Constraints

- ADR-001: C# implements it itself. Files stay at or under 500 lines.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Which narrower pairs are refused (an element type wider than the field is accepted) is the writer's reading of "cannot hold the element field"; the worker lists the rule in the batch report | coordinator | open | Low |
