---
loop: 11
---

# TypeScript unpack never hangs or throws on hostile packets

**Task**: AZ-2072_typescript_hostile_unpack
**Name**: TypeScript hostile-packet unpack
**Description**: `BinaryPacker.unpack` and `PackSession.unpack` return an `ok:false` result, never loop forever and never throw, for every packet the shared hostile vectors describe.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors
**Component**: typescript
**Tracker**: AZ-2072
**Epic**: AZ-2069

## Problem

Unpack runs on bytes from the network, in browsers (Vue/React) and in Node. Some byte sequences hang the receiver's event loop or throw out of `unpack` instead of returning `{ok:false,…}`. All cases were reproduced on `d108141` with `node` (22.23) importing `typescript/src/index.ts` from a scratch script.

| # | Case | Scheme (type 1) | Bytes (hex) | Today | Code |
|---|------|-----------------|-------------|-------|------|
| 1 | zero-progress repeat | `u8(0, x=>x.k)`, `repeat(1, [when(1, eq(0, 9), [u8(1, x=>x.v)])])` | `010005` | **hangs**: the process was killed by a 5 s alarm (exit 142). A round reads 0 bytes while bytes are left | `walker.ts:310-320` (`while (cur.offset < cur.buf.length)`; the `if` at 315 is a no-op, both arms `return err`) |
| 2a | negative count, signed source | `i8(0, n)`, `sized(1, p, 0)` | `01fd616263` | `readSized` moves the offset **backwards** (`kinds.ts:204-206`); returns `{ok:false, field:"", needed:0, left:6}` for a 5-byte buffer | `kinds.ts:195-208` |
| 2b | | `i8(0, n)`, `bits(1, b, 0)` | `01fd` | `{ok:true}`: count −3 gives `nbytes 0` and `b: []` | `walker.ts:344-350`, `kinds.ts:107-121` |
| 2c | | `i8(0, n)`, `packed(2, 1, k, 0)` / `times(1, 0, [u8(1, v)])` | `01fd` | **throws** `RangeError: k: item count -3` / `times: item count -3` | `walker.ts:38-53` (`borrowedCount`) |
| 2d | negative count from bias | `u8(0, n)`, `packed(1, 1, legs, 0, -1)` | `0100` | **throws** `RangeError: legs: item count -1` | same |
| 3 | invalid UTF-8 | `utf8(0, s)` / `dict(d, u8(0, v))` | `010100ff` / `0101000100ff05` | **throws** `TypeError: The encoded data was not valid for encoding utf-8` (`TextDecoder` with `fatal: true`) | `kinds.ts:285-298` (line 297), dict key via `walker.ts:409` |
| 4 | count behind a clear flag | `flags(0, [u8(0, n)])` then `sized(1, p, 0)` / `packed(2, 1, k, 0)` / `times(1, 0, [u8(1, v)])` | `0100` | **throws** `RangeError: p: count missing` / `k: count missing` / `times: count missing` | `kinds.ts:200-202`, `walker.ts:47-49` |
| 4b | | same with `bits(1, b, 0)` | `0100` | `{ok:true}` with `b: []`: `Number(undefined)` is NaN, read as 0 items | `walker.ts:345` |
| 5 | oversize count | list `ffff` `01ffff0100`; utf8 `ffff` `01ffff61`; times 255 `01ff0102`; sized 255 `01ff0102`; dict `ffff` `01ffff` | already `ShortErr`, handler not called. **Keep** | — |

Cross-language: Python has the same hang and throws for 3/4 (task 02). C#, Java (04/05) and Rust (06) hang on case 1.

## Outcome

- Every vector in `fixtures/hostile/` gives `ok:false`, handler not called, no exception, in under 1 s.
- `bits` uses the same count rule as `packed`/`sized`/`times`: missing or negative is an error, never "0 items".
- Golden hex, language-pair handoffs and the existing 44 tests pass unchanged.

## Scope

### Included
- Clear `BinaryPacker.unpack` and `PackSession.unpack`.
- Progress check for `repeat`: a round that consumes 0 bytes ends the repeat; the unread bytes are reported by the existing trailing check.
- Negative counts (signed source or bias), invalid UTF-8 (string, dictionary key, string element), and an absent count source all return an error result.
- A vector test (`tests/hostile.test.ts`) that reads `fixtures/hostile/` with `node:fs` (tests only; `src` stays browser-safe).

### Excluded
- New public error types or labels (C15).
- Pack behavior (pack keeps throwing `RangeError` for bad rows).
- Reference-scope rules (task 21) and the `bool` rule (task 11).

## Interim error mapping (until C15)

| Vector kind | TypeScript result |
|-------------|-------------------|
| zero_progress_repeat | the existing trailing shape `{ok:false, field:"", needed:0, left:<unread>}`; for `010005` → `left:1` |
| oversize_count | `ShortErr` as today |
| negative_count, invalid_utf8, count_behind_clear_flag | `{ok:false, field:<member name of the field that could not be read>, needed:0, left:<bytes left at that field>}`. This is the precedent used today for a duplicate dictionary key (`walker.ts:415`, strings-lists-dicts F-AC-9) |

