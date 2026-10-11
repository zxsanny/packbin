---
loop: 19
branch: dev
---

# A single byte buffer given for a `Bytes`/`Sized` name in a `repeat`/`times` round is refused with an error naming the member instead of being broadcast to every round

**Task**: AZ-2332_lone_bytes_in_round_refused
**Name**: Lone byte buffer in a round refused
**Description**: A single byte buffer given for a `Bytes`/`Sized` name in a `repeat`/`times` round is refused with an error naming the member instead of being broadcast to every round.
**Complexity**: 2 points
**Dependencies**: AZ-2182 (done)
**Component**: typescript, python, java, rust (C# already refuses, AZ-2182; C++ probe only)
**Tracker**: AZ-2332
**Epic**: AZ-2069

## Problem

Owner decision 4 (assessment U1) of loop 19 (2026-10-11, option A, accepted as recommended). TypeScript, Python, Java and Rust broadcast a lone byte buffer to every round; C# refuses it. The same scheme and row must give the same bytes or the same refusal.

## Outcome

- The four packages refuse a lone byte buffer for a `Bytes`/`Sized` name in a round, naming the member.
- A list of byte buffers (one per round) packs as before.

## Scope

### Included
- Probe table, then the refusal in the four packages; a test per package.

### Excluded
- A lone `string` for a `Utf8` name (broadcasts everywhere and stays).

## Acceptance Criteria

**AC-1: lone buffer refused**
Given a `times` scheme with a `Bytes` name and one buffer
When packed
Then error naming the member in TypeScript, Python, Java, Rust, C#

**AC-2: per-round buffers pack**
Given a list with one buffer per round
When packed
Then bytes unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | lone buffer | error |
| AC-2 | list of buffers | bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | existing rounds ring | rounds ring | unchanged | — |

## Constraints

- ADR-001: each package edits only its own directory.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Callers relying on the broadcast break (upgrade note) | owner decision 4, 2026-10-11 | resolved | Medium |
