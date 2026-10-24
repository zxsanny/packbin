---
loop: 63
branch: dev
---

# C++ pack.cpp: find a 72 B flash saving, then decide on the pack-side held_of

**Task**: AZ-3169_cpp_pack_flash_saving
**Name**: C++ pack.cpp: find a 72 B flash saving, then decide on the pack-side held_of
**Description**: Look in `cpp/src/core/pack.cpp` for a Cortex-M4F flash saving of at least 72 B with the same bytes, results and stack; only when it is found, rebuild the loop 61 pack-side `held_of` on top of it and keep it only when it pays for itself.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/src/core/pack.cpp`
**Tracker**: AZ-3169 (Jira connector absent, see `_docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md`)
**Epic**: AZ-2645

## Problem

The Cortex-M4F image is at 7,808 B of 8,192 B (pin 7,808 B, margin 384 B) and the stack at 496 of 512 B (margin 16 B). Loop 61 measured a pack-side `held_of` (one function deciding skip / enter inline / enter a flag bit's child for a `when` or a flag bit, asked by `pack_children` and `pack_one`) at +44 to +72 B of flash for 0 to 8 B of pack stack, and dropped it; `AGENT_GOTCHAS.md` says not to retry it without a saving of at least 72 B found first in `pack.cpp`. The owner asked on 2026-10-23 to look for that saving first, then decide on `held_of`.

## Outcome

- Part 1: `pack.cpp` is smaller by at least 72 B of Cortex-M4F flash (7,736 B or less), with equal bytes, results and stack; or a smaller pure reduction is kept; or the source stays at HEAD with every shape tried recorded.
- Part 2 (only after a 72 B saving): the pack-side `held_of` is kept when its flash is at most the part 1 figure and no stack figure grows; otherwise dropped with its figures recorded.

## Scope

### Included
- `cpp/src/core/pack.cpp` only (its functions, helpers and the order of its cases).
- Measurement on the Cortex-M4F image (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`), lowering `flash_pin` in `cpp/embedded/lib.sh`, margins in `_docs/AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md`.
- The shape tried and its figures in the loop 63 record, kept or not.

### Excluded
- Unpack, the `Field` layout, `values.hpp` and `values.cpp`, the wire format, the other seven packages, raising the flash pin, any change visible to a user of the scheme-building API.

## Acceptance Criteria

Loop source of truth: `_docs/02_task_plans/pack-flash-saving/acceptance_criteria.md`.

**AC-1: Baseline**
Given HEAD `c9ceaa7` with no source edit
When the arm embedded stage runs
Then Cortex-M4F flash (expected 7,808 B) and the pack and unpack stack figures (deepest 496 B) are recorded in the loop 63 record.

**AC-2: Saving**
Given a candidate edit to `pack.cpp`
When the arm stage measures it
Then a kept saving gives flash of 7,736 B or less (72 B or more under 7,808 B) and part 2 runs; a saving of 1 to 71 B is kept when AC-3 to AC-5 hold and part 2 is skipped; with no saving the source stays at HEAD and every shape tried is recorded.

**AC-3: Stack**
Given the all-kinds image and the chain images of the arm stage
When the stack is measured after a kept edit
Then no figure is above HEAD: pack 412 B / 448 B / 500 B (plain / flag / round chain) and the deepest 496 B of 512 B.

**AC-4: Same bytes and results** (scenarios 6 and 8)
Given the C++ host suite, the `gcc:16` suite, the ring and the shared corpus
When they run after a kept edit
Then they pass with 0 changed expectations: packets are byte-equal and every refused input returns the same `Error`, offset and field id as at HEAD.

**AC-5: Pin**
Given a kept saving
When the loop closes
Then `flash_pin` in `cpp/embedded/lib.sh` is lowered to the measured figure and is never raised.

**AC-6: Candidate figures**
Given part 1 reached 72 B
When the loop 61 shape (`_docs/loops/loop61/pack_held_of_a.patch`, shapes A to E as needed) is built on the saving
Then its flash and stack figures are recorded next to the part 1 figures.

