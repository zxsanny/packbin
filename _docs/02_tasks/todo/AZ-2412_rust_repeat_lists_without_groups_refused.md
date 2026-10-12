---
loop: 22
branch: dev
---

# Rust refuses per-name repeat lists given without __repeat__ groups

**Task**: AZ-2412_rust_repeat_lists_without_groups_refused
**Name**: Rust refuses per-name repeat lists given without __repeat__ groups
**Description**: Rust packs `01` and silently drops per-name lists given for a `repeat` when no `__repeat__` groups are given; it refuses with a named error.
**Complexity**: 2 points
**Dependencies**: none
**Component**: rust
**Tracker**: AZ-2412
**Epic**: AZ-2069

## Problem

Owner decision U13 of loop 22 (option A). In Rust the rounds of a `repeat` are `__repeat__` groups; a row that gives the per-name lists (`{n:[1,2], x:[5,6]}`) without groups packs the count and drops the lists. The other five packages pack the lists as rounds. Dropping given values is the class of defect AZ-2383/AZ-2386 removed elsewhere.

## Outcome

- Rust `pack` refuses a row that gives a repeat member's name (a list value) with no `__repeat__` groups, naming the member and telling the caller to use `__repeat__` groups.
- A row with groups, or with no value for the member, packs exactly as before.

## Scope

### Included
- The Rust pack walk (map and typed scheme paths), its message, and the batch-report note on what the five other packages do for the same row (probe row recorded for the hostile spec AZ-2417).

### Excluded
- Other packages; unpack.

## Acceptance Criteria

**AC-1: refused**
Given a `repeat` scheme and a row with per-name lists and no `__repeat__`
When packed in Rust
Then an error naming the member; no bytes.

**AC-2: groups and absent pack unchanged**
Given the same scheme with `__repeat__` groups, and with nothing given for the members
When packed
Then bytes as at HEAD.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | one list, two lists, lone value | error |
| AC-2 | groups; absent | HEAD bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_repeat_lists_without_groups` (AZ-2417) | refused in Rust; the five others pack the lists (rule table says so) | — |

## Constraints

- README Rounds section states that Rust takes rounds as groups only (step 13).
