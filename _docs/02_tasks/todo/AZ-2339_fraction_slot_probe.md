---
loop: 19
branch: dev
---

# Probe what TypeScript, Python, Java, Rust and C++ do with a fraction in `u2`, `bits` and `packed` slots and write the per-package table

**Task**: AZ-2339_fraction_slot_probe
**Name**: Fraction slot probe
**Description**: Probe what TypeScript, Python, Java, Rust and C++ do with a fraction in `u2`, `bits` and `packed` slots and write the per-package table.
**Complexity**: 1 points
**Dependencies**: AZ-2309 (done)
**Component**: typescript, python, java, rust, cpp (probe, no code change)
**Tracker**: AZ-2339
**Epic**: AZ-2069

## Problem

Owner decision 13 (assessment U11) of loop 19 (2026-10-11, option A, accepted as recommended). C# is strict about fractions in those slots (AZ-2309); the other five were never probed with the same rows.

## Outcome

- A table per package (bytes or error) in the batch report, and follow-up specs for the loop 20 handoff.

## Scope

### Included
- Probe rows and the table.

### Excluded
- Any code change.

## Acceptance Criteria

**AC-1: probe table exists**
Given the AZ-2309 rows with a fraction in u2, bits and packed slots
When each package packs them
Then the table lists bytes or error per package and row

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | probe | table |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | none | report | table present | — |

## Constraints

- Read-only for source; probes run in each package's own test directory and are not committed unless they pin a decision.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Follow-up specs are loop 20 work | coordinator | resolved | Low |
