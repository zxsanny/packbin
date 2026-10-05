---
loop: 11
---

# C# unpack keeps flags state per call

**Task**: AZ-2076_csharp_unpack_state_per_call
**Name**: C# thread-safe flags unpack
**Description**: Two threads unpacking with one shared scheme always get the correct rows.
**Complexity**: 2 points
**Dependencies**: None
**Component**: csharp
**Tracker**: AZ-2076
**Epic**: AZ-2069

## Problem

Schemes are meant to be built once and shared. The README and tests declare them `static readonly`. The architecture NFR says "one call does not share state with another". C# unpack breaks this: it writes the flags byte it reads into the **scheme object** and then reads it back.

- `csharp/Walker.cs:6-35` `FlagGroup` has a mutable `public byte Unpacked { get; set; }` (line 10). The group belongs to the `Field` built at scheme construction (`Field.cs:170-177` `Flags`, `:164-168` `FlagByte`).
- `Walker.cs:274-293` `UnpackFlags` stores the byte with `field.FlagOwner!.Unpacked = flags` (line 285), then calls `UnpackFlagBit` for each child. `UnpackFlagBit` (`:310-320`) decides presence from `field.FlagOwner!.Unpacked` (line 317), **not** from the local `flags`.
- `Walker.cs:295-308` `UnpackFlagByte` (split form `Field.FlagByte()` + `.Bit(...)`) stores at line 306. Each later `.Bit` field reads it back at line 317.
- Between the store and the read, another thread unpacking with the same scheme can overwrite `Unpacked`. The row then gets fields its packet does not hold, or loses fields it does hold. Offsets shift, and the call returns a wrong row or a spurious `ShortPacket`/`TrailingBytes`.

**Reproduction (probe, copy of sources at `d108141`, .NET 10, Release)**:
- Scheme `new Scheme<RaceRow>(1, Field.Flags(0, Field.U8<RaceRow>(0, x => x.A), Field.U8<RaceRow>(1, x => x.B)))`, where `RaceRow { byte? A; byte? B; }`.
- `onlyA = Pack(new RaceRow { A = 7 })` → `01 01 07`; `onlyB = Pack(new RaceRow { B = 8 })` → `01 02 08`.
- Thread 1 unpacks `onlyA` 200 000 times and expects `A == 7`, `B == null`, no error. Thread 2 unpacks `onlyB` 200 000 times and expects the mirror.
- Result: **2 860 wrong results out of 400 000** (wrong row or error).
- Existing tests only check concurrent **pack** (`LayoutTests.cs:458-466`), which has no shared state.

Cross-language: Java has the same defect for the split `flagByte()` form (11 593 / 400 000, task 08); its combined `flags()` form reads a local and is safe. C++ (task 09) keys flag bytes per walk. Rust (task 13) shares a bit counter at construction. TypeScript and Python keep flag bytes in per-call maps.

## Outcome

- Unpack keeps every flags byte it reads in state owned by that one call (and by the current scope inside it). Nothing on `Scheme`, `Field` or `FlagGroup` changes during pack or unpack.
- The concurrent probe above gives 0 wrong results, for both the `Flags` form and the split `FlagByte`/`.Bit` form.

## Scope

### Included
- `FlagGroup.Unpacked` removed. The value read lives in per-call state, keyed by the flag group, so a split-form `.Bit` field finds the byte its own `FlagByte` read earlier in the same call.
- A repeat/list/dict scope that contains its own flags byte keeps its own value per round.
- The first tests of the split form `Field.FlagByte()` + `.Bit(...)`: today 0 tests cover it in C#.

### Excluded
- `SchemeOrder` mutating `Field.CountName` / `Condition.FieldName` at construction (task 19 "scheme owns its field list").
- The bool presence rule and the 8-bit cap (task 10).
- Thread safety of `PackSession`: it is caller-held, and its counters are per instance by contract.

## Acceptance Criteria

**AC-1: Concurrent unpack, combined form**
Given one `static readonly` scheme with `Flags(0, U8 A, U8 B)` and the packets `01 01 07` and `01 02 08`
When two threads each unpack one of them 200 000 times at the same time
Then all 400 000 calls return no error, and every row holds exactly the field its packet sets.

**AC-2: Concurrent unpack, split form**
Given a scheme `FlagByte()` m, `m.Bit(U8 A)`, `m.Bit(U8 B)` and packets with only A and only B
When two threads unpack them concurrently as in AC-1
Then 0 wrong results.

**AC-3: Scheme is immutable during use**
Given any scheme
When it packs and unpacks
Then no member of the scheme, its fields or its flag groups changes value.

**AC-4: Bytes unchanged**
Given the golden fixture, the route fixture `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` and all existing tests
When the suite runs
Then all pass with identical bytes.

**AC-5: Split form round-trips**
Given the split form with a group between the flag byte and its bits, as in the schema "split form" (flag byte, a `When` group, then `m.Bit(U16 Heading)`, `m.Bit(U8 Speed)`)
When a row with `Heading = 90` is packed and unpacked
Then the flag byte is `01`, the bytes match the TypeScript/Python split-form output for the same row, and the row comes back equal.

## Non-Functional Requirements

**Performance**
- AC-10 still ≤ 1 s. Per-call flag state must not add a per-field allocation on the position packet: one small map or array per call at most.

**Reliability**
- Unpack is safe to call from any number of threads with one scheme.

## Unit Tests

Write these first; AC-1 and AC-2 must fail on the current code.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | two threads × 200 000 unpacks of `01 01 07` / `01 02 08` with one `Flags` scheme (the probe) | 0 wrong rows, 0 errors |
| AC-2 | same with the split `FlagByte` scheme | 0 wrong rows, 0 errors |
| AC-3 | reflect over the scheme's `FlagGroup` instances before and after 1 000 unpacks of different packets | no settable runtime member exists |
| AC-5 | split form with `Heading = 90`, `Speed` and `Altitude` absent | `motion` byte `01`, `5a 00` follows, round-trip equal |
| AC-5 | split form, clear byte `00` with leftover bytes | `TrailingBytes`, no fields set |
| AC-4 | existing `PackbinTests`, `LayoutTests.FlagGroup_*`, `ObjectBindingTests` | still pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `fixtures/golden.hex` | pack/unpack the position row | `4001000065cd1d00a3e1110100` both ways | AC-10 |
| AC-4 | `language-pair.sh` C# ↔ each language | handoff of position, user and nested cases | 0 mismatched bytes | — |

## Constraints

- ADR-001: no shared code with Java's fix (task 08). Each package keeps its own walker.
- No public API change. `FlagGroup` is internal.
- Wire bytes unchanged.

## Risks & Mitigation

**Risk 1: Flaky concurrency test**
- *Risk*: a race test can pass by luck on a fast machine.
- *Mitigation*: 200 000 iterations per thread showed 2 860 failures on the current code. Keep that count, and add the deterministic AC-3 check that no runtime state exists on the scheme.

**Risk 2: Split form is untested today**
- *Mitigation*: add the AC-5 tests before changing the code, so the refactor has a baseline.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The split form `FlagByte()`/`.Bit()` has no C# tests today. Its expected bytes for AC-5 must be taken from the TypeScript/Python split-form tests, not guessed. | implementer | open | Low |
