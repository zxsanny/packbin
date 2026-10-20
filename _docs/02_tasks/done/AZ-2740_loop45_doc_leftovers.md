---
loop: 46
branch: dev
---

# Loop 45 documentation leftovers: test-spec hex, traceability matrix size, size report header

**Task**: AZ-2740_loop45_doc_leftovers
**Name**: Loop 45 documentation leftovers
**Description**: Five test-spec cases show compact-format hex, the traceability matrix is back under 500 lines, and the size report header is written by its script.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `_docs/02_document/tests/`, `scripts/text/size_report.py`, `_docs/02_task_plans/compact-strings/size_report.md`
**Tracker**: AZ-2740
**Epic**: AZ-2645

## Problem

After AZ-2733: `blackbox-tests-02-strings-lists-dicts.md` FT-D-01 to FT-D-04 and FT-H-02 still hold old-format hex (the 103-byte user value, `000000000000`, the 58-byte nested value); `traceability-matrix.md` is 504 lines after the 29 new rows (soft cap 500); `size_report.md` has a hand-written header (date and sha256 of the recipe files), which a rerun of `scripts/text/size_report.py` drops (`handoff46.md`, "Small leftovers found in loop 45").

## Outcome

- No document of `_docs/02_document/tests/` holds old-format string bytes in these cases.
- A rerun of the size script reproduces the committed report.

## Scope

### Included
- The five cases: compact hex as the reference encoder `scripts/text/textfmt.py` and the schemas of the cases give it; the byte counts named in the text follow.
- The matrix: move rows to a side file named in the matrix, as loop 26 did, until the matrix is ≤ 500 lines.
- `size_report.py`: write the run date and the sha256 of the recipe files into the header.

### Excluded
- Any other test-spec case; any production code; changing a size figure.

## Acceptance Criteria

**AC-1: Hex** (TW-7)
Given the five cases FT-D-01 to FT-D-04 and FT-H-02
When the packets are recomputed with `scripts/text/textfmt.py`
Then the documented hex equals the recomputed hex and no old-format hex remains in `blackbox-tests-02-strings-lists-dicts.md`.

**AC-2: Matrix size** (TW-8)
Given `traceability-matrix.md`
When its lines are counted
Then it has at most 500 lines, the side file is linked from the matrix, and the number of rows in the two files equals the number before.

**AC-3: Report header** (TW-9)
Given `scripts/text/size_report.py`
When it runs twice on the same tree
Then `size_report.md` is identical except for the date line, and the header holds the date and the sha256 of the recipe files.

## Non-Functional Requirements

**Maintainability**
- Every file ≤ 500 lines (`quality-thresholds`).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | run `size_report.py` twice | same file except the date |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `scripts/text/textfmt.py` | recompute the five packets | equal to the documents | — |
| AC-2 | `wc -l`, a row count before and after | the matrix | ≤ 500 lines, no row lost | Maintainability |

## Constraints

- The parent does this task (documents and one script; disjoint from the test workers).

## Risks & Mitigation

**Risk 1: A byte count in the text changes**
- *Risk*: a case names "103 bytes" and the compact packet is shorter.
- *Mitigation*: recompute and correct the sentence in the same edit.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| None beyond the above | — | resolved | Low |
