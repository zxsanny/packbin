---
loop: 21
branch: dev
---

# An empty times or repeat body is refused at construction in six packages

**Task**: AZ-2390_empty_round_body_refused
**Name**: An empty times or repeat body is refused at construction in six packages
**Description**: A `times` or `repeat` whose body has no members is refused when the scheme is built, so no round charges 0 slots and writes 0 bytes.
**Complexity**: 3 points
**Dependencies**: AZ-2382 (slot rule)
**Component**: typescript (first), python, java, csharp, rust, cpp
**Tracker**: AZ-2390
**Epic**: AZ-2069

## Problem

Security F33 (Low) from the loop 20 audit. An empty `times` or `repeat` body charges 0 slots and writes 0 bytes, so the budget does not bound CPU: a `list` of groups holding `times(65535) {}` with 65 535 items (about 1.1 MB of JSON) took 93 s in TypeScript (extrapolated 41 s Java, 74 s C#, 3 min Rust release, 1.7 h Python). Loop 20 lesson: every unit of work, the empty one included, must charge at least one unit. The simplest rule that gives that is to refuse the empty body, since it can carry no data.

## Outcome

- Building a scheme with an empty round body fails in all six packages with a named error; an empty body inside a `when` that can be clear is judged by the same rule (decision recorded in the reference table).

## Scope

### Included
- Scheme construction checks in the six packages.

### Excluded
- Rounds with a non-empty body; unpack of existing packets (they cannot contain it).

## Acceptance Criteria

**AC-1: refused**
Given `times(n) {}` and `repeat {}`
When the scheme is built
Then an error naming the member

**AC-2: CPU bound**
Given the F33 request shape
When sent to pack
Then it fails at build, in under 1 s

**AC-3: non-empty body**
Given a body with one `u8`
When built
Then unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | both forms per package | error |
| AC-2 | F33 shape | under 1 s |
| AC-3 | one-member body | builds |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_empty_round_body` (AZ-2394) | error in six | — |

## Constraints

- A construction-time rule: it adds no per-round cost.
- C++ cost on Cortex-M4F must fit the 32 B margin or the C++ part goes to the next loop with a recorded saving needed.

## Loop 21 result

All six refuse a `repeat` or `times` whose body holds no member when the scheme is built (`repeat 0: the body holds no member; a round of it would charge no slot and write nothing`; Rust panics; C++ `SchemeInvalid`, direct children only, so a single empty `when` still builds there: gap G1). A zero-width `bytes`, a flag byte and a member-less `flags` are members and build. The F33 request shape is refused in a few ms. Tests: `empty-round-body.test.ts`, `test_empty_round_body.py`, `EmptyRoundBodyTest`, `EmptyRoundBodyTests`, `empty_round_body_tests.rs`, `container_tests.cpp`; hostile `construct_empty_*`.
