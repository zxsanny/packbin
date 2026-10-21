---
loop: 54
branch: dev
---

# C++ core: pin the 255-entry link limit of a `when` source

**Task**: AZ-2823_cpp_when_source_link_limit
**Name**: C++ `when` source link limit test
**Description**: A host test pins that the source of a `when` can sit at most 255 entries behind the `when` that holds it, as the source of a count already can.
**Complexity**: 1 point
**Dependencies**: AZ-2816_cpp_when_of_skipped_source
**Component**: `cpp/tests/core/when_skipped_source_host_tests.cpp`
**Tracker**: AZ-2823
**Epic**: AZ-2645

## Problem

AZ-2816 (loop 54) gave the source of a `when` the link back to its holding `when` that the source of a count has (`mark_held`, a distance that fits one byte). A distance above 255 fails scheme construction: a rule that exists for counts (`order.hpp`; loop 20 C3 "the 255-entry limit"). The feature assessment of round 1 found no test of it for a `when` source (`assessment54.md`, row D2).

## Outcome

- A scheme whose `when` source sits 255 entries behind its holding `when` builds; 256 and 301 entries are refused when the scheme is checked.

## Scope

### Included
- One host test with the three distances.

### Excluded
- Any change to the limit or to the production code.

## Acceptance Criteria

**AC-1: Limit pinned**
Given `u8 mode; when(mode == 1) { n fillers; u8 k }; when(k == 2) { u8 b }`
When the scheme is checked with 254, 255 and 300 fillers (the source 255, 256 and 301 entries behind its `when`)
Then the first is valid and the other two are refused.

## Non-Functional Requirements

**Compatibility**
- No wire change, no change in production code.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `ac6_source_link_is_limited_to_255_entries` | valid, refused, refused |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test` | C++ suite | 0 failures | Compatibility |

## Constraints

- Test only.

## Risks & Mitigation

**Risk 1: none beyond the existing limit**
- *Risk*: a scheme with a body above 255 entries in a `when` that also holds a source is refused; none exists in the repository.
- *Mitigation*: the limit is the one counts already have.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The limit now also applies to `when` sources; other packages have none | recorded in `description.md` of the C++ package | accepted-risk | Low |
