---
loop: 55
branch: dev
---

# C++ `when` chain stack on the Cortex-M4F image

**Task**: AZ-3132_cpp_when_chain_stack
**Name**: C++ `when` chain stack
**Description**: The stack cost of a source three `when`s deep is measured on the Cortex-M4F image, stays within 512 B, and is guarded by the embedded stage.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `cpp/src/core/values.cpp` (only if a saving is needed), `cpp/embedded/common/all_kinds.cpp` and `.hpp`, `cpp/embedded/arm.sh`, margins in `_docs/AGENT_GOTCHAS.md` and `_docs/02_document/components/05_cpp_package/description.md`
**Tracker**: AZ-3132
**Epic**: AZ-2645

## Problem

`when_matches` and `source_skipped` call each other once per enclosing `when` of a source (loop 54, review #1). The all-kinds image has one `when` and no chain, so its 504 B of the 512 B budget (8 B margin) does not show what a chain costs. A scheme with a source three `when`s deep may exceed 512 B on the device without any stage saying so.

## Outcome

- The chain figure is measured, written down, and at most 512 B.
- The all-kinds image holds the chain, so the stage guards it from now on.

## Scope

### Included
- A scheme with a source 3 `when`s deep (`u8 m; when(m==1){ u8 k1; when(k1==1){ u8 k2; when(k2==1){ u8 k3; when(k3==1){ u8 b } } } }` or an equal shape) in the all-kinds image, a row for it in the image's row list and its host comparison; bytes checked against the Python package.
- If the stack is above 512 B: a saving elsewhere in `cpp/src/core` first, or a non-recursive check with packets unchanged. A depth limit on schemes is a new refusal: stop and ask the owner.
- New margins in `AGENT_GOTCHAS.md` and the C++ package description.

### Excluded
- Any wire change or new public API; row U24; the bool/group probe (AZ-3133).

## Acceptance Criteria

**AC-1: Measured** (AC-A1)
Given the Cortex-M4F image with the 3-deep chain
When the arm embedded stage measures the deepest pack and unpack stack
Then the figure is recorded and is at most 512 B.

**AC-2: Guarded** (AC-A2)
Given the all-kinds image after this task
When the embedded stage builds it
Then it contains the chain; flash is at most 8,192 B; `cpp-avr-uno` and `PACKBIN_NO_TEXT` stay inside their recorded margins.

**AC-3: Equal to the reference** (AC-A3)
Given the chain scheme and the rows all true / outermost false / inner false
When packed and unpacked in C++ and in Python
Then packets are byte-equal and rows equal; 0 differences.

**AC-4: Over budget** (AC-A4)
Given a figure above 512 B
When the task closes
Then the stack is brought to at most 512 B with packets unchanged, or the owner has decided; never a red stage.

## Non-Functional Requirements

**Performance**: no C++ speed-suite case gets slower.
**Compatibility**: no wire change; no packet that unpacked before stops unpacking.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | arm embedded stage with the chain in the image | stack at most 512 B, flash at most 8,192 B |
| AC-3 | host comparison of the image rows against Python bytes | 0 differences |
| AC-4 | stage run before and after a saving | margins recorded |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Margin is 8 B; the chain may not fit | measure first; saving before the commit | open | Medium |
