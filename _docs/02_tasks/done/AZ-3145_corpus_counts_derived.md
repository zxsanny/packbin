---
loop: 56
branch: dev
---

# Corpus case counts derived from cases.txt

**Task**: AZ-3145_corpus_counts_derived
**Name**: Hostile corpus counts derived
**Description**: The Go, Swift and Rust hostile loaders take the case count from `fixtures/hostile/cases.txt` and name a missing or unused handler by case id.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `go/hostile_loader_test.go`, `swift/Tests/PackbinTests/HostileTests.swift` and `FuzzTests.swift`, the Rust loader in `rust/src` that reads `fixtures/hostile/cases.txt`
**Tracker**: AZ-3145
**Epic**: AZ-2645

## Problem

The loaders hard-code the number of cases (Go and Swift: 75; Swift fuzz: 17). A new line in `cases.txt` fails them with a count mismatch, not with the case that lacks a handler (review #5, Low).

## Outcome

- No literal case count is asserted; the count is the number of non-comment, non-empty lines (the Swift fuzz count: the number of unpack and limit lines).
- A case without a handler, and a handler without a case, are reported by id.

## Scope

### Included
- The three loaders; the Rust location found at task time (state it in the report).

### Excluded
- `fixtures/` edits (shown with a broken copy under the scratchpad); other packages.

## Acceptance Criteria

**AC-1: Derived** — Given `cases.txt`, When Go, Swift and Rust loaders run, Then no literal 75 or 17 asserts a count.

**AC-2: By id** — Given a copy of `cases.txt` with one valid line added and, separately, one line removed, When each loader runs on the copy, Then it fails naming the case id (not a count). Shown once per loader.

**AC-3: Suites pass** — Given the real `cases.txt`, When the Go, Swift and Rust suites run, Then they pass.

## Non-Functional Requirements

**Compatibility**: no change to test coverage; no case skipped.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-3 | full suites of the three packages | pass |
| AC-2 | broken copy of `cases.txt`, per loader | fails by case id |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loaders read a fixed path; a broken copy needs an env override or a temporary swap | swap only in a scratchpad copy of the tree, never edit `fixtures/` | open | Low |

## Outcome of loop 56

All ACs met. Go, Swift and the Rust heap-free loaders name a missing or unused handler by case id. The plain Rust loader cannot name an unused unpack or limit handler; the `corpus.txt` counts (Swift 33, Rust nostd at least 33) stay hard-coded.
