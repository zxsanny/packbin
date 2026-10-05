# C# unpack never hangs or throws on hostile packets

**Task**: AZ-2073_csharp_hostile_unpack
**Name**: C# hostile-packet unpack
**Description**: Every C# unpack of a crafted packet returns an error value: no infinite loop, no exception.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors
**Component**: csharp
**Tracker**: AZ-2073
**Epic**: AZ-2069

## Problem

`BinaryPacker.Unpack` reads bytes from the network. A crafted packet can hang the receiver or make it throw. The contract (project AC-8/AC-9, `components/01_csharp_package/description.md`) says unpack returns an error value and calls no handler. Found in the 2026-10-05 assessment (`_docs/04_refactoring/02-whole-project-assessment/discovery/scan_csharp_java.md` L9, L10). Each probe below was reproduced against a copy of the sources at `d108141`.

### Defect 1 — zero-progress `repeat` loops forever
- `csharp/Walker.cs:356-375` `UnpackRepeat` loops `while (offset < bytes.Length)` and runs the body again even when a round read 0 bytes.
- Probe: `new Scheme<BoolRow>(1, Field.Repeat(0, Field.Bool<BoolRow>(0, x => x.Straight)))`; `BinaryPacker.Read(scheme, 01 09)` → **never returns** (3 s timeout).
- After tasks 10 and 18 a `bool` or a `when` can no longer be a repeat body. A zero-width body is still possible with `Field.Bytes<T>(id, x => x.B, 0)` (n = 0 is accepted, `Field.cs:117`). Use that form for the regression test.
- Other packages: the same hang exists in TypeScript, Python, Java and Rust (tasks 02, 03, 05, 06). C++ is not affected.

### Defect 2 — counts read from the packet throw
| Probe (scheme; hex after the type byte) | Today | Code |
|---|---|---|
| `U32 N` + `Sized(1, x => x.P, 0)`; `01 ff ff ff ff` | `OverflowException` (Int32 conversion of a `uint`) | `Walker.Counted.cs:69-71` |
| `I8 N` + `Sized(1, …, 0)`; `01 ff` (count −1) | `ArgumentOutOfRangeException` (`Slice(offset, -1)`) | `Walker.Counted.cs:73-75` |
| `I8 N` + `Bits(1, …, 0)`; `01 ff` | `ArgumentOutOfRangeException` (`new List<int>(-1)`) | `Walker.Counted.cs:109-116` |
| `I8 N` + `Times(1, 0, U8 X)`; `01 ff` | `ArgumentException: times: item count -1` | `Walker.Counted.cs:124-130` (`BorrowedCount`), `:196` |
| `I8 N` + `Packed(2, 1, …, 0)`; `01 ff` | `ArgumentException: … item count -1` | `Walker.Counted.cs:162` |
| `U32 N` + `Times(1, 0, U8 X)`; `01 ff ff ff 7f` | `ShortPacket('X', 1, 0)` — already correct | — |

### Defect 3 — a count behind a clear flag bit throws
- Probe: `Flags(0, U8<CountRow>(0, x => x.N))` + `Sized<CountRow>(1, x => x.P, 0)`; bytes `01 00 09` (flag clear, so `N` is absent) → `InvalidOperationException: P: count 'N' is missing`.
- Code: `Walker.Counted.cs:69-70` (Sized), `:109-110` (Bits), `:57-58` via `RequireCount` (Packed, Times).
- TypeScript and Python throw here too (tasks 02/03). Java throws `IllegalStateException` (task 05).

### Defect 4 — invalid UTF-8 is accepted silently
- Probe: `Utf8<Utf8Row>(0, x => x.Name)`; bytes `01 02 00 ff fe` → no error, and `Name` becomes two U+FFFD characters. `Walker.Counted.cs:249` and dict keys at `:351` use the lenient `Encoding.UTF8.GetString`.
- Python raises `UnicodeDecodeError`, TypeScript a `TypeError`, Java replaces silently like C#, C++ keeps the raw bytes. Task 01 fixes the expected result for `invalid_utf8`.

## Outcome

- Each of the five hostile vectors from task 01 returns the error kind task 01 lists for it. No exception, no handler call, and the call finishes in well under 1 s.
- Valid packets, the golden hex and all existing tests are unchanged.

## Scope

### Included
- Unpack paths of `repeat`, `sized`, `bits`, `packed`, `times`, `utf8` and dict keys.
- A reader in `csharp/tests` that runs the task 01 vector file (`fixtures/hostile/`) through `BinaryPacker.Unpack`.
- One named constant for the 65 535 count limit (`Walker.Counted.cs:227,259,301,309`).

### Excluded
- Pack-side validation (task 19).
- Error labels and new error kinds beyond what this task needs (C15, not decided).
- `PackSession.Unpack`: it calls the same `BinaryPacker.Unpack` after the XOR, so it inherits the fix with no separate work.

## Acceptance Criteria

**AC-1: Zero-progress repeat ends**
Given a scheme whose `repeat` body can read 0 bytes (`zero_progress_repeat`)
When a packet with bytes left after the last full round is unpacked
Then unpack returns the task 01 error for that vector (expected `TrailingBytes` with `Left` = bytes not consumed) within 1 s, and the handler is not called.

**AC-2: Negative count**
Given a borrowed count read as a negative number (`negative_count`) for `sized`, `bits`, `packed` or `times`
When the packet is unpacked
Then unpack returns the task 01 error for `negative_count` and throws nothing.

