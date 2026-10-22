---
loop: 57
branch: dev
---

# Corpus guards in the Go, Swift and Rust test loaders

**Task**: AZ-3153_corpus_guards
**Name**: Corpus guards
**Description**: The Rust, Swift and Go loaders of the hostile corpora fail by case id for the four gaps left by AZ-3145.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `rust/src/hostile_tests.rs`, `rust/tests/nostd_hostile_tests.rs`, `swift/Tests/PackbinTests/FuzzTests.swift`, `go/hostile_loader_test.go`, `go/hostile_pack_test.go`
**Tracker**: AZ-3153
**Epic**: AZ-2645

## Problem

The plain Rust loader cannot name an unused unpack or limit handler (`scheme_for`, `rust_outcome` are `match` expressions); a Rust nostd case moving between run and a reasoned skip is not noticed; `corpus.txt` counts are hard-coded (Swift 33, Rust nostd at least 33); Go has two helpers for one check (`idDifference`, `sameSet`).

## Outcome

- Each gap is closed and shown with a broken copy of the fixtures; the three suites pass.

## Scope

### Included
- The four changes above in the files named; an expected-skip set (ids with reasons) for the nostd test.

### Excluded
- `fixtures/` in the real tree; the other five packages' loaders; any product code.

## Acceptance Criteria

**AC-6: Rust unused handler** — Given a copy of `cases.txt` with the only line of an unpack or limit handler removed, When the plain Rust loader runs, Then it fails naming that case id.

**AC-7: Skip set** — Given a Rust nostd case moved from run to skip (or back), When the nostd corpus test runs, Then it fails naming the id; the expected skips are an explicit set of ids with reasons.

**AC-8: Derived corpus counts** — Given a copy of `corpus.txt` with one extra line, When the Swift fuzz test and the Rust nostd test run, Then both pass with the new count (no literal 33).

**AC-9: One Go helper** — Given a missing and an unused handler, When the Go loader runs, Then one helper reports them with the messages of today; the Go, Swift and Rust suites pass.

## Non-Functional Requirements

**Compatibility**: test code only.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-6, AC-7, AC-8 | broken copy under the scratchpad, focused test per loader | fails by id / passes with new count |
| AC-9 | Go in `golang:1.27`, Swift `swift test`, Rust `cargo test` | pass |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The expected-skip set can go stale | a stale entry fails by id | open | Low |
| Rust `match` handlers may need a handler table to be countable | smallest change that names the id | open | Low |

## Outcome of loop 57

AC-6 to AC-9 met, each shown on a broken copy. Rust handlers are tables (`rust/src/hostile_tests/schemes.rs`) with `unused_handlers`; the nostd test compares the skipped set with an explicit `SKIPS` set in both directions; Swift and Rust nostd counts equal the corpus line count; Go `sameSet` is gone. Go, Rust and Swift suites pass.
