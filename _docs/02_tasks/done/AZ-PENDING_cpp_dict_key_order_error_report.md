---
loop: 60
branch: dev
---

# C++ dict key order test: print the Error, do not pack a refused key

**Task**: AZ-PENDING_cpp_dict_key_order_error_report
**Name**: C++ dict key order test: print the Error, do not pack a refused key
**Description**: Each of the 7 pairs reports the `Error` returned and expected by name; `put_key` returns whether it copied and a refused key is never packed.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `cpp/tests/core/dict_order_host_tests.cpp`
**Tracker**: pending (Jira connector absent, see `_docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md`)
**Epic**: AZ-2645

## Problem

A failing pair prints a fixed message, not the `Error` returned; `put_key` leaves an empty key on an oversize key and the pair is still packed.

## Outcome

- A wrong pair result names the pair and shows both `Error` names; an oversize key cannot pass as `Ok` or `BadValue`.

## Scope

### Included
- Test code in the file named under Component.

### Excluded
- Any product code, `cpp/src`, `cpp/include`, the arm stage figures. No new `expect(` call site per pair beyond what the file has (the firmware runner counts sites per file; this file is host-only).

## Acceptance Criteria

**AC-1: Error shown** — Given a pair that returns an unexpected `Error`, Then the failure message names the pair and prints the `Error` returned and the one expected by name.

**AC-2: Sensitivity** — Given a scratch copy that flips one pair's expectation, Then the failure line shows that pair and both `Error` names; the real tree passes on the Mac host and in `gcc:16`.

**AC-3: Refused key** — Given `put_key` with `n` above the key capacity, Then it reports its own failure, the pair is not packed, and the helper returns an `Error` that no pair expects.

## Non-Functional Requirements

**Compatibility**: test code only; flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | host test, scratch copy with one flipped pair | pass on the real source; the copy prints pair and both names |
| AC-3 | scratch copy calling `put_key` with n = 5 | its own failure; no pack result matches a pair |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |

## Outcome of loop 60

AC-1 to AC-3 met. `put_key` returns whether it copied; `pack_error` returns `kKeyRefused` (`Error::TooLong`) without packing when a key is refused; `error_name` and `expect_pair` print `pack: <pair>: got <Error>, want <Error>` for each of the 7 pairs. Scratch copies: a flipped pair fails `FAIL: pack: ab then a: got BadValue, want Ok`; a 5-byte key fails `FAIL: put_key: the key fits its Text` and `FAIL: pack: a twice: got TooLong, want BadValue`. Real source passes on the Mac host (`make -C cpp test`) and in `gcc:16`; no file under `cpp/src` or `cpp/include` changed.
