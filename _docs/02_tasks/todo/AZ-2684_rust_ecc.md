---
loop: 38
branch: dev
---

# Message ECC: Rust package

**Task**: AZ-2684_rust_ecc
**Name**: Message ECC: Rust package
**Description**: Rust scheme parity setting, pack with parity, unpack with detection and repair.
**Complexity**: 5 points
**Dependencies**: AZ-2679_ecc_reference_vectors
**Component**: rust package
**Tracker**: AZ-2684
**Epic**: AZ-2677

## Problem

Rust callers cannot detect or repair a corrupted message. The package must read the contract `message-ecc.md` and match the shared vectors. Source of truth for the numbers: `_docs/02_task_plans/message-error-correction/acceptance_criteria.md` (EC-n) and `input_data/expected_results/results_report.md` (rows 1 to 17). Owns: `rust/src/` and its tests. No other package or shared fixture is edited here.

## Outcome

- A scheme declares n parity bytes (0 to 32, default 0); n = 0 is byte-identical to today
- pack appends parity; unpack detects, repairs up to t bytes, reports the repaired count, and returns a typed uncorrectable error beyond that
- session, compact text and dispatch rules of the contract hold in Rust

## Scope

### Included
- Scheme setting and its validation (EC-3)
- Encode, syndrome check, repair, new error kind, repaired count
- Size limit 254 - n (EC-4)
- Session: parity over the padded bytes (EC-10)
- Compact-text field in a protected message (EC-11)
- Dispatch same-n rule (`unpack_with` dispatch) (EC-16)
- Speed bound (1 s)

### Excluded
- Other packages
- Shared fixtures and CI wiring (AZ-2679, AZ-2689)
- Block splitting, erasures

## Acceptance Criteria

**AC-1: Off is unchanged**
Given a scheme with 0 parity bytes
When the existing suite and the golden fixtures run
Then 0 failures and 0 byte mismatches (EC-1).

**AC-2: Golden protected bytes**
Given the position fixture and n = 1, 2, 4, 8, 16
When packed
Then the bytes equal rows 2 to 6 of the report (EC-2); n = 33 fails when the scheme is built, naming n and 32 (EC-3).

**AC-3: Repair**
Given n >= 2 and t = n/2
When up to t bytes (any position, any bit pattern) of a protected message are wrong
Then unpack returns the original row and the repaired count (EC-5); all 15 positions x 255 values for n = 2 and 1,000 seeded cases each for n = 4, 8, 16 recover 100 %.

**AC-4: Refuse beyond capacity**
Given t, and t+1 to n-t wrong bytes
When unpacked
Then an uncorrectable error and 0 values, never a wrong row: 10,000 seeded cases for (n = 4, t = 1) and (n = 4, t = 0) (EC-6); garbage with n = 2, t = 0 accepted at most 12 of 200,000 (EC-7); rows 7 to 12 of the report behave as stated (EC-8); truncation and unprotected bytes refused (EC-14).

**AC-5: Size limit**
Given n and a clear message above 254 - n bytes (n = 32: 222 ok, 223 refused)
When packed
Then a typed error naming the length and the limit, 0 bytes written (EC-4).

**AC-6: Session, text, dispatch**
Given an open session, a protected scheme with a compact-text field, and a dispatch of several schemes
When 2 bytes are wrong (session n = 4, text n = 4) or the type byte is wrong
Then the row, the string and the right handler are recovered; a mixed-n dispatch is refused when it is built (EC-10, EC-11, EC-16).

**AC-7: Speed**
Given a 254-byte message with 16 parity bytes and 8 wrong bytes
When unpacked 1,000 times, and packed 1,000 times
Then within 1 s on one core for the repair loop and 1 s for packing (EC-13).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | existing suites | 0 failures |
| AC-2 | rows 2 to 6 | equal |
| AC-3 | exhaustive and seeded cases | 100 % recovered |
| AC-4 | seeded refusals | 0 wrong rows |
| AC-5 | 222/223 at n = 32 | ok / refused |
| AC-6 | session, text, dispatch | as stated |
| AC-7 | speed loop | within bound |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | fixture | the shared vectors checker | passes | EC-2 |
| AC-3 | rows 7, 8, 11 | unpack | stated rows | EC-5,8 |
| AC-6 | open session n = 4 | 2 wrong bytes | row recovered | EC-10 |

## Constraints

- Match `message-ecc.md`; any parameter change goes back to AZ-2678
- Edit only `rust/src/` and its tests
- Decode work bounded by 255 x 32 operations; unpack still never throws or traps on hostile bytes

## Risks & Mitigation

**Risk 1: Package-specific error shapes**
- *Risk*: Rust error reporting differs from the others.
- *Mitigation*: the contract fixes one kind name; the ring task (AZ-2689) compares all eight.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Correcting t bytes lowers guaranteed detection to n - t bytes | the contract states it and lists the chance (EC-15); t = 0 gives full detection | open | High |
