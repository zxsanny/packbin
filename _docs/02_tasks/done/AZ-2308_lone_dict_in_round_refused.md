---
loop: 18
branch: dev
---

# A lone dictionary for a Dict name in a round is refused like a lone collection

**Task**: AZ-2308_lone_dict_in_round_refused
**Name**: Lone dictionary in a round
**Description**: In a `repeat` or `times` round a single dictionary given for a `Dict` name is refused with a clear error naming the member, instead of being broadcast to every round; a dictionary value belongs in a list with one entry per round.
**Complexity**: 2 points
**Dependencies**: AZ-2182_csharp_nonlist_round_value (done)
**Component**: csharp, and typescript, python, java, rust where the probe shows a difference
**Tracker**: AZ-2308
**Epic**: AZ-2069

## Problem

Owner decision 6 of loop 18 (2026-10-10, option A; assessment E5). C# broadcasts a lone `IDictionary` for a `Dict` name to every round (it threw before loop 17), while a lone collection for `Bytes`, `Sized`, `Bits` or `Packed` is refused. The same scheme and row must give the same bytes or the same refusal in every package; the other packages were not probed.

## Outcome

- Every package refuses a lone dictionary for a `Dict` name in a round with an error naming the member, or the probe shows it already does.
- A list of dictionaries (one per round) keeps working everywhere.

## Scope

### Included
- First step: probe TypeScript, Python, Java and Rust (and C++ if it has rounds over dict names) with the same scheme and row, and write the table into the batch report.
- Then change C# and every package that differs from "refuse".

### Excluded
- A lone `string` for a `Utf8` name (it broadcasts everywhere and stays); error kind and label (C15).

## Acceptance Criteria

**AC-1: probe table**
Given one `times` scheme with a `Dict` name and a lone dictionary
When each package packs it
Then the batch report holds a table of the result per package (bytes or error)

**AC-2: a lone dictionary is refused everywhere**
Given the same scheme and a lone dictionary, in or outside a round for the C# typed and dictionary paths
When packed
Then every package refuses it with an error naming the member

**AC-3: per-round dictionaries still pack**
Given a list holding one dictionary per round
When packed and unpacked
Then every package gives the same bytes as today

## Non-Functional Requirements

**Compatibility**
- Only rows that were broadcast change; documented in the upgrade notes.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | lone dictionary in each changed package | error naming member |
| AC-3 | list of dictionaries | bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | existing round ring | rounds ring | unchanged | — |

## Constraints

- ADR-001: each package implements it itself. A package other than C# is edited only when the probe shows it differs, and by its own wave worker (separate directory).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The probe may show that other packages broadcast too, which widens the change to up to six packages (still 2 points per package at most); the parent splits the work by directory | coordinator | open | Medium |

## Loop 18 result (2026-10-10)

Done in loop 18 wave 1 (csharp, typescript, python, java, rust; C++ not applicable). Probe table in `batch_01_loop18_report.md`. A lone dictionary for a `Dict` name in `repeat`/`times` is refused naming the member; a list of one dictionary per round packs as before. Open: a lone byte buffer for `Bytes`/`Sized` is broadcast everywhere except C#.
