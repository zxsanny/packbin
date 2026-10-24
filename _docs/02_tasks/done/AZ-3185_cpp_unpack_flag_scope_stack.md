---
loop: 67
branch: dev
---

# C++ unpack: stack of a flag scope inside a times round

**Task**: AZ-3185_cpp_unpack_flag_scope_stack
**Name**: Cut the unpack stack of a flag scope inside a `times` round
**Description**: Measure shapes of the C++ unpack walk on a tree copy and keep one that lowers the Cortex-M4F stack of the 0x5e image by at least 64 B with no flash growth; otherwise record a measured no-go.
**Complexity**: 3 points
**Dependencies**: None
**Component**: C++ package core (`cpp/src/core`)
**Tracker**: AZ-3185
**Epic**: AZ-2645

## Problem

The Cortex-M4F unpack of scheme 0x5e, a flag-byte chain three `when`s deep inside a `times` round, needs 612 B of stack, the highest of any image (`stack_pin`, read on HEAD in loop 67: raw 676 B less 64 B meter). Each flag-scope level costs 80 B (`with_outer_flags` 32 B plus `unpack_children` 48 B). Parts with little RAM cannot take a deeper scheme, and the budget rose to 2,048 B only because the target parts have 8 KB or more. There is no named consumer today; the owner chose to measure.

## Outcome

- Either the 0x5e image unpacks in at most 548 B of stack with flash no higher than today, and `stack_pin` is lowered, or
- the table of shapes tried (stack and flash each) is recorded and the source stays at HEAD.

## Scope

### Included
- `cpp/src/core/unpack.cpp` (`Walk`, `with_outer_flags`, `unpack_children`, `unpack_items`, `unpack_one`) and, if a shape needs it, `pack.cpp`.
- Shapes measured on a tree copy first, the arm embedded stage (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`, about 3 minutes) for each.
- `stack_pin` in `cpp/embedded/lib.sh`, `AGENT_GOTCHAS.md` and the C++ description (AC-5 / AC-6).

### Excluded
- Wire format, public API, other seven packages, the session `open` frame (528 B, not on this chain).
- Raising `flash_pin`.

## Acceptance Criteria

See `_docs/02_task_plans/flag-scope-times-stack/acceptance_criteria.md` (AC-1 to AC-7); copied here:

**AC-1: Stack** — all-kinds image on `cpp-m4f`: deepest pack/unpack stack at most 548 B (612 B today).
**AC-2: Flash** — budget image at most 7,724 B (7,724 B today).
**AC-3: Same bytes and results** — host, `gcc:16`, ring and corpus pass with 0 changed expectations.
**AC-4: Other targets build** — avr-uno, m0plus, m3-qemu (290 of 290 vectors), s390x and examples as before.
**AC-5: Pin and notes** — when AC-1 and AC-2 are met, `stack_pin` is lowered to the measured figure and the notes state the figures and the winning shape.
**AC-6: No saving** — otherwise source at HEAD, shape table recorded in `AGENT_GOTCHAS.md`, pins not raised.
**AC-7: Scope** — 0 source changes outside `cpp/src/core` (and tests) and `cpp/embedded/lib.sh`.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | existing C++ unpack tests for `when` chains, flag bits, `flags` members, rounds | pass unchanged |
| AC-3 | a test of the same flag byte number in an outer and an inner scope (add only if not covered) | outer value back after the inner scope |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | HEAD with the change | `cpp-m4f` stage of the arm embedded stage | stack at most 548 B, flash at most 7,724 B | — |
| AC-3 | HEAD with the change | `scripts/loop-tests.sh` cpp, ring | pass, packets byte-equal | — |
| AC-4 | HEAD with the change | arm embedded stage, all targets | pass as before | — |

## Constraints

- Any edit to `unpack.cpp` or `pack.cpp` runs the arm embedded stage before the commit (`AGENT_GOTCHAS.md`).
- The core takes standard names only from `packbin/platform.hpp`; GCC 16 `-Werror` check with `docker run gcc:16 make test` before the batch commit.
- `make -C cpp clean` before switching between host and container builds.

## Risks & Mitigation

**Risk 1: no shape wins**
- *Risk*: the 80 B per level is the cost of state that has to live somewhere; folding the save into `unpack_children` grows every `unpack_children` frame (loop 56 measured a fold that cost 676 B).
- *Mitigation*: measure on a tree copy; AC-6 closes the loop as a measurement.

**Risk 2: flash grows**
- *Risk*: a stack saving spends the 468 B of flash margin.
- *Mitigation*: AC-2 forbids growth; a shape that needs more goes to the owner.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Any figure in an AC is read from a run on HEAD in this loop | read on `b478c53` | resolved | Medium |
| Flash margin may be spent by a stack saving | AC-2 | open | Medium |
| The loop may end as a measured no-go | AC-6 | accepted-risk | Low |
