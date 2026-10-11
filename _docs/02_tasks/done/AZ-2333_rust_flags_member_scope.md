---
loop: 19
branch: dev
---

# Sibling `flags` members each get their own flag-byte scope in Rust, as in C++, TypeScript and Java

**Task**: AZ-2333_rust_flags_member_scope
**Name**: Rust per-member flag-byte scope
**Description**: Sibling `flags` members each get their own flag-byte scope in Rust, as in C++, TypeScript and Java.
**Complexity**: 2 points
**Dependencies**: AZ-2304 (done)
**Component**: rust
**Tracker**: AZ-2333
**Epic**: AZ-2069

## Problem

Owner decision 5 (assessment U3) of loop 19 (2026-10-11, option A, accepted as recommended). Rust shares one flag-byte scope across sibling `flags` members; C++, TypeScript and Java give each member its own. The same scheme can pack differently.

## Outcome

- Rust packs and unpacks sibling `flags` members with per-member scope, equal to the three other packages.

## Scope

### Included
- Probe row with two sibling `flags` members each with `flag_byte(0)`; change Rust; tests.

### Excluded
- Other packages (probe table only).

## Acceptance Criteria

**AC-1: sibling members have their own scope**
Given two sibling `flags` members each with a `flag_byte(0)` and bits
When packed by Rust
Then bytes equal to TypeScript, Java and C++

**AC-2: single member unchanged**
Given one `flags` member
When packed
Then bytes unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | sibling members | hex equal to reference |
| AC-2 | single member | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | sibling-flags ring | ring | identical hex | — |

## Constraints

- The reference hex comes from the TypeScript package (loop 18 table rule).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rust bytes change for sibling members that shared a byte (upgrade note) | owner decision 5 | resolved | Medium |

## Loop 19 result (2026-10-11)

Done in loop 19: Rust sibling `flags` members each have their own flag-byte scope; reference = TypeScript run on scheme S1.
