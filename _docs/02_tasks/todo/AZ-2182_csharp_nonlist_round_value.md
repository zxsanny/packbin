# C# a non-list value for a name in a round: broadcast, and a loud error for a lone collection

**Task**: AZ-2182_csharp_nonlist_round_value
**Name**: C# lone value in a round
**Description**: In a `repeat` / `times` round a lone scalar goes to every round, as in TypeScript, Python and Java, and a lone `byte[]` or collection for a `Bytes`, `Sized`, `Bits` or `Packed` name fails with an `ArgumentException` that names the field.
**Complexity**: 2 points
**Dependencies**: AZ-2087_csharp_forward_refs (round slicing), AZ-2088_csharp_pack_fails_loudly (loud pack); related AZ-2134_aligned_round_values, AZ-2179_rounds_ring
**Component**: csharp
**Tracker**: AZ-2182
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (C14, C15, T23, X7), owner scope A on 2026-10-05, cross-package parity.

- In a round C# reads any `IList` value as the list of rounds. A lone `byte[]` for a `Bytes` or `Sized` name, or a lone `List<int>` for a `Bits` or `Packed` name, is therefore read as a list of rounds whose items are bytes or ints. Pack throws a raw `InvalidCastException`, or under `times` a misleading `ArgumentException` ("holds N items, but the times count is M").
- A lone scalar goes to round 0 only. Probe: `Repeat(0, U8 A(0), U8 B(1))` with scalar A = 5 and B = [4, 6] throws `'A' (field id 0) has no value` for round 1. A lone scalar with one round packs `01 05`.
- TypeScript, Python and Java send a lone scalar to every round (TypeScript pins it with a test): scalar x = 1 with y = [4, 5] packs `01 01 04 01 05`.
- Rust's map `times` also puts a lone scalar in round 0 only (ticket text says only C# differs; see Flagged concerns).

## Outcome

- A lone scalar is used in every round, so C# packs `01 01 04 01 05` for the TypeScript probe.
- A lone collection for a name that holds per-round collections is refused with an error that says to wrap one round in a list.
- Rows that are lists with one entry per round, and rounds with only scalars (one round), pack exactly as today.

## Scope

### Included
- Pack of `repeat` and `times` rounds, for rows given as dictionaries and as typed rows.
- The value a `Bytes`, `Sized`, `Bits` and `Packed` name takes in a round: one `byte[]` or one list per round, inside a list of rounds.

### Excluded
- Unpack (already one list entry per round).
- Rust map `times` and other packages (see Flagged concerns).
- Nested rounds (AZ-2176).

## Acceptance Criteria

**AC-1: A lone scalar goes to every round (repeat)**
Given `Repeat(0, U8 X(0), U8 Y(1))` with scalar X = 1 and Y = [4, 5]
When it is packed
Then the bytes are `01 01 04 01 05`.

**AC-2: A lone scalar goes to every round (times)**
Given `U8 N(0), Times(1, 0, U8 X(1), U8 Y(2))` with N = 2, scalar X = 1 and Y = [4, 5]
When it is packed
Then the bytes are `01 02 01 04 01 05`.

**AC-3: One round of scalars is unchanged**
Given `Repeat(0, U8 A(0))` with scalar A = 5
When it is packed
Then the bytes are `01 05`.

**AC-4: A lone collection is refused**
Given a lone `byte[]` for a `Bytes` name, a lone `byte[]` for a `Sized` name, and a lone `List<int>` for a `Bits` or `Packed` name, each inside a `repeat` and inside a `times`
When the row is packed
Then `ArgumentException` names the field and says a round's value belongs in a list with one entry per round. No `InvalidCastException`, no count message.

**AC-5: Lists of rounds still work**
Given `Repeat(0, Bytes(2) D(0))` with D = [`0102`, `0304`], and a per-round list for a `Sized`, a `Bits` and a `Packed` name whose count is a field of the same round
When packed, read and repacked
Then the bytes for the `Bytes` row are `01 0102 0304`; each row reads back the same entries, and its repack bytes are identical.

**AC-6: Lists of unequal length are still refused**
Given a `repeat` whose lists hold 2 and 1 entries
When it is packed
Then `ArgumentException` as before (AZ-2088 AC-3).

**AC-7: Fixtures unchanged**
Given the golden row and the route fixture
When they are packed
Then the bytes are `4001000065cd1d00a3e1110100` and `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that packed before are unchanged. Only rows that threw, or packed a lone scalar in round 0 only, change.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | scalar X with list Y in `repeat` and `times` | `01 01 04 01 05`, `01 02 01 04 01 05` (today `'X' has no value`) |
| AC-3 | one round of scalars | `01 05` |
| AC-4 | lone `byte[]` / `List<int>` per kind, in `repeat` and `times` | `ArgumentException` naming the field |
| AC-5 | per-round lists of each of the four kinds | exact bytes; aligned read; identical repack |
| AC-6 | lists of 2 and 1 entries | `ArgumentException` |
| AC-7 | golden and route fixtures | bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | TypeScript probe row (x = 1, y = [4, 5]) | C# pack, then the TypeScript consumer unpacks | same bytes `01 01 04 01 05` | Compatibility |
| AC-7 | `fixtures/golden.hex`, `language-pair.sh` rings | C# producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: C# keeps its own round slicing; mirror the rule TypeScript, Python and Java use, no shared code.
- `ArgumentException` stays the pack error type; no public API change.
- Wire bytes in the ACs come from the ticket probes (AC-2 and AC-5 are derived from the same shapes); the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller passed a `byte[]` meant as one round's value**
- *Risk*: that row threw before, so nobody depends on it.
- *Mitigation*: the message names the field and says to wrap the value in a list; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| DECISION (cross-package parity): A) broadcast a lone scalar everywhere and refuse a lone collection (recommended; these ACs); B) refuse a lone value when there is more than one round; C) round 0 only. The owner confirms the option before implementation | owner | open | Medium |
| Ticket text says only C# differs from the others. Reading the code, Rust's map `times` also gives a lone scalar to round 0 only, so option A needs a Rust follow-up that has no ticket yet | coordinator | open | Medium |
| `List` and `Dict` names in a round have the same lone-versus-per-round shape; the ticket names only `Bytes`, `Sized`, `Bits`, `Packed`. Confirm whether the loud error covers them | owner | open | Low |
