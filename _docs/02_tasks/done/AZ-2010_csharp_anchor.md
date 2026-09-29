---
loop: 8
branch: loop/8-scheme-field-order
---

# C# scheme groups take an anchor id

**Task**: AZ-2010_csharp_anchor
**Name**: C# scheme groups take an anchor id
**Description**: A continuing group in a C# scheme states the next value-field number, and a wrong number fails construction.
**Complexity**: 3 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2010
**Epic**: AZ-1859

## Problem

A caller can see the number on a value field and cannot see where a group sits in that sequence.

## Outcome

- `repeat`, `when`, `times`, `flags`, and a group whose children continue the parent numbers take that next number as an anchor.
- The anchor does not add a field. The following child keeps the next integer.
- An anchor that is not that next number fails construction. Schemes built: 0. Bytes written: 0.
- A known packet packed after the call sites pass the anchor is the same hex.

## Scope

### Included

- The anchor on those groups.
- Existing call sites in this package pass the anchor.
- Construction failures for a gap and a bad anchor.

### Excluded

- A parent number on a list, a dict, or a nested group.
- A count on the wire in front of `repeat`.
- The other five languages.

## Acceptance Criteria

**AC-1: The anchor matches the next value field.**
Given a value field numbered 0 and a `repeat` whose anchor is 1 and whose first child is 1.
When the scheme is built and packed.
Then construction succeeds and the packed bytes match the bytes of that same row before the anchor existed.

**AC-2: A bad anchor fails closed.**
Given a `repeat` whose anchor is not the next value-field number.
When the scheme is built.
Then construction fails. Schemes built: 0. Bytes written: 0.

## Feature Acceptance Criteria

Exercises AC-1 and AC-2 of `_docs/02_task_plans/scheme-field-order/acceptance_criteria.md`.

## Non-Functional Requirements

**Compatibility**
- Mismatched bytes against the previous hex: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | anchor is not the next id | construction fails, 0 bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | field 0 then repeat anchor 1 | pack | same hex as before the anchor | Compatibility |

## Constraints

- The six packages stay peers.
- A list element still starts at 0.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

### ADR Compliance

> Implements ADR 001_runtime-primitives-no-generator. This package checks its own scheme. It does not call another language.
