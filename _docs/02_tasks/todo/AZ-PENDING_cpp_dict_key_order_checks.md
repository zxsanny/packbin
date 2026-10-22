---
loop: 59
branch: dev
---

# C++ dict key order test: guard put_key, name each refusal

**Task**: AZ-PENDING_cpp_dict_key_order_checks (Jira key pending, see `_docs/_process_leftovers/2026-10-22_loop59_jira_cpp_task.md`)
**Name**: C++ dict key order test: guard put_key, name each refusal
**Description**: `put_key` checks the key length against the key capacity; the pack helper returns the `Error` and each pair asserts its own result and message.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `cpp/tests/core/dict_order_host_tests.cpp`
**Tracker**: pending
**Epic**: AZ-2645

## Problem

`put_key` copies `n` bytes into a `Text<4>` unchecked; `packs_in_order` reports every refused pair with one message.

## Outcome

- A too-long key fails the test; a wrong pair result names that pair.

## Scope

### Included
- Test code in the file named under Component.

### Excluded
- Any product code, `cpp/src`, `cpp/include`, the arm stage figures.

## Acceptance Criteria

**AC-4: Key length** — Given `put_key` with `n` above the key capacity, Then the test fails with its own message and nothing is copied.

**AC-5: Own message** — Given the 7 key pairs, Then each asserts its own result (`Error::Ok` or `Error::BadValue`) with its own message at its call site.

**AC-6: Sensitivity** — Given a scratch copy that flips one pair's expectation, Then the failure names that pair; the real tree passes on the Mac host and in `gcc:16`, no file under `cpp/src` or `cpp/include` changes.

## Non-Functional Requirements

**Compatibility**: test code only; flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | scratch copy calling `put_key` with n = 5 | fails with the guard's message |
| AC-5, AC-6 | host test, scratch copy with one flipped pair | pass on the real source; the copy names its pair |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |
