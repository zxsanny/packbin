# TypeScript times refuses a list longer than its count

**Task**: AZ-2185_typescript_times_list_longer
**Name**: TypeScript `times` list longer than the count is an error
**Description**: Pack throws `RangeError` naming the member when a list held by a `times` body has more entries than the `times` count, instead of dropping the extra entries.
**Complexity**: 1 point
**Dependencies**: AZ-2091_typescript_nested_flags_names (round slicing on pack)
**Component**: typescript
**Tracker**: AZ-2185
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X5, T24), owner scope A on 2026-10-05; batch 3 discovered 2.

- A `times` writes its inner fields exactly N times. README: "The inner fields, exactly N times". AZ-2088 AC-3 (C#): "`times` lists must have exactly `count` items". TypeScript, Python and Java pack a longer list without a word and drop the extra entries; C# throws, and Rust and C++ refuse.
- Probe (verified on the current code): `u8(0, a)`, `times(1, 0, u8(1, x))`. `{a:2, x:[1,2,3]}` packs `01 02 01 02`: the third item is silently dropped. `{a:0, x:[1]}` packs `01 00`. The same happens for a member under `when` inside the body (`k:[1], v:[7,8]` with count 1 packs `01 01 01 07`).
- A list shorter than the count already throws `RangeError` `missing x`.
- Python and Java get their own tickets (AZ-2186, AZ-2187).

## Outcome

- Pack throws `RangeError` naming the member when any list a `times` body holds has more entries than the count, and returns no bytes.
- Valid rows, the shorter-list error and every wire byte are unchanged.

## Scope

### Included
- Every member the `times` body can hold (its own fields and the ones under `when`, `flags`, flag bits and groups), as C# checks them.
- Tests for the probes below.

### Excluded
- `repeat`: its round count is the longest list, so no list is too long.
- Lists inside a list or dict element, and a `repeat` or `times` nested in a round (AZ-2177 refuses it at construction).
- The shorter-list error (`missing x`) and unpack.

## Acceptance Criteria

**AC-1: A longer list is refused**
Given `u8(0, a)`, `times(1, 0, u8(1, x))`
When `{a:2, x:[1,2,3]}` is packed
Then pack throws `RangeError` whose message names `x`, the 3 items and the count 2.

**AC-2: Count zero**
Given the scheme of AC-1
When `{a:0, x:[1]}` is packed, and then `{a:0, x:[]}` and `{a:0}`
Then the first throws `RangeError` naming `x`; the other two pack `01 00`.

**AC-3: Any member of the body**
Given `times(1, 0, u8(1, x), u8(2, y))` after `u8(0, a)`, and `times(1, 0, u8(1, k), when(2, eq(1, 1), [u8(2, v)]))` after `u8(0, a)`
When `{a:2, x:[1,2], y:[3,4,5]}` and `{a:1, k:[1], v:[7,8]}` are packed
Then the first throws `RangeError` naming `y`, the second naming `v`.

**AC-4: Valid rows and the shorter list are unchanged**
Given the schemes above
When `{a:2, x:[1,2]}`, `{a:2, x:[1]}`, `{a:2, x:5}`, `{a:1, x:5}`, `{a:2, x:[1,2], y:[3,4]}` and `{a:2, k:[1,0], v:[7]}` are packed
Then the bytes are `01 02 01 02`, `RangeError` `missing x`, `01 02 05 05`, `01 01 05`, `01 02 01 03 02 04` and `01 02 01 07 00`.

**AC-5: Unpacked rows still pack**
Given `01 02 01 02` unpacked with the scheme of AC-1
When the row is packed again
Then the bytes are `01 02 01 02`.

**AC-6: Fixtures unchanged**
Given the route fixture (a `times` with a borrowed count) and the language-pair handoffs
When they are packed
Then the bytes are unchanged (route `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`).

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that packed with no dropped entry are unchanged.

**Reliability**
- Pack either writes every entry the caller supplied or throws (AZ-2088 NFR).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `x:[1,2,3]`, count 2 | `RangeError` names `x` (packs `01 02 01 02` today) |
| AC-2 | `{a:0, x:[1]}`; `{a:0, x:[]}`; `{a:0}` | throws; `01 00`; `01 00` |
| AC-3 | `y` longer; `v` under `when` longer | `RangeError` names `y`; names `v` |
| AC-4 | exact, shorter, lone scalar, two members, `when` | bytes as listed; `missing x` for the shorter list |
| AC-5 | unpack `01 02 01 02`, repack | identical bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | route fixture in the borrowed-count tests, `fixtures/golden.hex` | pack | unchanged hex | project AC-1/3 |
| AC-6 | `language-pair.sh` rings | TypeScript producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: TypeScript only; mirror the C# rule (any list longer than the count is an error), do not share code.
- `RangeError` is the pack error type; browser-safe `src`; no public API change.
- Wire bytes in the ACs come from probes of the current code; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller passed an over-long list on purpose**
- *Risk*: a row that packed with its tail dropped now throws.
- *Mitigation*: the dropped entries were data the packet never carried; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket names only a `times` list; AC-3 extends it to every member the body holds, as C# does. The owner may narrow it to the body's direct fields | owner | open | Low |
