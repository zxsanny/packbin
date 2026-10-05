---
loop: 11
---

# Python unpack never hangs or throws on hostile packets

**Task**: AZ-2071_python_hostile_unpack
**Name**: Python hostile-packet unpack
**Description**: `BinaryPacker.unpack` and `PackSession.unpack` return an error result, never loop forever and never raise, for every packet the shared hostile vectors describe.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors
**Component**: python
**Tracker**: AZ-2071
**Epic**: AZ-2069

## Problem

Unpack runs on bytes from the network. Today some of those bytes hang the receiver or crash it with an exception instead of returning `UnpackResult(ok=False)`. All five cases below were reproduced on `d108141` from a scratch script importing `python/src`.

| # | Case | Scheme (type 1, row `dict`) | Bytes (hex) | Today | Code |
|---|------|------------------------------|-------------|-------|------|
| 1 | zero-progress repeat | `u8(0, k)`, `repeat(1, when(1, eq(0, 9), u8(1, v)))` | `010005` | **hangs**: the process was killed by a 5 s alarm (exit 142). The `when` never matches, so a repeat round reads 0 bytes while bytes are left | `_unpack.py:269-275` (`while offset < len(data)` with no progress check) |
| 2a | negative count, signed source | `i8(0, n)`, `sized(1, p, 0)` | `01fd616263` | count −3 moves `offset` **backwards** (`_unpack.py:281-284`); result `TrailingBytes(left=6)` for a 5-byte buffer | `_unpack.py:276-286` |
| 2b | | `i8(0, n)`, `bits(1, b, 0)` / `packed(2, 1, k, 0)` / `times(1, 0, u8(1, v))` | `01fd` | `ok=True`, `b=[]` / `k=[]` / no items. The negative count is silently read as "none" (`range(-3)`, `_read_packed` with `count<0`) | `_unpack.py:49-60`, `296-327` |
| 2c | negative count from bias | `u8(0, n)`, `packed(1, 1, legs, 0, -1)` | `0100` | `ok=True`, `legs=[]` (item count −1). Pack of the same row raises `ValueError: item count -1` (`_pack.py:88-90`), so the two directions disagree | `_unpack.py:306-317` |
| 3 | invalid UTF-8 | `utf8(0, s)` / `dict(d, u8(0, ·))` | `010100ff` / `0101000100ff05` | raises `UnicodeDecodeError` out of `unpack` | `_unpack.py:119`, `178`, `339` |
| 4 | count behind a clear flag | `flags(0, u8(0, n))` then `sized(1, p, 0)` / `bits(1, b, 0)` / `packed(2, 1, k, 0)` / `times(1, 0, u8(1, v))` | `0100` | raises `RuntimeError: 1: count 0 is missing` (or `count is missing` / `times: count is missing`) | `_unpack.py:278-279`, `298-299`, `309-310`, `320-321` |
| 5 | oversize count | list count `ffff` with one element `01ffff0100`; utf8 length `ffff` `01ffff61`; times 255 `01ff0102`; sized 255 `01ff0102`; dict count `ffff` `01ffff` | already `ShortPacket`, handler not called. **Keep** (regression only) | — |

Cross-language: TypeScript has the same hang (task 03) and throws `TypeError`/`RangeError` for cases 3 and 4. C# and Java hang on case 1 and throw on negative/oversize counts (tasks 04/05). Rust hangs on case 1 (task 06).

## Outcome

- Every vector in `fixtures/hostile/` unpacks to `ok=False`, `value=None`, with the handler not called, no exception, in under 1 s.
- Pack and unpack agree: a count that pack refuses (negative item count) is also refused by unpack.
- The golden vector, the language-pair handoffs and the existing 44 tests keep passing unchanged.

## Scope

### Included
- Clear unpack (`BinaryPacker.unpack`) and session unpack (`PackSession.unpack`, which calls clear unpack after removing the pad).
- A repeat round that consumes 0 bytes ends the repeat. The unread bytes are then reported by the existing trailing-bytes check.
- Negative counts (signed source or bias), invalid UTF-8 (string, dictionary key, string list element), and a count whose source field is absent all return an error result.
- A test module that reads every vector in `fixtures/hostile/` and declares the scheme each vector names.

### Excluded
- New error types or a new field-label rule. That is C15, not decided. See the interim mapping below.
- Pack-side behavior. Pack keeps raising on bad rows.
- Split-form flag bytes (task 31), and the `bool` rule (task 14).

## Interim error mapping (until C15)

| Vector kind (as task 01 names it) | Python result |
|-----------------------------------|---------------|
| zero_progress_repeat | `TrailingBytes(left=<bytes not consumed>)`; for `010005` → `left=1` |
| oversize_count | `ShortPacket(field, needed, left)` exactly as today |
| negative_count, invalid_utf8, count_behind_clear_flag | `ShortPacket(field=<label of the field that could not be read>, needed=0, left=<bytes left at that field>)`. This is the precedent already used for a duplicate dictionary key (strings-lists-dicts F-AC-9). The label is today's Python label (`str(field_id)`, `""` for dict keys) |

If task 01 records a different expected kind for a case, the vector wins and this table is updated.

## Acceptance Criteria

