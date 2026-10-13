---
loop: 25
branch: dev
---

# Probe the six for a split-flag bit inside a false `when` with the member given (D7)

**Task**: AZ-2478_split_flag_false_when_probe
**Name**: Probe the six for a split-flag bit inside a false `when` with the member given
**Description**: D7 A: TypeScript packs a split-flag bit as the body with no payload for a member whose `when` is false (`01000306`, repacks as `01000206`); Go copies TypeScript (Go-3). Probe Python, Rust, C#, Java, C++ for the same row and fix the outliers so each package packs TypeScript's `01000206` (and tolerates reading `01000306`).
**Complexity**: 3 points
**Dependencies**: none
**Component**: python, rust, csharp, java, cpp (probe first; fix outliers)
**Tracker**: AZ-2478
**Epic**:

## Problem

The split-flag-bit row is a hostile construct the loop 24 Go port discovered (Go-3): a `Flags` bit named inside a `when` whose condition is false. TypeScript packs `01000306` on the first run and `01000206` on repack of the unpacked value, because the unpacker drops the bit when the `when` is false. Go copies TypeScript. The other five have not been probed; the owner picked A (probe + fix outliers) in D-batch 2026-10-14.

Reference: `_docs/02_task_plans/round-parity-and-construction-checks/` (Go-3 and the split-flag rows), `_docs/loops/loop24/assessment24.md` (D7).

## Outcome

- A probe row per package (Python, Rust, C#, Java, C++) in the parity rows doc with the hex produced on `pack` and on `pack(unpack(pack))`.
- An outlier whose pack bytes differ from TypeScript's `01000306` or whose repack differs from `01000206` is fixed in this ticket: the walker drops the bit on unpack when its `when` is false, so repack produces TypeScript's bytes.
- No regression in any other hostile vector or parity row the package already pins; the six `run-suite.sh` runs stay green for the probed packages.

## Scope

### Included

- A short probe test under `<pkg>/tests/` for each of the five.
- A walker fix in the outliers (`<pkg>/src/` or the equivalent), limited to the drop-on-false-`when` behavior for a flag bit.
- Owns (exclusive write): `python/**`, `rust/**`, `csharp/**`, `java/**`, `cpp/**` for the probe test and the fix if the package is an outlier (one package per worker; the ticket decomposes into one sub-worker per package if more than one needs the fix).

### Excluded

- TypeScript, Go (both already pin the row).
- Changes to the parity rows doc beyond the one row per package.

## Acceptance Criteria

**AC-1: Probe row recorded for each of the five**
Given the scheme and value from the Go-3 row (D7 in handoff 25)
When each package packs and repacks
Then the parity doc has a row for the package with the pack hex and the repack hex; probed packages 5.

**AC-2: Pack bytes match TypeScript (or Bug ticket if infeasible this loop)**
Given AC-1 bytes
When compared to TypeScript's `01000306` on pack
Then every outlier is fixed in this ticket; infeasible fixes (walker rewrite too large) get a Bug ticket with the hex and the owner's decision needed.

**AC-3: Repack bytes match TypeScript**
Given a packet unpacked from AC-2 bytes and repacked
When compared to TypeScript's `01000206`
Then the bytes match for every package that AC-2 fixed.

**AC-4: No regression in run-suite**
Given the fixed outlier
When its `run-suite.sh` runs
Then every PASS row that was green on the loop 24 close is green now; new failures 0.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | each of the five on the Go-3 scheme | row recorded |
| AC-2 | outliers pack | `01000306` |
| AC-3 | outliers repack | `01000206` |
| AC-4 | each fixed package's run-suite | 0 regressions |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | Go-3 scheme, Go-3 value | pack and repack | 5 rows recorded | |
| AC-2 | outliers | pack | `01000306` | |
| AC-3 | outliers | pack(unpack(pack)) | `01000206` | |
