---
loop: 8
branch: loop/8-scheme-field-order
---

# Rust scheme build checks field order

**Task**: AZ-2013_rust_scheme_order
**Name**: Rust scheme build checks field order
**Description**: Every public Rust scheme constructor rejects a gap, a bad anchor, and a reference to an id not yet walked.
**Complexity**: 5 points
**Dependencies**: None
**Component**: rust
**Tracker**: AZ-2013
**Epic**: AZ-1862

## Problem

Some Rust scheme constructors never check that field numbers are 0, 1, 2. A raw field list and a dictionary helper can build a scheme another language would reject.

## Outcome

- Continuing groups take the same anchor as the other languages.
- Every public constructor runs that walk, including a raw field list and a dictionary whose element numbers were not supplied.
- A gap or a repeated id fails construction. Schemes built: 0.
- A `when` or a borrowed count that names an id not yet walked fails construction. Schemes built: 0.
- A known packet packed after the call sites pass the anchor is the same hex.

## Scope

### Included

- The anchor on continuing groups.
- The check on every public constructor.
- The reference check for `when` and a borrowed count.

### Excluded

- A parent number on a list or a dict.
- A shared checker used by another language.

## Acceptance Criteria

**AC-1: A raw field list cannot skip a number.**
Given a raw field list whose second value field is numbered 2.
When the scheme is built.
Then construction fails. Schemes built: 0. Bytes written: 0.

**AC-2: A missing reference fails closed.**
Given a `when` or a borrowed count that names an id not yet walked.
When the scheme is built.
Then construction fails. Schemes built: 0.

**AC-3: A good anchor keeps the bytes.**
Given a value field 0 and a `repeat` whose anchor and first child are 1.
When the scheme is packed.
Then the hex matches the bytes of that same row before the anchor existed. Mismatched bytes: 0.

## Feature Acceptance Criteria

Exercises AC-1, AC-2, and AC-4 of the scheme-field-order feature.

## Non-Functional Requirements

**Compatibility**
- Mismatched bytes: 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | raw list with a gap | construction fails, 0 bytes |
| AC-2 | when names an unknown id | construction fails, 0 bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | field 0 then repeat anchor 1 | pack | same hex as before the anchor | Compatibility |

## Constraints

- The six packages stay peers.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |

### ADR Compliance

> Implements ADR 001_runtime-primitives-no-generator.