**AC-1: Zero-progress repeat ends**
Given the scheme `u8(0, k)`, `repeat(1, when(1, eq(0, 9), u8(1, v)))`
When `010005` is unpacked
Then the call returns within 1 s with `ok=False`, `error=TrailingBytes(left=1)`, `value=None`, and the handler is not called

**AC-2: Repeat that progresses is unchanged**
Given `repeat(0, i32(0, lat), i32(1, lon))`
When the README two-point buffer `010a000000140000001e00000028000000` is unpacked
Then `lat == [10, 30]` and `lon == [20, 40]`, and one extra byte still gives an error with 0 values (AC-7)

**AC-3: Negative counts are errors**
Given each scheme in rows 2a–2c
When its bytes are unpacked
Then the result is `ok=False` with a `ShortPacket` naming the counted field and `needed=0`; the offset never moves backwards and no value is returned

**AC-4: Invalid UTF-8 is an error**
Given `utf8(0, s)` and `dict(d, u8(0, ·))`
When `010100ff` and `0101000100ff05` are unpacked
Then each returns `ok=False` with a `ShortPacket` (no `UnicodeDecodeError` escapes)

**AC-5: Missing count source is an error**
Given `flags(0, u8(0, n))` followed by `sized`, `bits`, `packed` or `times` counting on field 0
When `0100` is unpacked
Then each returns `ok=False` with a `ShortPacket` naming the counted field; no `RuntimeError`

**AC-6: Shared vectors**
Given every file in `fixtures/hostile/`
When this package's vector test runs
Then each vector yields `ok=False`, `value=None`, handler not called, no exception, under 1 s, with the error kind the vector records (mapped per the table above)

**AC-7: Session path**
Given an opened `PackSession` pair
When the waiter unpacks a payload whose clear bytes are vector 1 (`010005`)
Then it returns the same error as clear unpack, within 1 s

## Non-Functional Requirements

**Performance**
- AC-10 Python loop (100 000 round trips) stays ≤ 2 s. The progress check is one integer compare per repeat round.

**Reliability**
- No input byte sequence makes unpack loop without consuming input or raise an exception.

## Unit Tests

Write these first. They must fail on `d108141`. Guard the hang test with a timeout (e.g. run the unpack in a subprocess or thread with a 5 s join) so a regression fails instead of hanging CI.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `test_zero_progress_repeat_ends` | scheme row 1, `010005` | `ok False`, `TrailingBytes(left=1)`, handler not called, < 1 s |
| AC-2 | existing `test_repeat_group_boundary` | unchanged | still passes |
| AC-3 | `test_negative_sized_count_is_error` | `i8`, `sized`, `01fd616263` | `ok False`, `ShortPacket.needed == 0` |
| AC-3 | `test_negative_bits_packed_times_count_is_error` | `01fd` × 3 schemes | `ok False` each |
| AC-3 | `test_bias_below_zero_is_error` | `packed(1,1,legs,0,-1)`, `0100` | `ok False` |
| AC-4 | `test_invalid_utf8_string_is_error` | `010100ff` | `ok False`, no exception |
| AC-4 | `test_invalid_utf8_dict_key_is_error` | `0101000100ff05` | `ok False`, no exception |
| AC-5 | `test_count_behind_clear_flag_is_error` | 4 schemes, `0100` | `ok False` each, no `RuntimeError` |
| AC-7 | `test_session_unpack_hostile_payload` | pad(`010005`) | same error as clear |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/hostile/` case `zero_progress_repeat` | unpack the vector hex with the scheme it names | error (trailing), handler not called, < 1 s | Reliability |
| AC-6 | case `negative_count` | same | error, no value | Reliability |
| AC-6 | case `oversize_count` | same | short packet, no value | Reliability |
| AC-6 | case `invalid_utf8` | same | error, no exception | Reliability |
| AC-6 | case `count_behind_clear_flag` | same | error, no exception | Reliability |
| AC-2 | `fixtures/golden.hex` + language-pair `user`/`nested`/`session` handoffs | pack/unpack as today | bytes unchanged | AC-3 (project) |

## Constraints

- ADR-001: the fix is in the Python walker only. No shared walker, and no import from another package.
- Wire bytes are unchanged for every packet that unpacks today.
- `UnpackResult`, `ShortPacket`, `TrailingBytes` and `TypeMismatch` keep their public shape (no new public types before C15).
- Python ≥ 3.10, no new runtime dependency.

## Risks & Mitigation

**Risk 1: A real schema relied on an empty repeat body**
- *Risk*: A scheme whose repeat body is all optional may now report trailing bytes where it used to hang.
- *Mitigation*: Hanging was never a valid outcome. The error names the unread byte count.

**Risk 2: Interim labels change again with C15**
- *Risk*: Tests asserting `needed == 0` will change when C15 lands.
- *Mitigation*: Assert the kind through one test helper so C15 edits a single place.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind and label for bad values are not decided (C15). This task uses the documented duplicate-key precedent (`needed=0`) as an interim | user / C15 | open | Medium |
| Task 01's vector format and kind names are not written yet; the mapping table may need renaming | task 01 writer (D) | open | Low |
| `repeat` with an optional field gives a shorter list than its siblings (positions are lost). This is not a hostile case; it is noted for C15/C21 | coordinator | open | Low |
