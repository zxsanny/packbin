---
loop: 19
branch: dev
---

# When a split `flagByte` has a `when`/`times` bit whose condition or count is written between the byte and the bit, pack fails naming the member instead of silently dropping the body

**Task**: AZ-2331_split_form_pack_fails_loudly
**Name**: Split-form flag pack fails loudly
**Description**: When a split `flagByte` has a `when`/`times` bit whose condition or count is written between the byte and the bit, pack fails naming the member instead of silently dropping the body.
**Complexity**: 3 points
**Dependencies**: AZ-2120, AZ-2128 (done)
**Component**: csharp, typescript, python, java, rust, cpp
**Tracker**: AZ-2331
**Epic**: AZ-2069

## Problem

Owner decision 3 (review C3, assessment U7/U8) of loop 19 (2026-10-11, option A, accepted as recommended). A split `flagByte` decides its `when`/`times` bit where the byte is read, so a body whose condition or count is written later is dropped silently: pack cannot produce a packet its own unpack accepts. The same holds for a `times` whose count field was skipped and a false-condition `when` with a given body.

## Outcome

- Pack fails with an error naming the member in all six packages for those shapes.
- Shapes whose source is written before the byte pack as before.

## Scope

### Included
- Probe all six with the loop 18 reference rows (`flags_member_reference_cases_loop18.md`) and write the table.
- Raise the error in each package (C#: re-check in `PackFlagBit`).

### Excluded
- Moving the bit decision to the end of the group (changes the format).

## Acceptance Criteria

**AC-1: condition written after the byte**
Given a split `flagByte` and a `when` whose source is written between the byte and the bit, body given
When packed
Then error naming the member in all six

**AC-2: skipped count**
Given a `times` bit whose count field was skipped and values given
When packed
Then error naming the member

**AC-3: false condition with a body (decided 2026-10-11, after wave 1)**
Given a `when` bit whose condition is false (its source written before or after the flag byte) and a body given
When packed
Then the packet is written without the body and without an error (the loud cases are only those where the body would be written but the byte left its bit clear); the loop 18 reference rows and the combined `flags` form are unchanged

**AC-4: source before the byte still packs**
Given the reference rows with the source before the byte
When packed
Then bytes unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1..3 | three hostile shapes | error in 6 packages |
| AC-4 | reference rows | bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1..3 | hostile `pack` stage | three cases replayed by six packages | error | — |

## Constraints

- ADR-001: each package implements it itself; the reference rows come from loop 18 wave 3.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A package may already refuse one shape; the probe decides the per-package work | coordinator | open | Low |

## Decision record

2026-10-11 (owner, after wave 1): option A. Loud only when the body WOULD be written (condition true, count above 0, or count never written) and the byte left the bit clear. Wave 1 as built: Java, TypeScript, C++ already match; C# and Rust were loud on every false-condition row and Python loud on a false condition with the source after the byte; the three are relaxed in the follow-up pass.

## Loop 19 result (2026-10-11)

Done in loop 19. AC-3 decided by the owner after wave 1 (option A): a false condition packs silently; loud only when the body would be written but the byte left the bit clear. Review fixes: C# count-0 regression and Flags case, TypeScript `when` case, Python several `when`s, Rust absent source silent, Java FLAGS recursion, C++ source inside the bit body. Hostile cases `pack_split_*`.
