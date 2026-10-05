---
loop: 11
branch: loop/11-hostile-unpack
---

# Java unpack never hangs or throws on hostile packets

**Task**: AZ-2074_java_hostile_unpack
**Name**: Java hostile-packet unpack
**Description**: Every Java unpack of a crafted packet returns an error value: no infinite loop, no exception.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors
**Component**: java
**Tracker**: AZ-2074
**Epic**: AZ-2069

## Problem

`BinaryPacker.unpack(byte[], Handler...)` is what an Android app calls on bytes from the network. A crafted packet can hang it or throw an unchecked exception. The contract (project AC-8/AC-9, `components/06_java_package/description.md`) is error-as-value with no handler call. Found in the 2026-10-05 assessment (`scan_csharp_java.md` L9, L10). Each probe below was reproduced against a copy of the sources at `d108141` with JDK 21.

### Defect 1 — zero-progress `repeat` loops forever
- `java/src/main/java/packbin/Walker.java:334-343` `unpackRepeat` loops `while (offset[0] < data.length)` even when a round read 0 bytes.
- Probe: `repeat(0, boolField(0, Access.get("b"), Access.set("b")))` on a `Map` scheme, bytes `01 09` → **never returns** (3 s timeout).
- After task 20, `boolField` outside flags (including directly in a repeat) is a construction error. A zero-width body is still possible with `bytes(0, get, set, 0)` (`Packbin.java:46-51` accepts n = 0). Use that form for the regression test.
- Other packages: the same hang exists in C#, TypeScript, Python and Rust (tasks 04, 02, 03, 06).

### Defect 2 — counts read from the packet throw
| Probe (Map scheme; hex) | Today | Code |
|---|---|---|
| `u32(0,n)` + `sized(1,p,0)`; `01 ff ff ff ff` | `NegativeArraySizeException: -1` (`Long.intValue()` wraps to −1) | `VarFields.java:46,48,51` |
| `i8(0,n)` + `bits(1,p,0)`; `01 ff` | `IllegalArgumentException: Illegal Capacity: -1` | `VarFields.java:128-134` |
| `i8(0,n)` + `times(1,0,u8(1,x))`; `01 ff` | `IllegalArgumentException: times: item count -1` | `VarFields.java:144-154`, `:411` |
| `i8(0,n)` + `packed(2,1,k,0,0)`; `01 ff` | `IllegalArgumentException` | `VarFields.java:187` |
| `u32(0,n)` + `times(1,0,u8(1,x))`; `01 ff ff ff 7f` | `ShortPacket(field "1", needed 1, left 0)` — already correct | — |

A `u32` count of `0x80000000` and above, and a `u64` count of any size, wraps when narrowed with `intValue()`. A large positive count can therefore turn into a small or negative one: the reader works with a different length than the packet states.

### Defect 3 — a count behind a clear flag bit throws
- Probe: `flags(0, u8(0,n))` + `sized(1,p,0)`; bytes `01 00 09` → `IllegalStateException: 1: count 0 is missing`.
- Code: `VarFields.java:42-45` (sized), `:124-127` (bits), `:145-148` (`borrowedCount`, used by packed and times).
- C# throws `InvalidOperationException`; TypeScript and Python throw too. Tasks 04, 02, 03.

### Defect 4 — invalid UTF-8 is accepted silently
- Probe: `utf8(0,name)`, bytes `01 02 00 ff fe` → no error; `name` is two U+FFFD characters (`VarFields.java:279`). Dict keys behave the same (`:388`).
- Python and TypeScript raise; C# replaces like Java; C++ keeps the raw bytes. Task 01 fixes the expected result.

## Outcome

- Each of the five hostile vectors from task 01 returns the error kind task 01 lists. No exception, no handler call, under 1 s.
- Counts are compared as 64-bit values before any narrowing, so no count wraps.
- Valid packets, the golden hex and all existing tests are unchanged.

## Scope

### Included
- Unpack paths of `repeat`, `sized`, `bits`, `packed`, `times`, `utf8` and dict keys, plus list elements that go through `unpackElement`.
- `java/src/test`: a reader that runs the `fixtures/hostile/` vectors through `BinaryPacker.unpack`, registered in the runner `PackbinTest.main`.
- One named constant for 65 535 (`VarFields.java:254,290,332,349`).

### Excluded
- Pack-side checks.
- Error label rules and new error kinds beyond this task (C15).
- Flags state (task 08) and nested rows (task 32).

## Acceptance Criteria

**AC-1: Zero-progress repeat ends**
Given a scheme whose `repeat` body can read 0 bytes (`zero_progress_repeat`)
When a packet with bytes left after the last full round is unpacked
Then unpack returns the task 01 error (expected `TrailingBytes` with `left` = bytes not consumed) within 1 s, and the handler is not called.

**AC-2: Negative count**
Given a borrowed count read as a negative number (`negative_count`)
When `sized`, `bits`, `packed` or `times` is unpacked
Then unpack returns the task 01 error for `negative_count` and throws nothing.

**AC-3: Oversize count, no narrowing**
Given a count larger than the bytes left, including a `u32` ≥ 2³¹ or any `u64` (`oversize_count`)
When the packet is unpacked
Then unpack returns `ShortPacket` naming the counted field, with `left` = bytes remaining. It never reads a wrapped, smaller length.

