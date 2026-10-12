---
loop: 22
branch: dev
---

# Lower the default maxSlots to bound unpack memory in the five growable packages

**Task**: AZ-2415_default_max_slots_lowered
**Name**: Lower the default maxSlots to bound unpack memory in the five growable packages
**Description**: The default `maxSlots` (4 194 304) lets a 4.3 MB packet cost 548 MB (Python) to 1 072 MB (TypeScript) on unpack; the default drops to 1 048 576 (about a quarter) with a measured memory A/B.
**Complexity**: 3 points
**Dependencies**: none
**Component**: typescript (reference), python, java, csharp, rust
**Tracker**: AZ-2415
**Epic**: AZ-2069

## Problem

Owner decision U17 of loop 22 (option A; finding F10, Medium). A slot costs memory on unpack, differently per package (loop 21 lesson), so `maxSlots` times the per-slot cost is a memory ceiling. The owner wants the default lowered and a spec before the Go package, so Go copies one limit.

## Outcome

- Default `maxSlots` is 1 048 576 in TypeScript (`DefaultMaxSlots`), Python (`DEFAULT_MAX_SLOTS`, `Scheme.DEFAULT_MAX_SLOTS`), Java (`DEFAULT_MAX_SLOTS`), C# (`DefaultMaxSlots`) and Rust (`DEFAULT_MAX_SLOTS`); C++ is fixed-size and unchanged (probe: record its limit).
- Every message that quotes the old number, and every test and hostile case that sat between 1 048 576 and 4 194 304 slots, is updated; `maxRounds` (65 535) and `maxBytes` unchanged.
- A worst-case memory A/B (the 4.3 MB packet shape of F10, before and after, per package) is written into the batch report; the worker states the new ceiling per package. If any package's new worst case exceeds 400 MB the worker reports it before the parent decides on a lower value.
- The README Limits text and the upgrade notes carry the new default (step 13).

## Scope

### Included
- The default constants, tests that pin them, the `pack_slots_over_limit` family of hostile message texts (`hostile.test.ts`, `refusals.py`/`hostile_refusals.py`, `HostileRefusals.java`, `refusals.rs`, C# equivalents) and fixture cases whose slot totals depend on the default.

### Excluded
- Changing the slot charge rule; `maxRounds`; the ability to raise the limit per scheme (stays).

## Acceptance Criteria

**AC-1: new default**
Given a scheme built with no limits
When its limits are read
Then maxRounds 65 535, maxSlots 1 048 576 in five packages.

**AC-2: bound**
Given a packet of the F10 shape (4.3 MB, rounds with the cheapest body)
When unpacked with default limits
Then refused with the slots message naming 1 048 576; peak memory in each package is at most a quarter of the pre-change worst case (measured, in the report).

**AC-3: raising still works**
Given a scheme with limits raised to 4 194 304
When the old worst packet is unpacked
Then it unpacks (as before the change).

**AC-4: no other change**
Given the package suites, hostile and golden fixtures
When run
Then green after the text and threshold updates.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | default constants per package | 1 048 576 |
| AC-2 | F10 packet | refused; memory in report |
| AC-3 | raised limit | unpacks |
| AC-4 | suites | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | hostile `unpack`/`pack` stage | slots-over-limit cases (AZ-2417 updates the numbers) | refused in six | memory ceiling |

## Constraints

- TypeScript lands first and writes the memory A/B method into `_docs/03_implementation/reference_loop22.md`; the other four reuse it. C++ is not edited unless its limit differs (flash margin 40 B).
