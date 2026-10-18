---
loop: 37
branch: dev
---

# Compact text: research/bench.py reuses textfmt.py and fits 500 lines

**Task**: AZ-2676_bench_reuses_textfmt
**Name**: Compact text: research/bench.py reuses textfmt.py and fits 500 lines
**Description**: Compact text: research/bench.py reuses textfmt.py and fits 500 lines
**Complexity**: 2 points
**Dependencies**: None
**Component**: compact-text
**Tracker**: AZ-2676
**Epic**: AZ-2645

## Problem

`_docs/02_task_plans/compact-strings/research/bench.py` is 688 lines and holds its own parse of the vectors that `scripts/text/textfmt.py` already provides (review35 finding 6).

## Outcome

- One parser; research files of at most 500 lines each; the same numbers.

## Scope

### Included
- `bench.py` and new sibling research files in the same folder.

### Excluded
- `scripts/text/textfmt.py` behavior, the reference, any package.

## Acceptance Criteria

**AC-1: One parser, same numbers**
Given the current `bench.py` output
When the file is split and imports the parse from `scripts/text/textfmt.py`
Then no second parser remains, each file is at most 500 lines and the printed table equals the saved output of the old run (RL-3)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | diff of the old and new output | identical numbers |


## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond `problem.md` | — | resolved | Low |
