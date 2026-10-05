# Python times refuses a list longer than its count

**Task**: AZ-2186_python_times_list_longer
**Name**: Python `times` list longer than the count is an error
**Description**: Pack raises `ValueError` naming the member when a list held by a `times` body has more entries than the `times` count, instead of dropping the extra entries.
**Complexity**: 1 point
**Dependencies**: AZ-2083_python_bool_flag_limit (same pack module; land in order)
**Component**: python
**Tracker**: AZ-2186
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X5, T24), owner scope A on 2026-10-05.

- A `times` writes its inner fields exactly N times. README: "The inner fields, exactly N times". AZ-2088 AC-3 (C#): "`times` lists must have exactly `count` items". Python packs a longer list without a word and drops the extra entries. C# throws; Rust and C++ refuse. TypeScript and Java have their own tickets (AZ-2185, AZ-2187).
- Probe (verified on the current code): `u8(0, a)`, `times(1, 0, u8(1, x))`. `{"a": 2, "x": [1, 2, 3]}` packs `01 02 01 02`: the third item is dropped. `{"a": 0, "x": [1]}` packs `01 00`.
- The same happens for a second list member (`y: [3, 4, 5]` packs `01 02 01 03 02 04`), for a member under `when` in the body (`k: [1]`, `v: [7, 8]` with count 1 packs `01 01 01 07`) and for a member under `flags` in the body (`f: [1, 2, 3]`, count 2, packs `01 02 01 01 01 02`).
- A list shorter than the count already fails, but with a raw `IndexError` (`list index out of range`) that names nothing. The ticket text said it fails with `missing x`; that is the TypeScript message, not Python's.

## Outcome

- Pack raises `ValueError` naming the member (Python labels members by field id, as in `0: 300 does not fit in u8`), the number of items and the count, when any list a `times` body holds is longer than the count. No bytes are returned.
- Valid rows, the shorter-list failure and every wire byte are unchanged.

## Scope

### Included
- Every member the `times` body writes in a round: its own fields and the ones under `when`, `flags`, flag bits and groups.
- Tests for the probes below.

### Excluded
- `repeat` (its lists must already have equal lengths; unchanged).
- The shorter-list failure and its raw `IndexError` label (C15 error labels), unpack.
- Lists inside a list or dict element.

## Acceptance Criteria

**AC-1: A longer list is refused**
Given `u8(0, a)`, `times(1, 0, u8(1, x))`
When `{"a": 2, "x": [1, 2, 3]}` is packed
Then pack raises `ValueError` naming field 1, the 3 items and the count 2.

**AC-2: Count zero**
Given the scheme of AC-1
When `{"a": 0, "x": [1]}` is packed, and then `{"a": 0, "x": []}` and `{"a": 0}`
Then the first raises `ValueError` naming field 1; the other two pack `01 00`.

**AC-3: Any member of the body**
Given `times(1, 0, u8(1, x), u8(2, y))`, `times(1, 0, u8(1, k), when(2, eq(1, 1), u8(2, v)))` and `times(1, 0, flags(1, u8(1, f)))`, each after `u8(0, a)`
When `{"a": 2, "x": [1, 2], "y": [3, 4, 5]}`, `{"a": 1, "k": [1], "v": [7, 8]}` and `{"a": 2, "f": [1, 2, 3]}` are packed
Then each raises `ValueError` naming field 2, field 2 and field 1 in turn.

**AC-4: Valid rows are unchanged**
Given the schemes above
When `{"a": 2, "x": [1, 2]}`, `{"a": 2, "x": 5}`, `{"a": 2, "x": [1, 2], "y": [3, 4]}`, `{"a": 2, "k": [1, 0], "v": [7]}` and `{"a": 2, "f": [1, 2]}` are packed
Then the bytes are `01 02 01 02`, `01 02 05 05`, `01 02 01 03 02 04`, `01 02 01 07 00` and `01 02 01 01 01 02`.

**AC-5: A shorter list keeps its failure**
Given the scheme of AC-1
When `{"a": 2, "x": [1]}` is packed
Then it fails exactly as it does today (an `IndexError`).

**AC-6: Unpacked rows still pack; fixtures unchanged**
Given `01 02 01 02` unpacked, and the route fixture
When the unpacked row and the route row are packed
Then the bytes are `01 02 01 02` and `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that packed with no dropped entry are unchanged.

**Reliability**
- Pack either writes every entry the caller supplied or raises.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `x: [1, 2, 3]`, count 2 | `ValueError` names field 1 (packs `01 02 01 02` today) |
| AC-2 | `a: 0` with `[1]`, `[]`, absent | raises; `01 00`; `01 00` |
| AC-3 | `y`, `v` under `when`, `f` under `flags`, each too long | `ValueError` names field 2, 2, 1 |
| AC-4 | exact lists, lone scalar, two members, `when`, `flags` | bytes as listed |
| AC-5 | `x: [1]`, count 2 | unchanged `IndexError` |
| AC-6 | unpack `01 02 01 02`, repack; route row | identical bytes |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | route fixture in the borrowed-count tests, `fixtures/golden.hex` | pack | unchanged hex | project AC-1/3 |
| AC-6 | `language-pair.sh` rings | Python producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Python only; mirror the C# rule, do not share code.
- `ValueError` is the error type for a bad row length, as for `repeat` and `packed`.
- No public API change.
- Wire bytes in the ACs come from probes of the current code; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller passed an over-long list on purpose**
- *Risk*: a row that packed with its tail dropped now raises.
- *Mitigation*: the dropped entries were data the packet never carried; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ticket names only a `times` list; AC-3 extends it to every member the body writes, as C# does. The owner may narrow it to the body's direct fields | owner | open | Low |
| A shorter list raises a raw `IndexError` with no member named; fixing it belongs with the error labels (C15) | C15 | open | Low |
