---
loop: 55
branch: dev
---

# C++ stack of a `when` chain whose bodies read a flag byte

**Task**: AZ-3141_cpp_when_chain_flag_byte_stack
**Name**: C++ `when` chain with flag bytes, stack
**Description**: A chain of three nested held `when`s that each hold a flag byte is measured on the Cortex-M4F image, stays within 512 B, and is guarded by the embedded stage.
**Complexity**: 2 points
**Dependencies**: AZ-3132 (done)
**Component**: `cpp/src/core/unpack.cpp` (only if a saving is needed), `cpp/embedded/common/all_kinds.cpp` and `.hpp`, `cpp/embedded/arm/ac2_main.cpp`, `cpp/embedded/common/vectors_main.cpp`, `cpp/tests/core/when_chain_host_tests.cpp`
**Tracker**: AZ-3141
**Epic**: AZ-2645

## Problem

Since AZ-3132, `pack_children` and `unpack_children` enter a held child `when` inside their own loop. On unpack a held `when` whose body reads a flag byte still goes through `unpack_one` and `with_outer_flags`, which keeps the flag scope; each such level costs about 130 to 144 B of stack again (loop 55 batch 01 discoveries). A chain of three such levels was never measured; the Cortex-M4F margin is 8 B.

## Outcome

- The figure of the flag-byte chain is measured, recorded, and at most 512 B; the image guards it.

## Scope

### Included
- A scheme with three nested `when`s, each holding a flag byte with a bit (shape of the existing `pack_late_when_in_bit_body` cases), as a third scheme in the all-kinds image with rows (all held; outermost clear; an inner clear), checked against the Python packets on host, M3/s390x and M4F.
- If the stack is above 512 B: a saving (for example the flag scope entered without a recursion through `unpack_one`), packets unchanged. A depth limit on schemes is a new refusal: stop and ask the owner.
- New figure in `AGENT_GOTCHAS.md` and the C++ description (parent writes them from the worker's report).

### Excluded
- Any wire change; the plain chain (AZ-3132, done); `repeat`/`times` bodies between levels.

## Acceptance Criteria

**AC-1: Equal to the reference** (AC-E1)
Given the flag-byte chain and rows all held / outermost clear / inner clear
When packed and unpacked in C++ and in Python
Then packets are byte-equal and unpacked rows equal; 0 differences.

**AC-2: Measured and within budget** (AC-E1)
Given the Cortex-M4F image with the flag-byte chain
When the arm embedded stage measures the deepest pack and unpack stack
Then the figure is recorded, is at most 512 B, and flash stays at most 8,192 B with `cpp-avr-uno` and `PACKBIN_NO_TEXT` inside their margins.

**AC-3: Over budget**
Given a figure above 512 B
When the task closes
Then it is brought to at most 512 B with packets unchanged, or the owner has decided; never a red stage.

## Non-Functional Requirements

**Compatibility**: no wire change; no packet that unpacked before stops unpacking.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | host comparison of the image rows against Python bytes | 0 differences |
| AC-2, AC-3 | arm embedded stage with the chain in the image | stack at most 512 B, flash at most 8,192 B |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The flag scope may need a recursion; margin is 8 B | measure first; saving before commit; no depth limit without the owner | open | Medium |
