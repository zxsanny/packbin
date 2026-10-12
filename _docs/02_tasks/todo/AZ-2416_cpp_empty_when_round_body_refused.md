---
loop: 22
branch: dev
---

# C++ refuses a times or repeat whose body is an empty when

**Task**: AZ-2416_cpp_empty_when_round_body_refused
**Name**: C++ refuses a times or repeat whose body is an empty when
**Description**: The C++ empty-round check looks at direct children only; a `times`/`repeat` whose body is an empty `when` builds in C++ and is refused in the other five (D8 rule).
**Complexity**: 2 points
**Dependencies**: none
**Component**: cpp
**Tracker**: AZ-2416
**Epic**: AZ-2069

## Problem

Gap G1 of loop 21 (assessment and review). AZ-2390 refuses an empty round body at construction: a body with no *member* looking through `when` and groups. C++ `order.hpp` `check_shape` sees direct children only, so `times(2, 1, [when(1, eq(0,1), [])])` builds. Cortex-M4F flash is 8152 of 8192 B (margin 40 B) and stack 456 of 512 B (margin 56 B).

## Outcome

- The body check looks through `when` and group children, as the D8 rule in the other five packages: a body of only empty containers is refused with `Error::SchemeInvalid`; a zero-width `bytes`, a flag byte and a member-less `flags` are members and still build.
- If the arm embedded stage exceeds 8 192 B flash or 512 B stack with the change, the change is dropped and the saving needed (bytes) is written to the loop 23 handoff.

## Scope

### Included
- `cpp/include/packbin/order.hpp` (`check_shape`) and C++ tests; the arm stage numbers in the batch report.

### Excluded
- Any other C++ behavior; the C++ late-flag exact id (needs ~54 B saving, not taken).

## Acceptance Criteria

**AC-1: refused**
Given `times`/`repeat` whose body is an empty `when`, a `when` of an empty `when`, an empty group
When the scheme is built
Then `SchemeInvalid`.

**AC-2: members still build**
Given a body with a zero-width `bytes`, a flag byte, or a member-less `flags`, or a `when` holding a member
When built
Then it builds as at HEAD.

**AC-3: footprint**
Given the arm embedded stage
When run
Then flash at most 8 192 B and stack at most 512 B; numbers recorded.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | three empty shapes x times/repeat | SchemeInvalid |
| AC-2 | member shapes | builds |
| AC-3 | arm stage | within budget |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile loader (cpp) | `scheme_error` rows for empty-when bodies (AZ-2417) | refused in six | flash 8 192 B |

## Constraints

- Ends with `docker run gcc:16 make test` (and `make -C cpp clean` between host and container builds) and the arm embedded stage.
