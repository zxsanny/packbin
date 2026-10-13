---
loop: 22
branch: dev
---

# Python repeat lists of unequal length pack like the other five packages

**Task**: AZ-2413_python_repeat_lists_of_any_length
**Name**: Python repeat lists of unequal length pack like the other five packages
**Description**: Python requires equal lengths for `repeat` lists (a lone value, a short required list, a `when` list outside `flags`); it follows the rule the other five packages share.
**Complexity**: 3 points
**Dependencies**: none
**Component**: python (change); typescript, java, csharp, rust (probe only)
**Tracker**: AZ-2413
**Epic**: AZ-2069

## Problem

Owner decision U14 of loop 22 (option A, align Python to the five). A lone value for a repeat member, a required list shorter than the longest, and a `when` list outside `flags` are refused in Python and packed by the other five. The five packages' rule: the round count is the longest list; a lone value broadcasts; a short required list ... (the worker records the exact rule per case from a TypeScript probe before changing Python, because the handoff names the shapes, not the bytes).

## Outcome

- A probe table in the batch report: each of the three shapes, the five packages' outcome (hex or error), one row per shape with-value and short.
- Python packs those rows to the same bytes as the five; where the five themselves differ, the worker stops and reports the row (no guess).
- Rows Python packs today keep their bytes.

## Scope

### Included
- Python `_pack.py` repeat handling and the messages that go away; Python tests.

### Excluded
- Unpack; the other five packages (probe only; a differing row becomes a question, not a change).

## Acceptance Criteria

**AC-1: probe table**
Given the three shapes
When run through TypeScript, Java, C#, Rust
Then the table records bytes or errors; all agree, else the worker stops.

**AC-2: Python matches**
Given the agreed rows
When packed with Python
Then the same bytes; Python unpack of those bytes gives back the rows the others unpack.

**AC-3: no regression**
Given the existing Python suite and the golden/ring fixtures
When run
Then all pass.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1/2 | each shape, with-value and short | bytes equal the table |
| AC-3 | suite | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | hostile/ring | `pack_repeat_unequal_lists` (AZ-2417) | same bytes in six | — |

## Constraints

- Wire bytes of rows accepted today unchanged. Python needs 3.10+ (per-worker venv).

## Parent decision after the TypeScript reference (2026-10-12)

Reference: `_docs/03_implementation/reference_loop22.md` section 3b. TypeScript packs the **lone value** (R1, R2a, R2b) and the **`when` list outside `flags`** (R3a to R3c, R3e); it **refuses** a short required list (R2d to R2f, `missing {name}`), so that shape is not "packed by the other five". Python changes for the lone value and the `when` list only; the short required list keeps the TypeScript rule (refused). The Java, C# and Rust workers record their outcome for rows R2d to R2f; a package that packs them is a question for the parent, not a change.

## Loop 22 result

Python no longer requires equal lengths for `repeat` lists: a lone value (R1, R2a, R2b) and a `when` list outside `flags` (R3a to R3c, R3e, R3f) pack to the TypeScript bytes; a short required list (R2d to R2f, R3d) is still refused naming the member (`KeyError 'missing field b'`). Java, C# and TypeScript probed: same outcomes. Tests: `test_loop22_parity.py` U14 block, three rewritten pins. Bound unchanged: `maxRounds`, `maxSlots`, `maxBytes` still apply.
