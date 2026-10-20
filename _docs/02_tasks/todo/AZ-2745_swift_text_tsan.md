---
loop: 47
branch: dev
---

# Swift TextConcurrencyTests under the thread sanitizer

**Task**: AZ-2745_swift_text_tsan
**Name**: `TextConcurrencyTests` in the `swift_sanitized` CI step
**Description**: The thread-sanitizer step of the Swift suite also runs the eight-thread text test of AZ-2735.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `.github/workflows/run-suite.sh`, `.github/workflows/run-suite-swift.test.sh`
**Tracker**: AZ-2745
**Epic**: AZ-2645

## Problem

`swift_sanitized` in `run-suite.sh` runs `ConcurrencyTests`, `SessionTests` and `SessionHostileTests` with `--sanitize=thread`. `TextConcurrencyTests` (eight threads on one built text scheme, AZ-2735, CS-S3) is not in that list, so a data race in the Swift text codec would pass CI unseen (loop 46 review, skipped finding). The test already calls `expectWithinUnlessSanitized`, so it is written to run under the sanitizer.

## Outcome

- A data race in the Swift text path is caught by the sanitizer in CI.

## Scope

### Included
- `swift_sanitized`: `TextConcurrencyTests` joins the suite-present check, the thread-use guard exemption (`/(Concurrency|Session|SessionHostile)Tests.swift$`, which must also exempt `TextConcurrencyTests.swift`) and the `--filter` list.
- `run-suite-swift.test.sh`: the three exact-string readers (the `for suite in` loops at lines 52 and 310 and the expected `swift test ... --sanitize=thread` line 132) read the new strings; a mutant where the suite is gone from the test listing must fail the step by name.

### Excluded
- Any change to a Swift source or test file (a race found is reported, not patched here).
- Other languages' sanitizers.

## Acceptance Criteria

**AC-1: Listed and run**
Given a Swift test listing that holds `TextConcurrencyTests`
When the `sanitized` part of `run-suite.sh` runs
Then the `swift test` line carries `--filter '\.TextConcurrencyTests/'` with the three existing filters.

**AC-2: Missing suite fails by name**
Given a test listing without `TextConcurrencyTests`
When the `sanitized` part runs
Then it exits non-zero with `swift has no TextConcurrencyTests suite`.

**AC-3: Guard still bites**
Given a threaded test file outside the four sanitized suites
When the step runs
Then it fails naming the file; `TextConcurrencyTests.swift` is not named.

**AC-4: Passes under TSan**
Given the Swift package on this Mac (recipe of `AGENT_GOTCHAS.md`)
When `swift test --sanitize=thread --filter '\.TextConcurrencyTests/'` runs
Then it passes with 0 races reported.

**AC-5: CI time**
Given the CI annotations after the push
When the Swift sanitized step time is read
Then the added time is recorded in the loop record (no fixed bound; the local TSan run of the suite was about 41 s).

## Non-Functional Requirements

**Performance**
- No new CI job; one more `--filter` on an existing step.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2, AC-3 | `bash .github/workflows/run-suite-swift.test.sh` | green, with the new mutant rejected |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `swift test` with the CLT flags of `AGENT_GOTCHAS.md`, one `swift` run at a time in the root tree | the sanitized text test | passes, no TSan report | Performance |

## Constraints

- Before committing: `git grep` the exact strings `SessionHostileTests` and `--sanitize=thread` over `.github`, `scripts` and `_docs/02_document` and update every reader (`AGENT_GOTCHAS.md`, loops 34 and 39).
- A worker never runs `git stash/checkout/reset/clean/add/rm/mv`; commands end on their own. Only one `swift build`/`swift test` at a time in the root tree.

## Risks & Mitigation

**Risk 1: TSan reports a race in the text path**
- *Risk*: the sanitizer finds a real race the plain run did not.
- *Mitigation*: stop and report the stack with the test name; no source change without the owner (a finding, not a test change).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The timing helper allows a looser bound under the sanitizer (`expectWithinUnlessSanitized`) | by design, already in the test | open | Low |
