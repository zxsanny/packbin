---
loop: 46
branch: dev
---

# Criteria CS-5/CS-10 to 3,000 strings and 30,000 payloads, and the missing random and hostile text tests (CS-A5, CS-A10)

**Task**: AZ-2736_text_random_hostile_counts
**Name**: Random and hostile text counts (CS-A5, CS-A10)
**Description**: The text acceptance criteria say what the suites run (3,000 random strings, 30,000 hostile payloads per package) and every package runs that.
**Complexity**: 3 points
**Dependencies**: None
**Component**: tests of the Python, C#, Swift and Go packages; `compact-strings/acceptance_criteria.md`
**Tracker**: AZ-2736
**Epic**: AZ-2645

## Problem

CS-5 says 100,000 random strings and CS-10 says 100,000 hostile payloads per package. The suites run: random strings ts 4,000, java 20,000, rust 3,000, go 3,000, cpp 20,000 and none in Python, C# and Swift; hostile payloads ts 30,000, java 60,000, rust 30,000, go 20,000, cpp 100,000 and none in Python, C# and Swift (Swift has the time-bounded corpus fuzz only). The owner (2026-10-20, answer B) chose to change the criteria to what the suites can run and to add the missing tests.

## Outcome

- The two criteria state the counts the suites run, and the large run as a manual probe.
- Every package runs at least 3,000 random strings and 30,000 hostile payloads on every suite run.

## Scope

### Included
- `compact-strings/acceptance_criteria.md`: CS-5 → "3,000 random Unicode strings per package in the suites", CS-10 → "30,000 hostile payloads per package in the suites"; add the sentence that the 100,000 run of loops 35 and 41 (`fixtures/hostile/fuzz/`) is a manual probe before any decoder change; keep the 1 ms per 64 KiB bound with the note that loop 41 measured it in a probe.
- Python, C# and Swift: a random-string round-trip test and a hostile-payload test for the text codec, named as the package names its text tests.
- Go: the hostile-payload test rises from 20,000 to 30,000 payloads.

### Excluded
- A suite test of the 1 ms per 64 KiB bound (the owner chose option B; accepted risk).
- Raising TypeScript, Java, Rust or C++ (already at or above the counts).
- Any production code change.

## Acceptance Criteria

**AC-1: Criteria text** (TW-4)
Given `compact-strings/acceptance_criteria.md`
When CS-5 and CS-10 are read
Then they say 3,000 random strings and 30,000 hostile payloads per package, name the 100,000 run as a manual probe, and keep the 64 KiB bound with its basis.

**AC-2: Random strings** (TW-2)
Given a package of Python, C# or Swift
When its suite runs
Then at least 3,000 random Unicode strings (capitals, emoji, other scripts, combining marks, the empty string, a few of 65,535 bytes) round-trip through pack then unpack and mismatches are 0.

**AC-3: Hostile payloads** (TW-3)
Given a package of Python, C# or Swift, or Go
When its suite runs
Then at least 30,000 hostile payloads (random bytes and damaged valid packets) go through unpack, none crashes or hangs, and no output exceeds 6 bytes per payload byte plus 8.

**AC-4: Suite time**
Given an idle host
When the three new Python tests run
Then each of the Python, C# and Swift suites grows by at most 20 seconds in total; the figure is recorded in the batch report.

## Non-Functional Requirements

**Performance**
- The Python 30,000-payload test is the slowest; if the budget of AC-4 is missed, the payload sizes are shortened, never the count.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | Python, C#, Swift: 3,000 random strings | 0 mismatches |
| AC-3 | Python, C#, Swift, Go: 30,000 payloads | no crash, no hang, bound holds |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `fixtures/hostile/fuzz/corpus.txt` seeds | the four suites | green | Performance |

## Constraints

- A fixed seed per test (reproducible); each test file ≤ 500 lines; Python 3.10 or newer on `PATH` (`AGENT_GOTCHAS.md`).

## Risks & Mitigation

**Risk 1: A decoder bug shows up**
- *Risk*: 30,000 payloads in a new package find a crash.
- *Mitigation*: report it; do not weaken the test; the owner decides whether the fix joins this loop.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| 1 ms per 64 KiB has no suite test | owner chose option B | accepted-risk | Low |
