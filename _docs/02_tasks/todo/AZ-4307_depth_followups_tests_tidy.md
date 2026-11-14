---
loop: 127
branch: dev
---

# Depth limit follow-ups: tests and tidy

**Task**: AZ-4307_depth_followups_tests_tidy
**Name**: Depth limit follow-ups: tests and tidy
**Description**: Four small items of the loop 126 review in four packages.
**Complexity**: 3 points
**Dependencies**: AZ-4294 to AZ-4303 (done)
**Component**: csharp, dart, typescript, python, go, java
**Tracker**: AZ-4307
**Epic**: AZ-4133

## Problem
1. `csharp/tests/HostilePackVectorTests.cs` is 509 lines (soft cap 500).
2. Dart stopped counting a flag bit as a level in loop 126 but no test pins it (the chain tests use `flags(0, [...])`).
3. TypeScript `elementOf` runs the depth walk on every `list()` / `dict()` call (quadratic, bounded by 257); Python `_finish_round` imports `_validate_depth` inside the function on every call.
4. The Go, Java and C# walk-timing tests (AZ-4257 / AZ-4259) build 250 levels through the whole build, the large chain only on the walk.

## Outcome
- The C# file is split by responsibility into files under 500 lines, same tests.
- A Dart test: 129 `flags` each holding a flag-byte bit build (and 257 flags refuse); where the Dart API cannot make a flag-byte bit chain, say so and test the nearest form.
- TypeScript measures a list element once per scheme (or only when the element itself is a container; no change of what is refused); Python imports at module level (move the function or the shared helper so there is no cycle).
- A whole-build timing guard at 250 levels in Go, Java and C# for a chain of nested whens and of nested groups, with a bound that fails on a quadratic build step (measure the figure on this Mac, bound it at the project's load-aware helper where the package has one).

## Acceptance Criteria

**AC-1** Given the C# tests, when run, then the count of tests is unchanged and no file is over 500 lines.
**AC-2** Given the Dart flag-bit chain, when built, then 129 build and 257 refuse; the test fails if `flagBit` counts as a level (proved by putting it back by hand once).
**AC-3** Given the TypeScript and Python packages, when their suites run, then the depth tests pass unchanged and the sources are as described.
**AC-4** Given the three timing guards, when run, then they pass at the measured figure and fail with a quadratic stand-in (prove once by hand for one package).

## Constraints
Owns the package folders named only. Existing tests keep their assertions.

## Flagged concerns
none
