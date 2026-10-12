---
loop: 22
branch: dev
---

# Rust accepts a short times list under flags like the other packages

**Task**: AZ-2414_rust_short_times_list_under_flags
**Name**: Rust accepts a short times list under flags like the other packages
**Description**: `times` with a short list under `flags` packs in TypeScript, Python, Java and C# (README Times, AZ-2248); Rust refuses the list form and accepts it.
**Complexity**: 2 points
**Dependencies**: none
**Component**: rust
**Tracker**: AZ-2414
**Epic**: AZ-2069

## Problem

Owner decision U15 of loop 22 (option B, accept in all). The README Times section (AZ-2248) lets a `times` with a short list under `flags` pack the given values and fill the missing rounds; Rust refuses the list form (AZ-2383's refusal is for `repeat` only).

## Outcome

- Rust packs the short `times` list under `flags` to the bytes TypeScript produces for the same row (reference: `_docs/03_implementation/reference_loop21_slots.md` section 3, rows for `times` under `flags`, plus a fresh TypeScript run recorded in the batch report).
- `repeat` short list under `flags` stays refused everywhere (AZ-2383).

## Scope

### Included
- Rust pack walk for `times` under `flags` (map and typed schemes); Rust tests.

### Excluded
- Other packages (they already accept); any change to `repeat`.

## Acceptance Criteria

**AC-1: accepted**
Given a `times(n, ...)` with a list shorter than n under `flags`
When packed in Rust
Then the bytes equal TypeScript's for the same row.

**AC-2: repeat still refused**
Given the AZ-2383 repeat row
When packed in Rust
Then refused as before.

**AC-3: round trip**
Given the packed bytes
When unpacked by Rust and by TypeScript
Then the same row.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | short list, empty list, full list | TypeScript hex |
| AC-2 | repeat row | error |
| AC-3 | unpack | equal row |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile/ring | `pack_times_short_list_flags` (AZ-2417) | same bytes in six | — |

## Constraints

- Wire bytes of rows Rust accepts today unchanged.
