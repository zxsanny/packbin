---
loop: 11
---

# Java atomic PackSession send counter

**Task**: AZ-2124_java_atomic_session_counter
**Name**: Java atomic PackSession send counter
**Description**: The Java session send counter is atomic, so concurrent packing on one session never reuses a keystream.
**Complexity**: 2 points
**Dependencies**: None
**Component**: java
**Tracker**: AZ-2124
**Epic**: AZ-2069

## Problem

**F9 (Low, security-relevant).** The Java `PackSession` send counter is not atomic (`java/src/main/java/packbin/PackSession.java` ~53): 8 threads packing the same plaintext 20 000 times each produced 44 546 distinct ciphertexts out of 160 000, so a ChaCha20 keystream is reused.

Source: loop 11 security audit (`_docs/05_security/security_report.md`). The owner chose to fix these in loop 11 (2026-10-05). Probes that reproduced them are in the audit scratchpad: `/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/02da6560-84eb-45e8-a2b7-c41bfedae5cd/scratchpad` (`cs2/Run.cs`, `ts/run.ts`, `java/Run.java`, `rs/run`, `gen.py`, `drive.py`).

## Outcome

Each AC below holds; wire bytes of every packet that unpacks or packs correctly today are unchanged.

## Scope

### Included
- java package only, production code and tests.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1: Atomic send counter**
Given one opened session, When 8 threads pack the same plaintext 2 000 times each, Then all 16 000 ciphertexts are distinct and each unpacks on a matching receiver in order

**AC-2: Sequential behaviour unchanged**
Given the existing session tests and the cross-language session vector, When they run, Then the ciphertext bytes are identical to before

## Unit Tests

Write these first. They must fail on the current code.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `concurrent_pack_yields_distinct_ciphertexts` | 8 threads x 2 000 | 16 000 distinct |
| AC-2 | `sequential_session_bytes_unchanged` | existing session vector | same bytes |

## Constraints

- Keep `PackSession` free of locks on the receive path unless a test shows it is needed.
- ADR-001: no shared walker, no import from another package.
- No new public error type before C15.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: a fix changes a result a caller relied on. *Mitigation*: the full existing suite, the golden vector and the language-pair handoffs stay green unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind and label undecided (C15) | user / C15 | open | Medium |
