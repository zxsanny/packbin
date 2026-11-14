---
loop: 126
branch: dev
---

# Shared: hostile cases, contract and README text for the scheme depth limit (256)

**Task**: AZ-4294_scheme_depth_hostile_cases_and_readme
**Name**: Shared: hostile cases, contract and README text for the scheme depth limit (256)
**Description**: `fixtures/hostile` gains the four depth cases, the root README states the limit, and the probe README says what the probe shows after the change, so the nine package tasks replay one file and quote one text.
**Complexity**: 2 points
**Dependencies**: None
**Component**: fixtures/hostile, README (docs), scripts/probes/scheme-depth/README.md
**Tracker**: AZ-4294
**Epic**: AZ-4133

Owner decision D18 (2026-11-14): "Shared limit (256)". Contract: `_docs/02_document/contracts/library/scheme-depth.md` (1.0.0, written in this loop).

## Problem

The limit has no shared fixture and the README says nothing about how deep a scheme may be. Without shared cases each package would pin its own reading of "depth" and its own text.

## Outcome

- `cases.txt` holds `construct_depth_when_257`, `construct_depth_group_257` (`construct`, `scheme_error`) and `pack_depth_when_256` (`010107`), `pack_depth_group_256` (`0107`) (`pack`, `bytes`), each with its section in `fixtures/hostile/README.md`.
- The root README states the limit and the refusal text where it lists the scheme mistakes refused at build, and tells an upgrader what stops building.
- The contract names its producer and consumers by ticket (done when this task is written).

## Scope

### Included
- `fixtures/hostile/cases.txt`, `fixtures/hostile/README.md` (sections, `Run by` / `Not run by`, the notation of a chain written by a loop).
- `README.md`: the scheme-mistakes list under Untrusted input, "If you upgrade", and any sentence that says a scheme can nest without limit.
- `_docs/02_document/module-layout.md`: the case count of `fixtures/hostile`.
- `scripts/probes/scheme-depth/README.md`: a State line for the loop 126 result.

### Excluded
- The checks in the packages and the loaders (the nine package tasks).
- Any change to the 79 existing cases; the wire format.

## Acceptance Criteria

**AC-1: The refused shapes are shared cases**
Given the contract's two refused chains
When `cases.txt` is read
Then `construct_depth_when_257` and `construct_depth_group_257` are `construct` cases with outcome `scheme_error` and a section that writes the chain in the file's notation (the chain length and the innermost `u8 b` are the whole scheme) and names the packages whose group form differs

**AC-2: The shapes that keep building are shared cases**
Given the contract's two chains at 256
When `cases.txt` is read
Then `pack_depth_when_256` is a `pack` case with bytes `010107` and `pack_depth_group_256` one with bytes `0107`, each with `Scheme`, `Row`, `Run by` and `Not run by` lines

**AC-3: The file stays valid**
Given the older cases
When `check-cases.sh` and `cases.test.sh` run
Then both pass and the older lines are byte-identical

**AC-4: The README states the limit**
Given the README sections on Untrusted input and upgrading
When a reader looks for how deep a scheme may be
Then the limit (256 levels), the refusal text of the contract and what stops building are stated

## Non-Functional Requirements

**Compatibility**
- No existing case changes; a loader that does not know a new id fails loudly, so this task lands before or together with the package tasks.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | `check-cases.sh` on the new lines | valid: id, stage, outcome, hex or `-`, a section per id |
| AC-3 | `cases.test.sh` | passes; a corrupted copy of a new line fails the check |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | the committed file | `bash fixtures/hostile/check-cases.sh` and `bash fixtures/hostile/cases.test.sh` | both pass | Compatibility |
| AC-4 | the README | the Swift README snippet test and the C# README example build | pass | — |

## Constraints

- Cases are the contract's; the file holds bytes and outcomes only, each package writes the chains by hand with a loop (ADR-001).
- The README is one file: this task makes every README edit of the feature, the package tasks make none.

## Risks & Mitigation

**Risk 1: A package suite is red between this task and its own task**
- *Risk*: each loader fails on an id it has no chain for.
- *Mitigation*: one loop, this task first; the total test run is the gate.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | | | |

## Contract

This task produces the shared cases of `_docs/02_document/contracts/library/scheme-depth.md`. Consumers (AZ-4295 to AZ-4303) MUST read that file, not this task spec, to discover the rule.