**AC-7: Keep rule**
Given the figures of AC-6
When `held_of` flash is above the part 1 figure, or any stack figure of AC-3 grows
Then `held_of` is dropped, the source stays at the part 1 state and the figures are recorded.

**AC-8: One decision point**
Given `held_of` is kept
When `pack.cpp` is read
Then one function decides "skip / enter inline / enter a flag bit's child" for a `when` or a flag bit and both `pack_children` and `pack_one` call it; no second copy of the `when_matches` / `present(i + 1)` test remains for these two kinds.

**AC-9: Other targets and notes**
Given any source change is kept
When the full arm stage (Cortex-M4F, M0, AVR Uno `cpp-avr-uno`, big-endian) and the `gcc:16` build run
Then they pass with 0 compile warnings, and `AGENT_GOTCHAS.md` and the C++ description carry the new flash and stack figures and margins.

## Non-Functional Requirements

**Performance**
- The 1 s speed bounds of the C++ tests stay as they are; no new load-factor bound.

**Compatibility**
- GCC 16 (`-Wall -Wextra -Werror`), Apple clang, avr-gcc 7.3 (no C++ library, `packbin/platform.hpp` names only in the core).

**Reliability**
- Any edit to `cpp/src/core/pack.cpp` runs the arm embedded stage (about 3 minutes) before the commit.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | existing host tests of pack vectors, refused values in flag bit children, held `when`s, counted items and dict keys | pass unchanged |
| AC-8 | read of `pack.cpp` after the edit | one function holds the `when` / flag bit decision |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-3, AC-6, AC-7 | `docker compose -f docker-compose.test.yml run --rm cpp-embedded` | flash and stack figures | per the AC rows | Reliability |
| AC-4 | `make -C cpp clean && make -C cpp test`, `gcc:16` `make test`, `scripts/loop-tests.sh` | host suite, container suite, ring, corpus | 0 failures, 0 changed expectations | Compatibility |
| AC-9 | `cpp/embedded/run.sh` (M0, avr, big-endian, examples) | each target builds | 0 warnings | Compatibility |

## Constraints

- Helpers called from `unpack_one` keep three real arguments (tail call; `AGENT_GOTCHAS.md`); this loop does not touch unpack.
- Run `make -C cpp clean` before switching between a Mac build and the `gcc:16` container.
- Edit no file in the repository while the `publish-gate` stage of `scripts/loop-tests.sh` runs.

## Risks & Mitigation

**Risk 1: no saving of 72 B exists in `pack.cpp`**
- *Risk*: the file is already tight after loops 20 to 62; the measured candidates stay under 72 B.
- *Mitigation*: AC-2 keeps a smaller pure reduction and skips part 2; with none, the source stays at HEAD and the report lists every shape.

**Risk 2: a saving moves cost to the stack**
- *Risk*: merging functions or inlining widens a pack frame and the stack margin of 16 B is gone.
- *Mitigation*: AC-3 compares every stack figure at HEAD values; a shape that grows one is dropped.

**Risk 3: GCC and clang differ on the same source**
- *Risk*: the Mac build is not evidence for GCC 16 or avr-gcc 7.3 (loop 18).
- *Mitigation*: AC-9 runs `gcc:16` and the full arm stage.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Flash margin 384 B and stack margin 16 B | `_docs/AGENT_GOTCHAS.md` (loops 62, 57) | open | High |
| No 72 B saving may exist: then no `held_of` build, no pin raise | owner default, Phase 1 | open | Low |
| A saving below 72 B is kept when it is a pure reduction (assumption from "keep the saving regardless") | owner default, Phase 1 | accepted-risk | Low |
| GCC 16 `-Werror` and avr-gcc 7.3 build `pack.cpp` too | `AGENT_GOTCHAS.md` (loops 18, 44) | open | Medium |
