---
loop: 6
branch: loop/6-python-single-accessor
---

# Python single accessor

**Task**: AZ-1963
**Name**: Python single accessor
**Description**: A Python scheme field takes one member accessor. Pack reads it. Unpack writes it back.
**Complexity**: 3 points
**Dependencies**: AZ-1950
**Component**: python
**Tracker**: AZ-1963
**Epic**: AZ-1861

## Problem

A Python field call takes a reader and a writer. The other languages take one member read. Callers copy a helper that builds both functions from a name.

## Outcome

- Each Python field is declared with one member accessor.
- Pack of the position row yields `4001000065cd1d00a3e1110100`. Wrong fields: 0.
- Unpack of that hex writes sid 1, lat 500000000, lon 300000000, profile 1. Bytes left: 0.
- A mapping row round-trips through one key accessor. Wrong fields: 0.
- An accessor that is not a plain member read fails at declaration. Accepted count: 0.
- The README Python example contains 0 bind helpers.

## Scope

### Included

- Every Python field helper that today takes a reader and a writer.
- Object rows and mapping rows.
- Python tests that declare those fields.
- README Python example.
- A Python field contract and the public-API note in the module layout.

### Excluded

- C#, TypeScript, Rust, Java, and C++ signatures.
- The BinaryPacker rename.
- Writing a value back through a computed accessor.
- Two callers packing at once, permission checks, and undo.

## Acceptance Criteria

**AC-1: One member accessor packs the field.**
Given a position row with sid 1, lat 500000000, lon 300000000, profile 1, and heading, speed, and altitude absent.
When each field is declared with one member accessor and the row is packed, including a second pack of the same row.
Then both hex strings are `4001000065cd1d00a3e1110100`. Wrong fields: 0.

**AC-2: Unpack writes that member.**
Given the hex `4001000065cd1d00a3e1110100` and one handler for that scheme.
When unpacked.
Then sid is 1, lat is 500000000, lon is 300000000, profile is 1. Bytes left: 0. Wrong fields: 0.

**AC-3: A mapping row uses the same call shape.**
Given a mapping whose sid is 1.
When the field accessor reads that key and the row is packed and unpacked.
Then sid is 1. Wrong fields: 0. Bytes left: 0.

**AC-4: A non-member accessor is rejected.**
Given an accessor that is not a plain member read.
When the field is declared.
Then declaration fails. Accepted non-member accessors: 0.

**AC-5: The README sample has no second function.**
Given the README Python example.
When counted.
Then occurrences of a bind helper are 0.

## Feature Acceptance Criteria

Exercises project field binding: the order number stays the binding key. This task changes only the Python call shape.

## Non-Functional Requirements

**Compatibility**
- The position hex stays `4001000065cd1d00a3e1110100`.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Pack a position object twice through one attribute accessor per field | Both hex strings equal `4001000065cd1d00a3e1110100` |
| AC-2 | Unpack that hex | sid 1, lat 500000000, lon 300000000, profile 1, bytes left 0 |
| AC-3 | Pack and unpack a one-key mapping | sid 1, wrong fields 0, bytes left 0 |
| AC-4 | Declare a field with a non-member accessor | Declaration fails, accepted count 0 |
| AC-5 | README Python example | bind helper count 0 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | Position values above | Pack | Hex `4001000065cd1d00a3e1110100` | Compatibility |

## Constraints

- A field call accepts one accessor. A separate writer argument is not part of the call.
- The accessor must be a plain member read on an object or a mapping.

## Risks & Mitigation

**Risk 1: Existing Python examples pass two functions.**
- *Risk*: Those calls fail after the signature change.
- *Mitigation*: Update the Python tests and the README in this task.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Two-function field calls stop working. Chosen option: one accessor only. | This task | resolved | Medium |
| A computed accessor has nowhere to write the unpacked value. | AC-4 | resolved | Low |
| Loop 5 is already stamped on binary_packer, so this loop is 6. | Hopper claim | resolved | Low |

## Contract

This task produces the contract at `_docs/02_document/contracts/python/fields.md`.
Consumers read that file for the Python field call shape.

### ADR Compliance

> Implements ADR 001_runtime-primitives-no-generator: Python stays a peer package. No shared walker.

## Document Dependencies

- `_docs/02_document/module-layout.md` public API row for Python. This task updates the call-shape note there.
