---
loop: 66
branch: dev
---

# Publish gate under load

**Task**: AZ-3171_publish_gate_load_aware
**Name**: Publish gate checks that hold under host load
**Description**: Make the Go proxy-window check independent of host speed and keep pip's own error in the publish test output.
**Complexity**: 3 points
**Dependencies**: None
**Component**: CI publish gate (`.github/workflows`)
**Tracker**: AZ-3171
**Epic**: AZ-2645

## Problem

In loop 65 the full publish gate, run with 8 shares at once on a host at load 9 to 22, failed two checks that each passed alone. `publish-go.test.sh` AC-3 saw one proxy ask where it needs two, because a 3 s window ends after the first slow ask. A `pip install` in the publish-phases run returned 1 and its error was not in the log, so the cause is unknown. A red gate that cannot be read costs a rerun of 325 s to 1,057 s each time.

## Outcome

- The Go window check passes however slow one proxy ask is, and still fails when the check loop stops after one try.
- A failed `pip install` in the publish tests shows pip's own error in the run output.
- The gate result under load is reported from the share logs, not guessed.

## Scope

### Included
- `publish-go.test.sh` AC-3 (the "never answers" case) and its delay injection.
- The two failure messages in `publish-phases-failures.test.sh` (lines 180 and 190) quote 25 lines of the run output, not 3, through one helper, and a test for it.
- One full `scripts/loop-tests.sh` gate run, with the host load, read from share logs.

### Excluded
- A retry of pip in the real publish path, unless the kept error names a network failure (AC-6; the owner is told first).
- Changing `proxy_check`'s production window or pause defaults.
- Candidates "stack of a flag scope" and the older hopper items.

## Acceptance Criteria

**AC-1: Go window under a slow ask**
Given the `go` stub sleeps 5 s per call
When `publish-go.test.sh` runs
Then it exits 0 and the "never answers" case records at least 2 asks.

**AC-2: the check still catches a one-try loop**
Given a copy of `publish-go.sh` whose `proxy_check` breaks after one try
When the same test runs
Then it exits non-zero naming "asked once only".

**AC-3: quiet-host time**
Given a quiet host
When `publish-go.test.sh` runs with no delay
Then it exits 0 in at most 60 s.

**AC-4: pip's error is kept**
Given a run output of 40 lines with `ERROR: stub pip failed` on line 30
When a publish-phases test quotes the run in a failure message
Then the message shows the last 25 lines, so the error is in the gate log, and the test for it fails on the current tree (the two messages quote 3 lines today).

**AC-5: phases group**
Given a quiet host
When `publish-gate.test.sh --groups phases` runs
Then it exits 0 in at most 400 s.

**AC-6: pip retry only on evidence**
Given the kept error of a real failure names a network or index error
When this task closes
Then a bounded retry of the install may be added and the owner is told; otherwise `publish-inside.sh` changes only in its log line, and the batch report says which.

**AC-7: gate under load**
Given the full `scripts/loop-tests.sh` gate run once
When it ends
Then the results of `publish-go` and `publish-phases-failures` are read from their share logs and reported PASS / FAIL with the host load.

## Non-Functional Requirements

**Reliability**
- No check is loosened: AC-2 proves the Go check still fails on the defect it exists for.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | slow `go` stub (5 s) | exit 0, asks >= 2 |
| AC-2 | broken `proxy_check` copy | exit != 0, "asked once only" |
| AC-4 | 40-line output with the pip error on line 30 | error line in the quote, fails before the change |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | quiet host | `publish-go.test.sh` | exit 0, <= 60 s | — |
| AC-5 | quiet host | `publish-gate.test.sh --groups phases` | exit 0, <= 400 s | — |
| AC-7 | busy host | full `scripts/loop-tests.sh` | two checks read, load noted | — |

## Constraints

- Test support only; the real publish path stays as is unless AC-6 fires.
- Wait for host load below 6 before the quiet-host runs (`AGENT_GOTCHAS.md`).

## Risks & Mitigation

**Risk 1: the load failure cannot be reproduced on demand**
- *Risk*: AC-7 passes by luck.
- *Mitigation*: AC-1 injects the delay; AC-7 is reported as evidence, not proof.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The pip failure's cause is unknown; a retry would change the real publish path | AC-6, owner told | open | Medium |
| The Go check could be loosened until it proves nothing | AC-2 broken copy | open | Medium |
| First `v*` and `go/v*` tags, F44, CS-D5, U24 | owner | accepted-risk | Low |
