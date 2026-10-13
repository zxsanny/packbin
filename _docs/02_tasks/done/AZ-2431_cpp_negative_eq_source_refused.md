---
loop: 23
branch: dev
---

# C++ refuses a when whose eq names a negative source id; empty-body rule pinned on its own

**Task**: AZ-2431_cpp_negative_eq_source_refused
**Name**: C++ refuses a when whose eq names a negative source id (U19, F36); empty-body rule tests that survive it (G2)
**Description**: C++ builds `when(id, eq(-1, v), ...)` with no error; refuse it at construction, flash-gated, and pin the AZ-2416 empty-body rule independently of that refusal.
**Complexity**: 2 points
**Dependencies**: none
**Component**: cpp
**Tracker**: AZ-2431
**Epic**: AZ-2069

## Problem

Owner decision U19 A (2026-10-13); security F36; review22 finding 6; assessment22 gap G2. In C++ a `when` whose `eq` source id is negative builds: the `when` never holds, the member is dropped on pack, and the same packet then fails to unpack. The other five packages name `when` sources by field name, so no such spelling exists there. The AZ-2416 tests (`times_count_zero_host_tests.cpp`, `hostile_host_tests.cpp`) reach the empty-body rule (`has_member` in `cpp/include/packbin/order.hpp`) only through this spelling; `refused_at` checks `SchemeInvalid` plus a field id, so once the hole is closed they could stay green without exercising `has_member`. Cortex-M4F: flash 8152 of 8192 B (40 B margin), stack 456 of 512 B (56 B margin).

## Outcome

- A `when` whose `eq` names a negative source id is refused at construction with `Error::SchemeInvalid` at the `when`'s own id.
- The empty-body rule is pinned by tests that cannot pass through the new refusal: either a spelling that reaches `has_member` without a negative id, or a direct constexpr/unit check of `has_member`/`check_shape`, or an assertion on the round's id (not the `when`'s). The worker states which and why (review22: in the other packages no public spelling reaches the rule; C++ may be the same after this change).
- If the arm embedded stage exceeds 8 192 B flash or 512 B stack, the source change is dropped and the saving needed (bytes) is written in the batch report for the loop 24 handoff; the G2 tests still land.

## Scope

### Included
- `cpp/include/packbin/order.hpp` (`resolve` or the `eq` check) and C++ tests; arm stage numbers in the batch report.

### Excluded
- Any other C++ behavior; the C++ late-flag exact id (about 54 B, not taken); hostile cases (D4).

## Acceptance Criteria

**AC-1: negative eq source refused**
Given a scheme with `when(id, eq(-1, v), [member])` at the top level, inside a group, and inside a `times`/`repeat` body
When the scheme is built
Then `SchemeInvalid` at the `when`'s id.

**AC-2: valid ids unchanged**
Given every scheme in the C++ suite that uses `eq` with a non-negative id
When built, packed and unpacked
Then results and bytes as at HEAD (b8b2809).

**AC-3: empty-body rule on its own**
Given `times`/`repeat` bodies of an empty `when`, a `when` of an empty `when`, an empty group (the three AZ-2416 shapes), and the four member shapes (zero-width `bytes`, flag byte, member-less `flags`, `when` holding a member)
When validated
Then the three empty shapes are refused by the body rule (at the round's id, or by a direct check of `has_member`) and the four member shapes build.

**AC-4: footprint**
Given the arm embedded stage
When run
Then flash at most 8 192 B and stack at most 512 B; numbers recorded.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | negative eq id in three positions | SchemeInvalid at the when's id |
| AC-2 | existing suite | green, bytes unchanged |
| AC-3 | 3 empty shapes x times/repeat; 4 member shapes | body rule refuses / builds |
| AC-4 | arm stage | within budget |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | hostile loader (cpp), 65 cases | `make test` hostile stage | all pass, `construct_empty_*when*` still `scheme_error` | flash 8 192 B |

## Constraints

- Ends with host `make -C cpp test`, `make -C cpp clean`, `docker run --rm -v "$PWD":/src -w /src/cpp gcc:16 make test`, and the arm embedded stage (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`).
- New test code goes in a file under 500 lines (`hostile_host_tests.cpp` was split in loop 22).
