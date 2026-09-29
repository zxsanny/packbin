---
loop: 8
branch: loop/8-scheme-field-order
---

# TypeScript scheme groups take an anchor id

**Task**: AZ-2011_typescript_anchor
**Name**: TypeScript scheme groups take an anchor id
**Description**: A continuing group in a TypeScript scheme states the next value-field number, and a wrong number fails construction.
**Complexity**: 3 points
**Dependencies**: None
**Component**: typescript
**Tracker**: AZ-2011
**Epic**: AZ-1860

## Problem

A caller can see the number on a value field and cannot see where a group sits in that sequence.

## Outcome

- `repeat`, `when`, `times`, `flags`, and a group whose children continue the parent numbers take that next number as an anchor.
- The anchor does not add a field.
- An anchor that is not that next number fails construction. Schemes built: 0. Bytes written: 0.
- A known packet packed after the call sites pass the anchor is the same hex.

## Scope

### Included

- The anchor on those groups, and the call sites in this package.

### Excluded

- A parent number on a list, a dict, or a nested group.
- The other five languages.

## Acceptance Criteria

**AC-1: The anchor matches the next value field.**
Given a value field numbered 0 and a `repeat` whose anchor is 1 and whose first child is 1.
When the scheme is built and packed.
Then the packed bytes match the bytes of that same row before the anchor existed.

**AC-2: A bad anchor fails closed.**
Given a `repeat` whose anchor is not the next value-field number.
When the scheme is built.
Then construction fails. Schemes built: 0. Bytes written: 0.

## Feature Acceptance Criteria

Exercises AC-1 and AC-2 of the scheme-field-order feature.

## Non-Functional Requirements

**Compatibility**
- Mismatched bytes: 0.

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

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

### ADR Compliance

> Implements ADR 001_runtime-primitives-no-generator.
