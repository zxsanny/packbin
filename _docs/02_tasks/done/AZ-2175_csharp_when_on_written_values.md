# C# pack evaluates `when` on the values it wrote

**Task**: AZ-2175_csharp_when_on_written_values
**Name**: C# `when` reads what pack wrote
**Description**: A `when` whose tested field was not written reads as not matching on pack, the same rule unpack applies, so pack never returns bytes its own read rejects or misparses; plus tests that pin the PackSession counter after a failed pack and a split-form flag byte inside a round.
**Complexity**: 5 points
**Dependencies**: AZ-2087_csharp_forward_refs (round slicing), AZ-2088_csharp_pack_fails_loudly (loud pack)
**Component**: csharp
**Tracker**: AZ-2175
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (`_docs/loops/loop13/assessment13.md`, C17, C9, C29), owner scope A on 2026-10-05.

- C# pack evaluates a `when` on the values the caller supplied. Unpack evaluates it on the fields it has read. When a `when` names a field that an earlier `when` skipped, the two disagree.
- Typed row `U8 Profile(0), When(1, Eq(0, 0), U8 Shape(1)), When(2, Eq(1, 0), U8 Detail(2))` with `{Profile = 1, Shape = 0, Detail = 4}` packs `01 01 04`. The first `when` does not match (Profile is 1), so Shape is never written; the second `when` sees the supplied Shape = 0 and writes Detail. Unpack of those bytes returns `TrailingBytes(1)`.
- Inside a round, `Repeat(0, U8 K(0), When(1, Eq(0, 1), U8 A(1)), When(2, Eq(1, 5), U8 B(2)))` with K = [0], A = [5], B = [3] packs `01 00 03`, and `Read` accepts it as K = [0, 3] with A and B null: the packet is accepted with wrong data. Before loop 13 the same packet was unreadable (`ShortPacket`); the aligned-round change made the misparse silent.
- README: "The tested field must already have been read." Java evaluates `when` on what it read; Rust and TypeScript are not affected by this shape.
- Also from the assessment, no test pins these working behaviors: a failed `PackSession.Pack` leaves the counter alone (the code is right), and a split-form `FlagByte` with `Bit(...)` members inside a `repeat` round packs, reads back aligned and repacks.

## Outcome

- Pack decides every `when` from the fields it wrote in the same scope; a tested field that was skipped or absent does not match.
- The typed chain above packs `01 01` and unpacks; the round above packs `01 00` and reads K = [0].
- The two pins exist as tests.

## Scope

### Included
- The `when` decision on pack, at the top level and inside `repeat` / `times` rounds.
- Tests for AC-4 and AC-5 (no production change expected for those two).

### Excluded
- Which field kinds a `when` or a count may name (float, bytes, utf8, bool): decided with AZ-2126 (assessment C19, C18).
- Typed-row `Unpack` of `repeat` / `times` rows (AZ-2092).
- Nested `repeat` / `times` in a round (AZ-2176).

## Acceptance Criteria

**AC-1: A skipped field does not match on pack (typed row)**
Given `U8 Profile(0), When(1, Eq(0, 0), U8 Shape(1)), When(2, Eq(1, 0), U8 Detail(2))` over a row `{Profile = 1, Shape = 0, Detail = 4}`
When the row is packed
Then the bytes are `01 01`, and unpacking them returns Profile = 1 with no error.

**AC-2: A skipped field does not match inside a round**
Given `Repeat(0, U8 K(0), When(1, Eq(0, 1), U8 A(1)), When(2, Eq(1, 5), U8 B(2)))` with K = [0], A = [5], B = [3]
When it is packed and read
Then the bytes are `01 00`, and the read gives K = [0] with A and B null for that round.

**AC-3: Earlier written fields still decide**
Given `Repeat(0, U8 K(0), When(1, Eq(0, 1), U8 V(1)))` with K = [1, 2], V = [9]; the route fixture; the golden fixture
When they are packed
Then the bytes are `01 01 09 02`, the route hex `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` and `4001000065cd1d00a3e1110100`, unchanged; a `when` that names a field written earlier in the same round sees that round's value.

**AC-4: A failed pack does not advance the session**
Given an open `PackSession` pair and a scheme with a required value A
When `Pack` throws for a row without A, and `{A = 7}` is then packed and unpacked by the peer
Then the peer returns A = 7 with no error.

**AC-5: A split-form flag byte inside a round**
Given `FlagByte m; Repeat(0, m, m.Bit(U8 A), m.Bit(Bool On))` with A = [1, null, 3], On = [true, true, null]
When it is packed, read and repacked
Then the bytes are `01 03 01 02 01 03`, the read gives A = [1, null, 3] and On = [true, true, null], and the repack bytes are identical.

**AC-6: A count names only a field that was written** (added after the batch 4 review, F2)
Given `U8 P(0), When(1, Eq(0, 0), U8 N(1)), Sized(2, Data, count 1)` and a row P = 1, N = 2 with two data bytes
When it is packed
Then pack throws, naming the count field, instead of returning `01 01 09 09` that its own read rejects (`ShortPacket`); the count is read from what pack wrote, as Java does (`sized`, `bits`, `packed` and `times` counts alike); counts that name a field written earlier in the same scope are unchanged.

**AC-7: A `when` on a clear flag bit does not match** (added after the batch 4 review, F4)
Given `Eq(boolField, false)` over a bool whose bit is clear, and a row with that bool false and a value in the `when` body
When it is packed
Then the bytes are `01 00` (the body is not written) and unpack reads them, where the old code wrote `01 00 07` that unpack rejected.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every packet that was readable before are unchanged. Only packets that were unreadable or misparsed change.

**Reliability**
- Pack either returns bytes the peer can read as the same row, or throws (AZ-2088 NFR).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | typed chain, row above | `01 01`; unpack returns Profile = 1 |
| AC-2 | round chain K = [0], A = [5], B = [3] | `01 00`; read K = [0] |
| AC-3 | sibling `when` in a round, route and golden fixtures | bytes unchanged |
| AC-4 | session pair, failed pack then `{A = 7}` | peer reads A = 7 |
| AC-5 | split-form flag byte round | bytes `01 03 01 02 01 03`, aligned read, identical repack |
| AC-6 | `when` skips N, `Sized` counts N | pack throws naming the count; also `bits`, `packed`, `times` |
| AC-7 | `Eq(bool, false)` with a clear bit | `01 00`; unpack reads it |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `fixtures/golden.hex`, route hex in `BorrowedCountTests` | pack and unpack | identical bytes | Compatibility |

## Constraints

- ADR-001: C# keeps its own walker; mirror the rule Java uses (a `when` reads what was read), do not share code.
- `ArgumentException` stays the error type for the pack failures AZ-2088 introduced; a missing count keeps the `InvalidOperationException` (`count 'N' is missing`) that `RequireCount` already threw (AC-6 only decides when it fires).
- No public API change.

## Risks & Mitigation

**Risk 1: A scheme that packed a readable-by-luck packet now packs fewer bytes**
- *Risk*: a `when` chain whose middle field is skipped used to write the tail; the packet was unreadable or misparsed, so no correct consumer depended on it.
- *Mitigation*: README upgrade note in the loop 13 docs pass.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Which kinds a `when` / count may name (C# accepts any value field; Java and C++ integer or bool; Rust refuses non-integer) | AZ-2126 (decide integer or bool only everywhere; analysts recommend yes) | open | Medium |
