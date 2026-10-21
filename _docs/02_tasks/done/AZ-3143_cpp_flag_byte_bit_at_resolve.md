---
loop: 56
branch: dev
---

# C++ flag-byte answer at resolve time

**Task**: AZ-3143_cpp_flag_byte_bit_at_resolve
**Name**: C++ flag-byte bit at resolve (flash saving)
**Description**: `reads_flag_byte` no longer scans a `when`'s entries on each unpack call; the answer is set once when the scheme resolves, and the flash image shrinks.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/src/core/unpack.cpp`, `cpp/include/packbin/table.hpp` (`flag::`), `cpp/include/packbin/order.hpp` (resolve), `cpp/embedded/` (probe), `cpp/tests/core`
**Tracker**: AZ-3143
**Epic**: AZ-2645

## Problem

`reads_flag_byte` (`unpack.cpp:48`) scans the entries of a held `when` on every `unpack_children` call. The answer depends only on the scheme. The Cortex-M4F flash margin is 72 B (8120 B of 8192 B), so no other C++ edit fits until a saving is made.

## Outcome

- The answer is a bit set at resolve time (`flag::` value 128 of `Field::flags` is free); unpack reads the bit. `Field` stays 16 bytes before `eq`.
- Flash image at most 8040 B.

## Scope

### Included
- A new `flag::` constant, set by the resolver for every `when` whose span holds a flag byte, on every build path (host builders and generated tables).
- Unpack uses it; `reads_flag_byte` and its loop are removed.
- Margins in `AGENT_GOTCHAS.md` and the C++ description (parent writes them from the report).

### Excluded
- The fold of `unpack_children` and `unpack_one` (AZ-3144); any wire change; other packages.

## Acceptance Criteria

**AC-1: Flash** — Given the Cortex-M4F flash image, When built after the change, Then at most 8040 B, and `cpp-avr-uno` and `PACKBIN_NO_TEXT` stay inside their margins.

**AC-2: No scan** — Given any scheme with held `when`s, When unpacked, Then no per-call scan of entries is made; the decision reads the bit set at resolve time, for schemes built by the host builders and by the generated tables.

**AC-3: Packets unchanged** — Given the shared hostile and differential corpora, When run, Then `make -C cpp test` (host), `gcc:16 make test`, and the arm embedded stage pass with no new skip, and `static_assert(offsetof(Field, eq) == 16)` holds.

## Non-Functional Requirements

**Compatibility**: no wire change. **Stack**: 3-deep chain 504 B and flag-byte chain 500 B not above today's.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | arm embedded stage flash figure | at most 8040 B |
| AC-2 | host test: a `when` with and without a flag byte inside, built both ways, unpacks to the same row; the bit is set exactly on the first | pass |
| AC-3 | full C++ suites listed above | pass |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A generated table path may not set the bit | test both build paths (AC-2) | open | Medium |
| The saving may be below 80 B | report the figure; AC-1 not met means a ticket, not a loosened bound | open | Medium |

## Outcome of loop 56

AC-2 and AC-3 met. AC-1 missed: flash 8,080 B against 8,040 B (a 40 B saving, margin 112 B). The owner accepted the gap and carried the byte search to a later loop (assessment 56, F4).