**AC-3: Oversize count**
Given a count larger than the bytes left, including counts above `int.MaxValue` from a `u32`/`u64` (`oversize_count`)
When the packet is unpacked
Then unpack returns `ShortPacket` naming the counted field, with `Left` = bytes remaining, and throws nothing.

**AC-4: Count behind a clear flag bit**
Given a count field inside a flag bit that is clear (`count_behind_clear_flag`)
When the counted field is unpacked
Then unpack returns the task 01 error for that vector and throws nothing.

**AC-5: Invalid UTF-8**
Given a `utf8` field or dict key whose bytes are not valid UTF-8 (`invalid_utf8`)
When the packet is unpacked
Then unpack returns the task 01 error for `invalid_utf8`. No replacement characters reach the row.

**AC-6: Valid packets unchanged**
Given every existing test and the golden fixture
When the suite runs
Then all pass, and the packed bytes are identical to before.

## Non-Functional Requirements

**Performance**
- AC-10 still passes: 100 000 position round trips ≤ 1 s.

**Reliability**
- No exception type escapes `BinaryPacker.Unpack` for any byte input to a valid scheme. The only exception left is the documented duplicate-type-number `ArgumentException`, a caller error.

## Unit Tests

Write these first; each must fail on the current code.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `Repeat(0, Bytes(0, x => x.B, 0))`, bytes `01 09`, run on a task with a 2 s timeout | returns the AC-1 error; does not time out |
| AC-1 | today's probe `Repeat(0, Bool(0, …))`, `01 09` (keep only until task 10 makes it a construction error) | no hang |
| AC-2 | `I8 N` + `Sized(1, P, 0)`, `01 ff` | error value, no exception |
| AC-2 | the same with `Bits`, `Packed(2,…)` and `Times` | error value for each |
| AC-3 | `U32 N` + `Sized(1, P, 0)`, `01 ff ff ff ff` | `ShortPacket(field "P", Left 0)` |
| AC-3 | `U32 N` + `Bits(1, …, 0)`, `01 ff ff ff ff` | `ShortPacket`, no `OverflowException` |
| AC-4 | `Flags(0, U8 N)` + `Sized(1, P, 0)`, `01 00 09` | error value, no `InvalidOperationException` |
| AC-5 | `Utf8 Name`, `01 02 00 ff fe` | error value; handler not called |
| AC-5 | dict key `ff`, `Dict(… Utf8 V)`, `01 01 00 01 00 ff 00 00` | error value |
| AC-6 | existing `LayoutTests`, `BorrowedCountTests` (route `3410…`) | still pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `fixtures/hostile/` `zero_progress_repeat_bool`, packet `01ff` | C# suite unpacks it | `trailing_bytes`, or `scheme_error` once task 10 rejects `bool` outside flags; < 1 s | Reliability |
| AC-1 | `zero_progress_repeat_when`, packet `0100ff` | unpack | `trailing_bytes`, or `scheme_error` once task 18 rejects the outer reference; < 1 s | Reliability |
| AC-2 | `negative_count`, packet `01ff61` (`i8 n` = −1, `sized`) | unpack | `bad_value` or `short_packet` | Reliability |
| AC-3 | `oversize_count`, `01ffffffff61`; `oversize_count_times`, `01ffffffff00`; `oversize_list_count`, `01ffff` | unpack | `short_packet` | Reliability |
| AC-4 | `count_behind_clear_flag`, `0100` (`sized`); `count_behind_clear_flag_bits`, `0100` | unpack | `bad_value` or `scheme_error` | Reliability |
| AC-5 | `invalid_utf8`, `010200c328`; `invalid_utf8_dict_key`, `0101000100ff00` | unpack | `bad_value` or `short_packet` | Reliability |
| AC-6 | `fixtures/golden.hex`, language-pair run | pack/unpack | 0 mismatched bytes | AC-10 |

Interim rule from task 01 (until C15): if C# has no type for a listed kind, any non-ok unpack result that is **not an exception** passes. The test name or message states the kind actually returned (e.g. `negative_count -> ShortPacket`).

## Constraints

- ADR-001: C# keeps its own walker. Do not import or share code with other packages. The vectors are data read from a file.
- Wire bytes of valid packets do not change.
- Keep to the existing error types where task 01's kind maps onto one. See Flagged concerns for kinds C# does not have.
- `Walker.Counted.cs` is 376 lines. Keep every file under 500.

## Risks & Mitigation

**Risk 1: Rejecting a legitimate zero-width round**
- *Risk*: a `repeat` whose body is legitimately empty on some rounds.
- *Mitigation*: an empty round with bytes left can never finish the packet, because repeat runs to the end of the buffer. Ending with an error is the only outcome that terminates.

**Risk 2: Strict UTF-8 rejects data that used to unpack**
- *Mitigation*: our own pack never produces invalid UTF-8 (`Encoding.UTF8.GetBytes` of a .NET string). Only foreign or corrupted bytes are affected.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| C# has no `bad_value` type. Task 01's interim rule accepts any non-ok, non-exception result (here `ShortPacket` for `negative_count`, `invalid_utf8` and `count_behind_clear_flag`), and the test states the kind returned. A real `BadValue` error is a public API addition that waits for C15. Do not add it in this task. | user / C15 | open | Medium |
| `ShortPacket.Needed` is `int`. A `u32` count above `int.MaxValue` cannot be reported exactly. Take the value from task 01's vector. Propose `int.MaxValue` if the vector leaves it open. | task 01 author | open | Low |
| `times` with a zero-width body and a huge count (`u32`) still runs up to 2³²−1 empty rounds: finite but slow. Not covered by C03. | security audit | accepted-risk | Low |
