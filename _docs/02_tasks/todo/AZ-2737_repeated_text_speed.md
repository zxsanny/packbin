---
loop: 46
branch: dev
---

# Repeated 65,535-character text speed test in Java, C#, Rust and C++ (CS-D7)

**Task**: AZ-2737_repeated_text_speed
**Name**: Repeated large text, 1 s test (CS-D7)
**Description**: A 65,535-character text written in 200 rounds packs and unpacks in about a second in Java, C#, Rust and C++, as in Python and TypeScript.
**Complexity**: 2 points
**Dependencies**: None
**Component**: tests of the Java, C#, Rust and C++ packages
**Tracker**: AZ-2737
**Epic**: AZ-2645

## Problem

When one 65,535-character text is written in 200 or more rounds, Python, TypeScript, Go and Swift keep the encoded bytes of the first round; Python and TypeScript have a test that it finishes within one second (HD-2). Java and C# have no such shortcut and no package of Java, C#, Rust or C++ has a test of the case, so it is unknown whether they finish in a second (loop 45 assessment, row CS-D7). The owner (2026-10-20, answer A) asked for the test first, and a fix only if a test fails.

## Outcome

- The four packages have the test and it passes, or the walker of a failing package is fixed.

## Scope

### Included
- One test in each of Java, C#, Rust and C++ with the setup of the Python/TypeScript HD-2 test (one text of 65,535 characters in a `times` or `repeat` group of 200 rounds); the unpacked rounds are compared with the input.
- Only if a package misses 1 s nominal: a change of that package's pack walker so the repeated text is not encoded again in each round, with the packed bytes of every `enc` row unchanged. Result: Java missed (2.9 s) and keeps the last text's encoded field inside one pack call (`ByteSink.writeText`).

### Excluded
- A shared rule in the walkers of all eight packages (option B of the assessment).
- Any file under `cpp/src`, `cpp/include` or `cpp/embedded` (C++ is tested through `cpp/tests` only). C++ missed 1 s (1.9 s on gcc:16 at load factor 1.00): the owner chose (2026-10-20) a 3 s nominal bound for the C++ test and AZ-2742 for a later shortcut.

## Acceptance Criteria

**AC-1: One second** (TW-5)
Given a scheme with a text field in a group repeated 200 times and a text of 65,535 characters
When the text is packed and unpacked
Then the unpacked rounds equal the input and the time is at most 1 second nominal times the package's load factor (C++: 3 seconds nominal, owner 2026-10-20).

**AC-2: Bytes unchanged**
Given a package whose walker was changed because AC-1 failed
When the `enc` rows of `fixtures/text/vectors.txt` run
Then every packed byte equals the reference, and the other seven packages' fixtures are unchanged.

## Non-Functional Requirements

**Performance**
- The nominal bound is 1 s; the timing helper of `_docs/AGENT_GOTCHAS.md` scales it.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | Java, C#, Rust, C++: 65,535 characters × 200 rounds | equal rounds, within the bound |
| AC-2 | the `enc` rows of any walker change | unchanged bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the HD-2 setup | the four suites | green | Performance |

## Constraints

- The packet size limit applies; build the scheme and the text as the Python/TypeScript HD-2 test does. C++ checks with the `gcc:16` container (`AGENT_GOTCHAS.md`).

## Risks & Mitigation

**Risk 1: A package is slow**
- *Risk*: Java or C# encodes the text 200 times and misses 1 s.
- *Mitigation*: fix the walker of that package only; report the other seven as unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A slow package needs a sixth per-codec shortcut (loop 35 review finding 3) | owner answer A: test first, decide after. Java got one (`ByteSink`); C++ stays at 3 s with AZ-2742 | accepted-risk | Medium |
