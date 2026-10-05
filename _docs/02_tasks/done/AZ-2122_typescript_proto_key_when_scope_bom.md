---
loop: 11
---

# TypeScript __proto__ dict key, when-in-repeat round scope, BOM kept

**Task**: AZ-2122_typescript_proto_key_when_scope_bom
**Name**: TypeScript __proto__ dict key, when-in-repeat round scope, BOM kept
**Description**: A dict key `__proto__` is an ordinary key, a `when` inside `repeat` reads the fields of its own round, and a leading BOM in a string is kept.
**Complexity**: 3 points
**Dependencies**: None
**Component**: typescript
**Tracker**: AZ-2122
**Epic**: AZ-2069

## Problem

**F5 (Medium).** A dict key `__proto__` replaces the prototype of the decoded dict and bypasses the duplicate-key check (`typescript/src/walker.ts` dict branch). Scheme `dict(acl, dict(inner, u8))` with packet `01 0100 0900 5f5f70726f746f5f5f 0100 0500 61646d696e 01` decodes ok with `acl.admin === 1` inherited and `"admin" in acl` true; two `__proto__` keys are accepted with an empty dict. `Object.prototype` itself is not polluted. The other four packages keep the key and reject the duplicate.

**F6 (Medium).** A `when` inside `repeat` that names a field of the same round never fires (`walker.ts` ~122): scheme `repeat(u8 k, when(eq(k,1), u8 v))` with packet `01 01 0a` gives `k=[1,10]` in TypeScript, while Python, Java, C# and Rust read `k=1, v=10`; packet `01 00 01` is ok in TypeScript and a short-packet error elsewhere. It decodes without error to a different row.

**F8 (Low).** `TextDecoder` drops a leading byte order mark (`kinds.ts` ~303): `01 0600 efbbbf 616263` gives `"abc"` in TypeScript and `"\uFEFFabc"` in Python, Java and C# (Rust keeps it).

Source: loop 11 security audit (`_docs/05_security/security_report.md`). The owner chose to fix these in loop 11 (2026-10-05). Probes that reproduced them are in the audit scratchpad: `/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/02da6560-84eb-45e8-a2b7-c41bfedae5cd/scratchpad` (`cs2/Run.cs`, `ts/run.ts`, `java/Run.java`, `rs/run`, `gen.py`, `drive.py`).

## Outcome

Each AC below holds; wire bytes of every packet that unpacks or packs correctly today are unchanged.

## Scope

### Included
- typescript package only, production code and tests.

### Excluded
- Error kind and label of any error value (C15).
- Other packages.

## Acceptance Criteria

**AC-1: F5: __proto__ is an ordinary key**
Given `dict(acl, dict(inner, u8))`, When the packet above is unpacked, Then no member is inherited (`"admin" in acl` is false), the `__proto__` key is an own entry, and two `__proto__` keys are rejected as duplicates like any other key

**AC-2: F6: when reads its own round**
Given `repeat(u8 k, when(eq(k,1), u8 v))`, When `01 01 0a` is unpacked, Then the row has `k` and `v` read from that round the way the other packages read them (v present); When `01 00 01` is unpacked, Then it is a short-packet error as in the other packages

**AC-3: F8: BOM kept**
Given a utf8 field, When `01 0600 efbbbf 616263` is unpacked, Then the string is `"\uFEFFabc"`; and pack/unpack of a string that starts with U+FEFF round-trips

**AC-4: Existing behaviour unchanged**
Given every existing test (80), the golden vector and the language-pair handoffs, When they run, Then they pass unchanged

## Unit Tests

Write these first. They must fail on the current code.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `dict_proto_key_is_ordinary` | the F5 packet | no inherited member; own key present |
| AC-2 | `dict_duplicate_proto_key_rejected` | two `__proto__` keys | duplicate-key error |
| AC-3 | `when_in_repeat_reads_own_round` | `01 01 0a` and `01 00 01` | row matches the other packages; short-packet error |
| AC-4 | `bom_is_kept` | `01 0600 efbbbf 616263` | string starts with U+FEFF |

## Constraints

- For F6 compare with python/csharp/java/rust behaviour for the same scheme before changing; the row shape must match what TypeScript already returns for a repeat (lists), only the evaluation of the `when` changes.
- ADR-001: no shared walker, no import from another package.
- No new public error type before C15.
- Files stay at or under 500 lines.

## Risks & Mitigation

- *Risk*: a fix changes a result a caller relied on. *Mitigation*: the full existing suite, the golden vector and the language-pair handoffs stay green unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind and label undecided (C15) | user / C15 | open | Medium |
