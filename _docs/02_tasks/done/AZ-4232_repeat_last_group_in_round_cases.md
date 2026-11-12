---
loop: 113
branch: dev
---

# Shared: hostile cases for a repeat inside a group of a round, replayed by all nine packages

**Task**: AZ-4232_repeat_last_group_in_round_cases
**Name**: Shared: hostile cases for a repeat inside a group of a round, replayed by all nine packages
**Description**: Two shared `construct` cases pin that a `repeat` inside a nested row or group that sits inside a `repeat` or `times` round is refused when the scheme is built, and each of the nine loaders replays them.
**Complexity**: 3 points
**Dependencies**: AZ-4210_repeat_last_hostile_cases_and_readme
**Component**: fixtures/hostile and the nine hostile loaders
**Tracker**: AZ-4232
**Epic**: AZ-4209

Written in loop 113 (2026-11-12) by the feature assessment (round 1, gap D1: `_docs/loops/loop113/assessment113.md`).

## Problem

Dart and C++ built a `repeat` inside a nested row or group that sits inside a `repeat` or `times` round, packed it, and read back other values with no error (`01 05 06 07` for two outer rounds read as one round `[5, 6, 7]`; `01 02 05 06 07` read as `[5, 6, 7]` and `[]`). Loop 113 fixed both, each with its own tests. The other seven packages refuse the scheme by their nesting rule or the new rule, but only an uncommitted probe shows it, so no shared case stops a regression there.

## Outcome

- `fixtures/hostile/cases.txt` holds `construct_repeat_in_group_in_repeat_round` and `construct_repeat_in_group_in_times_round`, each `scheme_error`, with a section each in `fixtures/hostile/README.md`.
- Each of the nine loaders writes both schemes by hand and expects the refusal it already gives.

## Scope

### Included
- The two cases, their README sections and the counts (90 cases; 26 `construct`): the parent made these in the same commit as this spec.
- One hand-written scheme per package and per way the package builds a scheme (map and typed rows where the loader has both; Rust map form and heap-free API; C++ run-time and `constexpr`), in each hostile loader.

### Excluded
- Any change of the rule or of a refusal text; `times` inside a round; the other package tests (they already pin the shape or are not needed).

## Acceptance Criteria

**AC-1: The cases are shared**
Given `fixtures/hostile/cases.txt`
When `check-cases.sh` and `cases.test.sh` run
Then both pass with 90 cases and each new id has its section in `fixtures/hostile/README.md`

**AC-2: Every loader replays them**
Given the nine hostile loaders
When each runs
Then each new id is a scheme error built by a hand-written scheme with the whole refusal text the package already gives (or `SchemeInvalid` at the id of the inner repeat in C++ and in the heap-free Rust API); none is skipped silently

**AC-3: Nothing else changes**
Given the fixtures, golden vectors and the packages' own suites
When the hostile tests of the nine packages run
Then they pass and no packet, fixture or golden vector byte differs

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `check-cases.sh`, `cases.test.sh` | 90 cases ok, the corrupted copies still fail |
| AC-2 | each loader, both new ids | refused with the package's own text or status |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | the committed fixtures | the hostile tests of each package | pass | Compatibility |

## Constraints

- The cases are bytes-free `construct` cases; each package writes the schemes by hand (ADR-001).
- The probe of loop 113 gave the answer per package (see the assessment): TypeScript, C#, Python, Go, Swift refuse by the nesting rule text; Java by the repeat-last round text; Rust map form `repeat at id <a> is inside a repeat or times round; a round keeps no inner repeat rounds` (R1), `nostd` `SchemeInvalid`; Dart by the repeat-last round text; C++ `SchemeInvalid`.

## Risks & Mitigation

**Risk 1: A loader fails on the new ids until its worker lands**
- *Risk*: each loader fails loudly on an id it has no scheme for.
- *Mitigation*: the three workers run in the same turn and the loop's one total test run is the gate.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | — | — |

## Document Dependencies

- `_docs/02_document/contracts/library/repeat-last.md` (rule 3, version 1.0.2).
- `_docs/loops/loop113/assessment113.md` (gap D1).
- `fixtures/hostile/README.md` (the two new sections).
