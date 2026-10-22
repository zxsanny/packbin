---
loop: 58
branch: dev
---

# Go refusal check names the differing ids

**Task**: AZ-3161_go_refusal_check_ids
**Name**: Go refusal check names the differing ids
**Description**: TestHostileEveryRefusalPinsOneRule fails with the idDifference message, not two raw lists.
**Complexity**: 1 points
**Dependencies**: None
**Component**: `go/hostile_pack_test.go`
**Tracker**: AZ-3161
**Epic**: AZ-2645

## Problem

`TestHostileEveryRefusalPinsOneRule` prints `pack_error cases [...], pinned rules [...]` (two map-ordered lists) when idDifference reports a difference.

## Outcome

- The failure message names each missing, unused or duplicate id.

## Scope

### Included
- Test code in the files named under Component.

### Excluded
- Any product code, `fixtures/` in the real tree, the other packages' loaders.

## Acceptance Criteria

**AC-3: Named ids** — Given `hostileRefusals` without one `pack_error` case id, or with one extra id (copy), When the test runs, Then it fails with the idDifference message naming that id.

**AC-4: Suite** — Given the unmodified tree, When `gofmt -l .`, `go vet ./...` and `go test -race -count=1 ./...` run in `golang:1.27`, Then all pass.

## Non-Functional Requirements

**Compatibility**: test code only; Cortex-M4F flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | broken copy of `hostileRefusals` (one removed, one added) | fails naming the id |
| AC-4 | Go suite in `golang:1.27` | passes |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |

## Outcome of loop 58

AC-3 and AC-4 met. `TestHostileEveryRefusalPinsOneRule` prints the `idDifference` message. With `pack_missing_required_value` replaced by an invented id in a copy of `hostileRefusals` it fails: `Go handler pack_invented_extra_id has no case in cases.txt; case pack_missing_required_value has no Go handler`. `golang:1.27` gofmt, vet and `go test -race -count=1 ./...` pass.
