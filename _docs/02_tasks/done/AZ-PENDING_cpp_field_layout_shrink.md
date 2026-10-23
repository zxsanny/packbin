---
loop: 62
branch: dev
---

# C++ Field layout: drop the Array-only count pointer from every table entry

**Task**: AZ-PENDING_cpp_field_layout_shrink
**Name**: C++ Field layout: drop the Array-only pointers from every table entry
**Description**: Make the C++ table entry (`Field`) 4 B smaller on 32-bit ARM by not carrying the Array-only `count` pointer in every entry (the count is the first member of every Array), with the same packets, results, API and stack; keep it only when the Cortex-M4F flash falls at least 56 B under the pin.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/include/packbin/table.hpp`, `cpp/src/core`
**Tracker**: pending (Jira connector absent, see `_docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md`)
**Epic**: AZ-2645

## Problem

Every entry of a C++ scheme table is 36 B on the Cortex-M4F, of which 8 B are two function pointers that only Array entries (repeat, times, list, dict, bits, packed) read. The flash-budget image has 14 entries, so about 112 B of its 8,192 B budget (pin 8,032 B, margin 160 B) go to fields that 13 of 14 entries never use. Flash is the limiting resource: loop 61 dropped a pack-side `held_of` because it cost 44 to 72 B over the pin.

## Outcome

- `sizeof(Field)` is at most 32 B on 32-bit ARM, not larger anywhere else.
- Flash of the budget image is at most 7,976 B and the pin is lowered to the measured figure; the stack stays at most 504 B.
- Packets, unpacked rows, errors and the scheme-building API are unchanged.
- Or, when the saving is not reached, the source stays at HEAD and the figures are recorded (as loop 61 did).

## Scope

### Included
- The `Field` layout and the Array builders in `cpp/include/packbin/table.hpp` and `fields_counted.hpp`; the readers of the Array item and count in `cpp/src/core/pack.cpp`, `unpack.cpp`, `values.cpp`.
- A compile-time size guard next to `static_assert(offsetof(Field, eq) == 16)`.
- Measurement on the Cortex-M4F image (`cpp/embedded/run.sh arm`), lowering `flash_pin` in `cpp/embedded/lib.sh`, notes in `_docs/AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md`.

### Excluded
- The wire format, the other seven packages, the `Field` members `late`, `flags`, `eq`, `access`, any change visible to a user of the scheme-building API, and raising the flash pin.
- The pack-side `held_of` (measured in loop 61, not kept) and any other `cpp/src/core` work the new margin might allow.

## Acceptance Criteria

Loop source of truth: `_docs/02_task_plans/field-layout-shrink/acceptance_criteria.md`.

**AC-1: Entry size**
Given the C++ package built for 32-bit ARM (Cortex-M4F)
When `sizeof(Field)` is read
Then it is at most 32 B (36 B today), and on no other target (x64, AArch64, x86-32, AVR) is it larger than today.

**AC-2: Flash**
Given the flash-budget image of the arm embedded stage (`PACKBIN_NO_TEXT`, 14-entry table)
When it is built after this loop
Then the flash figure is at most 7,976 B (8,032 B today).

**AC-3: Stack**
Given the all-kinds image of the arm embedded stage
When it measures the deepest pack and unpack stack
Then the figure is at most 504 B.

**AC-4: Same bytes and results** (scenarios S1 to S5)
Given the C++ host suite, the `gcc:16` suite, the ring and the shared corpus
When they run after this loop
Then they pass with 0 changed expectations: packets for Array, list, dict, bits and packed rows (absent, at capacity, one past capacity, nested) are byte-equal to today and unpacked rows and errors are equal.

**AC-5: Other targets build**
Given the `cpp-avr-uno` target and the example targets of `cpp/embedded`
When they are built after this loop
Then each builds as it did before.

**AC-6: No saving**
Given the flash figure of AC-2 is not reached, or AC-3 is not met
When the loop closes
Then the library source stays at HEAD, the shape tried and its figures are recorded in `_docs/AGENT_GOTCHAS.md`, and the pin is not raised.

**AC-7: Public API unchanged**
Given the scheme-building API and the examples in the README and `cpp/embedded`
When they are compiled without edits
Then they compile.

**AC-8: Pin and notes**
Given AC-2 is met
When the loop closes
Then `flash_pin` is lowered to the measured figure, and `AGENT_GOTCHAS.md` and the C++ description state the new `sizeof(Field)`, flash figure and margin.

**AC-9: Guarded**
Given AC-2 is met
When a later edit makes `Field` larger on a 32-bit target
Then the build fails at compile time.

## Non-Functional Requirements

**Performance**
- The 1 s speed bounds of the C++ tests stay as they are; no new load-factor bound.

**Compatibility**
- GCC 16 (`-Wall -Wextra -Werror`), Apple clang, avr-gcc 7.3 (no C++ library, `packbin/platform.hpp` names only in the core).

**Reliability**
- Any edit to `cpp/src/core/pack.cpp` or `unpack.cpp` runs the arm embedded stage (about 3 minutes) before the commit.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-9 | compile-time size check on `Field` | fails to compile above 32 B on a 32-bit target |
| AC-4 | existing host tests of repeat, times, list, dict, bits, packed, nested and capacity cases | pass unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-3 | `docker compose -f docker-compose.test.yml run --rm cpp-embedded` | flash and stack figures | flash at most 7,976 B, stack at most 504 B | Reliability |
| AC-4 | `make -C cpp test`, `gcc:16` `make test`, `scripts/loop-tests.sh` | host suite, container suite, ring, corpus | 0 failures, 0 changed expectations | Compatibility |
| AC-5 | `cpp/embedded/run.sh` (avr, examples) | each target builds | as before | Compatibility |

## Constraints

- No wire, API or other-package change; `static_assert(offsetof(Field, eq) == 16)` stays.
- Helpers called from `unpack_one` keep three real arguments (tail call; `AGENT_GOTCHAS.md`).
- Run `make -C cpp clean` before switching between a Mac build and the `gcc:16` container.

## Risks & Mitigation

**Risk 1: the new way to reach an Array's items adds code**
- *Risk*: an indirection or table for Array entries costs more flash than the entries save.
- *Mitigation*: measure first on the Cortex-M4F image; AC-6 keeps the source at HEAD when under 56 B.

**Risk 2: stack margin is 8 B**
- *Risk*: a deeper call or an extra argument in the pack/unpack walk raises the stack above 504 B.
- *Mitigation*: the arm stage before each commit; a shape above 504 B is not kept.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Indirection may eat the table saving | AC-6 (keep HEAD, record figures) | open | Medium |
| Stack margin 8 B, helper arguments stay three | `_docs/AGENT_GOTCHAS.md` | open | Medium |
| 16-bit targets (AVR) have other pointer sizes | AC-5; larger entry on AVR goes to the owner | open | Low |
