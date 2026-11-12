---
loop: 112
branch: dev
---

# All packages: a field after a repeat, or a repeat inside a list or dict element, packs bytes its own unpack refuses

**Task**: AZ-4206_repeat_followed_by_a_field
**Name**: All packages: a field after a repeat, or a repeat inside a list or dict element, packs bytes its own unpack refuses
**Description**: Probe the class in all nine packages with committed probes and give the owner one rule for it; the fix itself follows the owner's decision.
**Complexity**: 3 points (probe and decision)
**Dependencies**: None
**Component**: all nine packages (scheme build), probes under `fixtures/` or `scripts/`, findings under `_docs/06_metrics/`
**Tracker**: AZ-4206
**Epic**: AZ-4133

Owner decision 2026-11-12 (loop 111): found while scoping AZ-4205 and excluded from it, "its own cross-package task for a later loop". Not claimed by a loop: the next `/autodev` picks it from `todo/`.

## Problem

A `repeat` reads rounds until the buffer ends (README byte table: "the group until the buffer ends; no count"). A scheme with a byte-writing field after a repeat, or a repeat inside a list or dict element that is not the last thing read, builds and packs bytes its own unpack refuses. Measured in loop 111 on HEAD `05bdc52`:

- TypeScript, top level `repeat(0, u8 v), u8 x` with `v = [5, 6]`, `x = 9`: packs `01050609`; unpack `{ok: false, field: "x", needed: 1, left: 0}`.
- C# and TypeScript, list element row `(u8 mode, repeat(1, u8 v))` with items `{1, [5]}`, `{2, []}`: both pack `010200010502`; C# unpack `ShortPacket`, TypeScript `field mode, needed 1, left 0`.

The list already refuses a repeat as the whole element (`repeat is not a list element`), not a repeat inside an element row. The other seven packages were not probed.

## Outcome

- The owner sees, per package, which of these schemes build, what they pack and whether the package reads its own bytes, and decides one rule for all nine.

## Scope

### Included
- Committed probes (lesson loop 104: probes are committed, not scratch) of five shapes in all nine packages: (a) top-level field after a repeat; (b) repeat in a list element row; (c) repeat in a dict element; (d) repeat in a nested row followed by a field; (e) a repeat under `flags` or `when` followed by a field.
- A findings table `_docs/06_metrics/repeat-followed-by-field_<date>.md`: build / pack hex / unpack result per package and shape.
- A proposed rule with the evidence, and a check that no existing fixture or golden vector would be refused by it (expected 0).
- After the owner decides: the implementation task(s), via `/decompose` when 8 points or more.

### Excluded
- Changing the repeat wire format (no count is added).
- Implementing the rule in this task.

## Acceptance Criteria

**AC-1: Probe table**
Given the five shapes and the nine packages
When the committed probes run
Then the findings table records, for each of the 45 cells, build (yes / refused with message), pack hex, and unpack result.

**AC-2: One rule proposed**
Given the table
When the rule is proposed to the owner
Then it names one behavior for all nine packages (recommended: refuse at scheme build a repeat followed by a byte-writing field or placed inside a list or dict element), and lists the existing fixtures and golden vectors it would refuse (expected 0, measured).

**AC-3: Follow-up written**
Given the owner's decision
When the task closes
Then the implementation task(s) exist in `todo/` with tracker ids.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Each package's probe of the five shapes | Outcome recorded per cell, read from a run |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | All fixtures and golden vectors of the nine packages | Check each scheme against the proposed rule | Count of refused schemes recorded (expected 0) | Compatibility |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A build-time refusal may refuse a scheme someone uses only to pack (never unpack) | owner, 2026-11-12 (loop 112): "Refuse at build", chosen with the probe table and this cost named | resolved | Medium |

## Result (loop 112, 2026-11-12)

- AC-1: nine committed probes and a runner in `scripts/probes/repeat-followed-by-field/` (85 lines in one run, every `control` line `same`); the table is `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`. A sixth shape was added during the loop: two repeats in a row are read back as other values with no error, in all nine packages.
- AC-2: one rule proposed with the table; measured in TypeScript it refuses 0 shared fixtures, golden vectors or ring schemes and 4 of TypeScript's own test schemes (`rule-count/run.sh`). The owner chose "Refuse at build" from four options.
- AC-3: the rule is the contract `_docs/02_document/contracts/library/repeat-last.md`; the implementation is epic AZ-4209 with ten tasks in `todo/`, AZ-4210 (shared cases and README) and AZ-4211 to AZ-4219 (one per package), 29 points; `_docs/02_task_plans/repeat-must-be-last/` has the feature description and the scenarios.

