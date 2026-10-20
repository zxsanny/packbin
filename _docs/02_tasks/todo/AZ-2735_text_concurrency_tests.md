---
loop: 46
branch: dev
---

# Text concurrency test in C#, Java, Rust, Go and Swift (CS-S3)

**Task**: AZ-2735_text_concurrency_tests
**Name**: Text concurrency test (CS-S3)
**Description**: Eight concurrent workers pack and unpack different texts with one scheme in five packages, and every result is the reference bytes or the worker's own input.
**Complexity**: 3 points
**Dependencies**: None
**Component**: tests of the C#, Java, Rust, Go and Swift packages
**Tracker**: AZ-2735
**Epic**: AZ-2645

## Problem

Scenario S3 of compact strings (`scenarios.md`, CS-18) says "the tables are constants; no shared mutable state". No test of C#, Java, Rust, Go or Swift packs and unpacks texts from several threads at once (loop 45 assessment, row CS-S3). Python, TypeScript and C++ have only the interleaved or caller-scratch tests, which is all they can express.

## Outcome

- A concurrency test exists in each of the five packages and runs on every suite run.
- A shared mutable buffer in a text codec shows up as a wrong byte or a wrong text.

## Scope

### Included
- One new test file or test class in each of C#, Java, Rust, Go and Swift, named as the package names its text tests; the Go test also runs under `-race` (the Go suite already does).
- Texts: the `enc` rows of `fixtures/text/vectors.txt` (their reference bytes are known) plus random Unicode strings made from a fixed seed per worker.

### Excluded
- Python, TypeScript and C++ (owner 2026-10-20: interleaved or caller-scratch tests only).
- Concurrent use of one protected session from two threads (not walked in loop 45).
- Any production code change.

## Acceptance Criteria

**AC-1: Reference bytes under concurrency** (TW-1)
Given 8 concurrent workers and one built scheme with a text field
When each worker packs and unpacks at least 200 different texts, vector rows among them
Then every packed field of a vector row equals its reference bytes, every unpacked text equals the worker's input, mismatches are 0 and errors are 0. Rust schemes are not `Send` or `Sync` (`Rc<str>` names), so each Rust worker builds its own scheme and the threads share the process-wide codec tables; Go under `-race` uses a 10 s nominal bound (the 1 s bound is asserted without `-race`).

**AC-2: Load-aware bound** (TW-1)
Given the host load factor of the package's timing helper
When the test runs
Then it finishes in 1 second nominal times the factor; a timing assertion uses the helper of `_docs/AGENT_GOTCHAS.md`, never a fixed bound.

**AC-3: No production change**
Given the five packages
When the task is done
Then no file under a package's source directory changed; only test files and, for Rust and Java, the lines that register a test.

## Non-Functional Requirements

**Reliability**
- The test starts all workers together (a barrier or latch) so they overlap, uses no sleep, and joins with a time limit so a hang fails and does not block the suite.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | C#, Java, Rust, Go, Swift: 8 workers × 200 texts | 0 mismatches, 0 errors |
| AC-2 | each package: elapsed against the nominal bound times the factor | passes on an idle host and under load |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/text/vectors.txt` enc rows | the five suites | green | Reliability |

## Constraints

- Test files ≤ 500 lines; MSBUILDDISABLENODEREUSE=1 for `dotnet test`; Go only in `golang:1.27`; Swift flags of `AGENT_GOTCHAS.md`.

## Risks & Mitigation

**Risk 1: A flaky overlap**
- *Risk*: workers run one after another on a loaded host and never overlap.
- *Mitigation*: a start barrier; the correctness check does not depend on overlap, so the test cannot fail falsely.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Timing in a concurrency test | load-aware helper per package | open | Low |
