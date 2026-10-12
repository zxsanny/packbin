---
loop: 21
branch: dev
---

# One slot-width rule for a round in all six packages

**Task**: AZ-2382_round_slot_width_rule
**Name**: One slot-width rule for a round in all six packages
**Description**: Rust, Python, TypeScript, Java, C# and C++ (where it counts) charge `maxSlots` for a round by the TypeScript rule, pinned in a hex reference table.
**Complexity**: 5 points
**Dependencies**: AZ-2329 (done), AZ-2354 (done); TypeScript first, then the other packages
**Component**: typescript (reference, first), python, java, csharp, rust
**Tracker**: AZ-2382
**Epic**: AZ-2069

## Problem

Owner decision U2 of loop 21 (assessment U2, option A). The slot width of a round differs between packages: Rust counts group, `flags` and flag-byte names, Python never counts an empty group and counts duplicate leaves twice, TypeScript counts an empty group. A packet one package packs at the limit another refuses.

## Outcome

- One rule, the TypeScript one, for what a round charges per round on pack and on unpack, written in the README limits section.
- TypeScript writes `_docs/03_implementation/reference_loop21_slots.md`: scheme, row, slots charged, outcome at the limit and one over (hex where bytes are written). The parent checks every AC against it before the other packages start.

## Scope

### Included
- Slot charging on pack and unpack in the five growable packages; C++ only if it charges slots at all (otherwise a note in the table).

### Excluded
- Wire bytes of accepted rows; limit defaults.

## Acceptance Criteria

**AC-1: rule table**
Given the reference schemes (empty group, duplicate leaves, `flags`, flag byte, split bit)
When a round runs at `maxSlots` and at `maxSlots + 1` in each package
Then every package gives the outcome in the reference table

**AC-2: pack and unpack agree**
Given a packet pack writes at exactly `maxSlots`
When the same package unpacks it
Then it unpacks (U1 closes the Python case)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | reference rows per package | same outcome and wording shape |
| AC-2 | pack at the limit then unpack | round-trips |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile `pack` stage | `pack_round_slots_*` rows (AZ-2394) | same refusal in each loader | — |

## Constraints

- Reference table before the other packages start.
- Wire bytes of accepted rows unchanged.
- File length at or under 500 lines.
