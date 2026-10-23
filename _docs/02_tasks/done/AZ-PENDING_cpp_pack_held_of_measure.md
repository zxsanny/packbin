---
loop: 61
branch: dev
---

# C++ pack side held_of: measure the flash and stack cost

**Task**: AZ-PENDING_cpp_pack_held_of_measure
**Name**: C++ pack side held_of: measure the flash and stack cost
**Description**: Build the pack-side counterpart of unpack's `held_of` (one function that decides skip, inline or flag-bit child for a `when` or a flag bit, asked by `pack_children` and `pack_one`), measure it on the Cortex-M4F image, keep it only when flash stays at or under the pin.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `cpp/src/core/pack.cpp`
**Tracker**: pending (Jira connector absent; payload in `_docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md`)
**Epic**: AZ-2645

## Problem

`pack_children` and `pack_one` each decide for a `when` or a flag bit whether its children are written; unpack has one function for it.

## Outcome

- The candidate is measured; the source changes only if flash is at most 8,032 B and no stack figure grows.

## Scope

### Included
- `cpp/src/core/pack.cpp`, the arm M4F figures.

### Excluded
- Unpack, other languages, the `Field` layout.

## Acceptance Criteria

See `_docs/02_task_plans/pack-held-of/acceptance_criteria.md` (AC-1 to AC-7).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Flash margin 160 B, stack margin 8 B | `_docs/AGENT_GOTCHAS.md` | open | High |

## Outcome of loop 61

AC-1 and AC-2 met, AC-3 failed for every shape, so the source stays at HEAD (AC-3 says drop). Cortex-M4F, `size14` probe delta over `baseline`, same container, same flags as `run.sh arm`:

| Shape | Flash | Stack pack (chain / flag chain / round chain) |
|-------|-------|------------------------------------------------|
| HEAD (baseline) | 8,032 B | 412 / 448 / 500 |
| A: `held_of` shared by both callers, `pack_children` enters a flag bit's child itself (patch `_docs/loops/loop61/pack_held_of_a.patch`) | 8,104 B (+72) | 404 / 440 / 492 (-8) |
| B: A with `held_of` inlinable | 8,104 B (+72) | 404 / 440 / 492 |
| C: only `pack_children` enters the flag bit child, no shared function | 8,076 B (+44) | 412 / 448 / 500 |
| D: shared `held_of`, `pack_children` unchanged for flag bits | 8,080 B (+48) | 412 / 448 / 500 |
| E: D with `When` and `FlagBit` merged into one `pack_one` case | 8,080 B (+48) | 412 / 448 / 500 |

The deepest stack the stage reports (504 B) is the unpack walk and does not move. The only stack gain is 8 B on the pack side with shape A, which is not the limiting side. No shape stays at or under the pin of 8,032 B, so none is kept; the 160 B margin is not spent.
