---
loop: 11
---

# Rust cap collection capacity at the bytes left

**Task**: AZ-2125_rust_capacity_hint_bounded
**Name**: Rust cap collection capacity at the bytes left
**Description**: Collections decoded from a packet are not given a capacity larger than the bytes left.
**Complexity**: 1 points
**Dependencies**: None
**Component**: rust
**Tracker**: AZ-2125
**Epic**: AZ-2069

## Problem

**F7 (Low).** `Vec::with_capacity(count)` in `rust/src/walk/unpack.rs` (~368, list and dict) reserves from the u16 packet count before the bytes are checked: a 3-byte packet `01 ff ff` reserves about 4.2 MB of virtual memory.

Source: loop 11 security audit (`_docs/05_security/security_report.md`). The owner chose to fix these in loop 11 (2026-10-05). Probes that reproduced them are in the audit scratchpad: `/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/02da6560-84eb-45e8-a2b7-c41bfedae5cd/scratchpad` (`cs2/Run.cs`, `ts/run.ts`, `java/Run.java`, `rs/run`, `gen.py`, `drive.py`).

## Outcome

Each AC below holds; wire bytes of every packet that unpacks or packs correctly today are unchanged.

## Scope

### Included
- rust package only, production code and tests.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1: Bounded capacity hint**
Given a list or dict with count `ffff`, When `01 ff ff` is unpacked, Then it returns the same short-packet error as before and the reserved capacity is at most the bytes left (test the pure helper that computes the hint)

**AC-2: Existing behaviour unchanged**
Given every existing test (88), When they run, Then they pass unchanged

## Unit Tests

Write these first. They must fail on the current code.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `capacity_hint_is_capped_by_bytes_left` | helper with count 65535, left 1 | hint <= 1 |
| AC-2 | `count_ffff_short_packet_unchanged` | `01 ff ff` | same Short error |

## Constraints

- A small pure helper is fine; no new dependency.
- ADR-001: no shared walker, no import from another package.
- No new public error type before C15.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: a fix changes a result a caller relied on. *Mitigation*: the full existing suite, the golden vector and the language-pair handoffs stay green unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind and label undecided (C15) | user / C15 | open | Medium |
