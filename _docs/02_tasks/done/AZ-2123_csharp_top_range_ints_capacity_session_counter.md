---
loop: 11
---

# C# top-range u64/i64 overflow, capacity reserve, atomic session counter

**Task**: AZ-2123_csharp_top_range_ints_capacity_session_counter
**Name**: C# top-range u64/i64 overflow, capacity reserve, atomic session counter
**Description**: No exception escapes unpack for any 8-byte integer, list/dict capacity is not reserved from the packet count before the bytes are checked, and the session send counter is atomic.
**Complexity**: 3 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2123
**Epic**: AZ-2069

## Problem

**F4 (Medium).** `BinaryPacker.Unpack` throws `OverflowException` for a u64 at or above 0xFFFFFFFFFFFFFC00 (`01 ff ff ff ff ff ff ff ff`) and an i64 at or above 0x7FFFFFFFFFFFFE00 (`01 ff ff ff ff ff ff ff 7f`). Cause: `csharp/Walker.Scalars.cs:79` boxes every integer as `double`, then `csharp/ObjectValues.cs:118` converts it back with `Convert.ChangeType`. The neighbours `01 ff fb ff ff ff ff ff ff` and `01 ff fd ff ff ff ff ff 7f` are accepted. The same fields in Python, TypeScript, Java and Rust return a value. AZ-2116 (exact integer types) covers the rounding but not the crash.

**F7 (Low).** `new List(count)` and `new Dictionary(count)` (`csharp/Walker.Counted.cs` ~350, ~410) reserve from the u16 count before the bytes are checked: a 3-byte packet `01 ff ff` costs 62 us against 8 us for a small valid packet, with a gen-2 GC about every 10 packets.

**F9 (Low, security-relevant).** The `PackSession` send counter is not atomic (`csharp/PackSession.cs` ~47): 8 threads packing the same plaintext 20 000 times each produced 46 893 distinct ciphertexts out of 160 000, so a ChaCha20 keystream is reused.

Source: loop 11 security audit (`_docs/05_security/security_report.md`). The owner chose to fix these in loop 11 (2026-10-05). Probes that reproduced them are in the audit scratchpad: `/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/02da6560-84eb-45e8-a2b7-c41bfedae5cd/scratchpad` (`cs2/Run.cs`, `ts/run.ts`, `java/Run.java`, `rs/run`, `gen.py`, `drive.py`).

## Outcome

Each AC below holds; wire bytes of every packet that unpacks or packs correctly today are unchanged.

## Scope

### Included
- csharp package only, production code and tests.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1: F4: top-range integers do not throw**
Given a u64 field and an i64 field, When `01 ff ff ff ff ff ff ff ff` (u64) and `01 ff ff ff ff ff ff ff 7f` (i64) and the two neighbours are unpacked, Then each returns a row without any exception; prefer the exact value (read the 8 bytes as ulong/long and convert to the target type without going through double) if that is a small contained change, otherwise saturate to the target type limit and say so in the batch report

**AC-2: F7: capacity hint bounded by the bytes left**
Given a list or dict with count `ffff`, When `01 ff ff` is unpacked, Then it returns the same short-packet error as before and allocates a few hundred bytes at most (measure with `GC.GetAllocatedBytesForCurrentThread`)

**AC-3: F9: send counter is atomic**
Given one opened session, When 8 threads pack the same plaintext 2 000 times each, Then all 16 000 ciphertexts are distinct and each one unpacks on a matching receiver in order

**AC-4: Existing behaviour unchanged**
Given every existing test (136), the golden vector and the handoffs, When they run, Then they pass unchanged

## Unit Tests

Write these first. They must fail on the current code.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `top_range_u64_does_not_throw` | F4 packets | row returned, no exception |
| AC-2 | `top_range_i64_does_not_throw` | F4 packets | row returned, no exception |
| AC-3 | `list_count_ffff_allocates_little` | `01 ff ff` | short packet, small allocation |
| AC-4 | `concurrent_pack_yields_distinct_ciphertexts` | 8 threads x 2 000 | 16 000 distinct |

## Constraints

- Do not redo AZ-2116 (exact types everywhere); do the smallest change that stops the exception.
- ADR-001: no shared walker, no import from another package.
- No new public error type before C15.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: a fix changes a result a caller relied on. *Mitigation*: the full existing suite, the golden vector and the language-pair handoffs stay green unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind and label undecided (C15) | user / C15 | open | Medium |