**AC-4: Count behind a clear flag bit**
Given a count field in a clear flag bit (`count_behind_clear_flag`)
When the counted field is unpacked
Then unpack returns the task 01 error and throws nothing.

**AC-5: Invalid UTF-8**
Given a `utf8` field or dict key with bytes that are not valid UTF-8 (`invalid_utf8`)
When the packet is unpacked
Then unpack returns the task 01 error. The row never receives U+FFFD replacements.

**AC-6: Valid packets unchanged**
Given the existing Java tests, the golden fixture and the language-pair handoff
When they run
Then all pass with identical bytes.

## Non-Functional Requirements

**Performance**
- `nfrRoundTripsWithinOneSecond` still passes.

**Compatibility**
- Strict decoding uses APIs available on Android API 26 (user decision 2026-10-05; task 25 enforces `--release 17` / API 26), e.g. a `CharsetDecoder` with `CodingErrorAction.REPORT`.

**Reliability**
- No unchecked exception escapes `BinaryPacker.unpack` for any byte input to a valid scheme (duplicate type numbers remain a caller error).

## Unit Tests

Write these first; each must fail on the current code. Each test runs inside the existing hand-written runner.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `repeat(0, bytes(0, get("b"), set("b"), 0))`, `01 09`, on a daemon thread with a 2 s join | returns the AC-1 error; the thread finishes |
| AC-2 | `i8 n` + `sized(1,p,0)`, `01 ff` | error value, no exception |
| AC-2 | same with `bits`, `packed(2,…)`, `times` | error value each |
| AC-3 | `u32 n` + `sized(1,p,0)`, `01 ff ff ff ff` | `ShortPacket(field "1", left 0)`; no `NegativeArraySizeException` |
| AC-3 | `u32 n` + `bits(1,p,0)`, `01 00 00 00 80` | `ShortPacket`, not an empty or wrapped read |
| AC-4 | `flags(0,u8(0,n))` + `sized(1,p,0)`, `01 00 09` | error value, no `IllegalStateException` |
| AC-5 | `utf8(0,name)`, `01 02 00 ff fe` | error value, handler not called |
| AC-5 | `dict(… utf8)`, key `ff`: `01 01 00 01 00 ff 00 00` | error value |
| AC-6 | `PackbinFieldsTest.borrowedCount` (route `3410…`), `dictionary` (F-AC-1 hex) | still pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/hostile/` `zero_progress_repeat_bool`, packet `01ff` | Java suite unpacks it | `trailing_bytes`, or `scheme_error` once task 20 rejects `bool` outside flags; < 1 s | Reliability |
| AC-1 | `zero_progress_repeat_when`, packet `0100ff` | unpack | `trailing_bytes`, or `scheme_error` once task 20 rejects the outer reference; < 1 s | Reliability |
| AC-2 | `negative_count`, packet `01ff61` (`i8 n` = −1, `sized`) | unpack | `bad_value` or `short_packet` | Reliability |
| AC-3 | `oversize_count`, `01ffffffff61`; `oversize_count_times`, `01ffffffff00`; `oversize_list_count`, `01ffff` | unpack | `short_packet` | Reliability |
| AC-4 | `count_behind_clear_flag`, `0100` (`sized`); `count_behind_clear_flag_bits`, `0100` | unpack | `bad_value` or `scheme_error` | Reliability |
| AC-5 | `invalid_utf8`, `010200c328`; `invalid_utf8_dict_key`, `0101000100ff00` | unpack | `bad_value` or `short_packet` | Reliability |
| AC-6 | `fixtures/golden.hex`, language-pair run | pack/unpack | 0 mismatched bytes | AC-10 |

Interim rule from task 01 (until C15): if Java has no type for a listed kind, any non-ok unpack result that is **not an exception** passes. The test name or message states the kind actually returned (e.g. `negative_count -> ShortPacket`).

## Constraints

- ADR-001: Java walks its own list. Vectors are data files.
- No build tool or new dependency. Keep `java/test.sh` + `javac`.
- `Walker.java` is 497 lines. If the fix would push it over 500, move a cohesive part (for example the scalar codec `writeScalar`/`readScalar`/`require*`, lines 429-496) into its own file.
- Wire bytes of valid packets unchanged.

## Risks & Mitigation

**Risk 1: Walker.java crosses the 500-line cap**
- *Mitigation*: split by responsibility, as noted under Constraints, in the same change.

**Risk 2: Strict UTF-8 breaks a caller that relied on replacement**
- *Mitigation*: Java pack (`String.getBytes(UTF_8)`) never emits invalid UTF-8, so only corrupted input is affected.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Java has no `bad_value` type. Task 01's interim rule accepts any non-ok, non-exception result (here `ShortPacket` for `negative_count`, `invalid_utf8` and `count_behind_clear_flag`), and the test states the kind returned. A real `BadValue` error is a public API addition that waits for C15. Do not add it in this task. | user / C15 | open | Medium |
| `ShortPacket.needed` is `int`. A `u64` or large `u32` count cannot be reported exactly. Use task 01's value (proposal: `Integer.MAX_VALUE`). | task 01 author | open | Low |
| `times` with a zero-width body and a huge count runs up to 2³²−1 empty rounds: finite but slow. | security audit | accepted-risk | Low |
