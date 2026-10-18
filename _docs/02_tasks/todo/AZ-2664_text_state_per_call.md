---
loop: 36
branch: dev
---

# Compact text: encode state per pack call in Python and TypeScript

**Task**: AZ-2664_text_state_per_call
**Name**: Compact text: encode state per pack call in Python and TypeScript
**Description**: Compact text: encode state per pack call in Python and TypeScript
**Complexity**: 2 points
**Dependencies**: None
**Component**: compact-text
**Tracker**: AZ-2664
**Epic**: AZ-2645

## Problem

Python and TypeScript keep the last encoded text, its field and (TypeScript) scratch buffers in module-level variables.

## Outcome

- No encode state outlives or crosses a pack call.

## Scope

### Included
- Python `_text_encode.py`, `_pack.py`; TypeScript `text.ts`, `kinds.ts`, `pack-out.ts`; tests.

### Excluded
- Go, Swift, Rust, Java, C#, C++ (their caches are already per call or absent).

## Acceptance Criteria

**AC-1: State is per call**
Given two schemes and two interleaved pack calls with different texts
When each call packs
Then every result equals the reference bytes and no module-level variable holds a text or field (HD-1)

**AC-2: Repeated lone string stays fast**
Given a lone 65,535-character string under times with 256 rounds
When it is packed
Then it takes at most 1 s (HD-2)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | interleaved calls + module source check | reference bytes, no module-level cache |
| AC-2 | existing budget cases | pass |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond `problem.md` | — | resolved | Low |