If task 01 records a different kind, the vector wins.

## Acceptance Criteria

**AC-1: Zero-progress repeat ends**
Given `u8(0, k)`, `repeat(1, [when(1, eq(0, 9), [u8(1, v)])])`
When `010005` is unpacked
Then within 1 s the result is `{ok:false, field:"", needed:0, left:1}` and the handler is not called

**AC-2: Progressing repeat unchanged**
Given `repeat(0, [i32(0, lat), i32(1, lon)])`
When two complete points are unpacked
Then `lat` is `[10, 30]` and `lon` is `[20, 40]`; one extra byte is still an error with no row (IT-07)

**AC-3: Negative counts are errors**
Given each scheme in rows 2a–2d
When its bytes are unpacked
Then the result is `ok:false` naming the counted field (`p`, `b`, `k`, `legs`; for `times`, the first field of its body, `v`), with `needed:0`; no `RangeError` escapes and the offset never moves backwards

**AC-4: Invalid UTF-8 is an error**
Given `utf8(0, s)` and `dict(d, u8(0, v))`
When `010100ff` and `0101000100ff05` are unpacked
Then each returns `ok:false` naming `s` / `d`; no `TypeError` escapes

**AC-5: Missing count source is an error**
Given `flags(0, [u8(0, n)])` followed by `sized`, `bits`, `packed` or `times` counting on field 0
When `0100` is unpacked
Then each returns `ok:false` naming the counted field; `bits` no longer returns `[]`

**AC-6: Shared vectors**
Given every vector in `fixtures/hostile/`
When `tests/hostile.test.ts` runs
Then each yields `ok:false`, handler not called, no exception, < 1 s, kind as the vector records

**AC-7: Session path**
Given an opened opener/waiter pair
When the waiter unpacks a payload whose clear bytes are `010005`
Then it returns the clear-unpack error within 1 s, and the receive counter still advances by one

## Non-Functional Requirements

**Performance**
- The AC-10 loop (100 000 round trips) stays ≤ 1 s.

**Compatibility**
- `src` imports nothing Node-only. `fixtures/` is read only by tests.

**Reliability**
- No input makes unpack loop without consuming input or throw.

## Unit Tests

Write first; they must fail on `d108141`. Run the hang case in a `node:worker_threads` worker or a child `node` process with a 5 s timeout, so a regression fails instead of hanging `npm test`.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `zero-progress repeat ends with trailing error` | row 1, `010005` | `{ok:false, needed:0, left:1}`, < 1 s |
| AC-3 | `negative sized count is an error` | `01fd616263` | `ok:false`, `field "p"` |
| AC-3 | `negative bits count is an error` | `01fd` | `ok:false`, `field "b"` |
| AC-3 | `negative packed/times count does not throw` | `01fd` ×2, `0100` (bias) | `ok:false`, no throw |
| AC-4 | `invalid utf8 string is an error` | `010100ff` | `ok:false`, `field "s"` |
| AC-4 | `invalid utf8 dictionary key is an error` | `0101000100ff05` | `ok:false`, `field "d"` |
| AC-5 | `count behind a clear flag is an error` | 4 schemes, `0100` | `ok:false` each |
| AC-7 | `session unpack of hostile payload` | pad(`010005`) | same error |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/hostile/` `zero_progress_repeat` | unpack vector hex | trailing error, < 1 s | Reliability |
| AC-6 | `negative_count` | same | error, no throw | Reliability |
| AC-6 | `oversize_count` | same | short error | Reliability |
| AC-6 | `invalid_utf8` | same | error, no throw | Reliability |
| AC-6 | `count_behind_clear_flag` | same | error, no throw | Reliability |
| AC-2 | `fixtures/golden.hex`, language-pair handoffs | unchanged runs | bytes unchanged | project AC-3 |

## Constraints

- ADR-001: TypeScript walker only.
- Browser-safe: no `node:` imports, `Buffer` or `process` in `src`.
- Public result types keep their shape (`ShortErr`, `TypeMismatchErr`, `DispatchResult`).
- Wire bytes unchanged.

## Risks & Mitigation

**Risk 1: Worker-based hang test is flaky on CI**
- *Risk*: Timing-based tests can be slow in containers.
- *Mitigation*: Use a 5 s bound only as a kill switch. The assertion is "returned an error", not a tight time.

**Risk 2: C15 changes the shapes**
- *Mitigation*: One helper in the tests asserts the interim shape.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind for bad values is undecided (C15); interim uses the documented duplicate-key shape | user / C15 | open | Medium |
| Task 01 vector format not written yet | task 01 writer (D) | open | Low |
| Trailing bytes are still a `ShortErr` with `field ""` in TS only (other packages have `TrailingBytes`) — kept until C15 | C15 | accepted-risk | Low |
