---
loop: 55
branch: dev
---

# Repeated-text speed headroom in seven packages

**Task**: AZ-3134_repeated_text_headroom
**Name**: Repeated-text speed headroom
**Description**: Python, TypeScript, Java, Go, Swift, Rust and C++ each have a test of one 65,535-character text in 200 rounds and finish in at most half the bound, locally and on CI.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `python/tests/test_compact_text.py`, new `go/` test file, `swift/Tests/PackbinTests/TextSpeedTests.swift`, and the existing tests of Java, TypeScript, Rust, C++ (print the times); a walker only if a package is above half
**Tracker**: AZ-3134
**Epic**: AZ-2645

## Problem

The C# test of this case failed on CI at 1.07 s against its 1.0 s bound (loops 49 and 53; fixed by AZ-2815). The other packages were never checked for headroom. CI figures (run 39548740720): Java 0.048 s, Rust 0.049 s, C++ 0.026 s (bound 3 s), TypeScript 0.268 s. Python prints no time. Go and Swift have no test of the 200-round case.

## Outcome

- Seven measured figures, each at most half the bound, in the loop record; a package above half is fixed or ticketed.

## Scope

### Included
- Python: print the pack and unpack seconds of the existing test; measure.
- Go, Swift: a test of exactly the 200 x 65,535-character case with the package's load-factor helper and a printed time.
- Java, TypeScript, Rust, C++: no change unless a figure is missing; read the CI figure after the push.
- If a package is above half: the AZ-2815 reuse (last round's encoded text) in that walker, bytes unchanged.

### Excluded
- Changing a nominal bound; C# (AZ-2815 done); any wire change.

## Acceptance Criteria

**AC-1: The case runs everywhere** (AC-D1)
Given one 65,535-character text in 200 rounds of `times`
When the seven packages pack and unpack it
Then each has a test of this case, the rounds equal the input, and the pack and unpack seconds are printed.

**AC-2: Headroom** (AC-D2)
Given the measured time on this Mac and on the next CI run
When compared with the bound (1 s; C++ 3 s)
Then pack plus unpack is at most 500 ms (C++ 1,500 ms) in all seven.

**AC-3: A package above half** (AC-D3)
Given a package above half
When the task closes
Then its walker reuses the last round's encoded text with `fixtures/text/vectors.txt` `enc` rows byte-equal, or a ticket for loop 56 is open and the owner told.

**AC-4: The table** (AC-D4)
Given AC-1 to AC-3
When the loop closes
Then the seven figures (local and CI) are in the loop record.

## Non-Functional Requirements

**Performance**: the nominal bounds stay; the load-factor helper of `AGENT_GOTCHAS.md` scales them.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | the seven packages' 65,535 x 200 tests | equal rounds, within half the bound |
| AC-3 | `enc` rows of any changed walker | unchanged bytes |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The new Go or Swift test may fail on its first run | a finding: fix or ticket, never loosen | open | Low |
