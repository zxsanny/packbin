# Rust map `times`: a per-name list for a member under `flags` or `when` is an error

**Task**: AZ-2189_rust_map_times_list_under_flags
**Name**: Rust map `times` refuses a per-name value it cannot align
**Description**: A map `times` packed without `__times_<anchor>` rounds returns `PackError::Type` naming a member when a value is kept under that member's name and the member sits under a `flags` or a `when`, instead of dropping the value.
**Complexity**: 1 point
**Dependencies**: AZ-2086_rust_typed_times_vec (map `times` rounds and per-name lists)
**Component**: rust
**Tracker**: AZ-2189
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (R26), owner scope A on 2026-10-05.

- A hand-built map for a `times` can give each member one list with one item per round (the per-name form). A list has no null, so it cannot say which round holds a member that is present in some rounds only, which is what a member under `flags` or `when` is.
- Pack takes the direct children of the `times` for each round and nothing below them. Probe: scheme `[u8 "0", times(1, "0", [flags(1, "f", [u8 "1"]), u8 "2"])]`, values `"0" = 2`, `"1" = [9]`, `"2" = [5, 6]`, no `__times_1`. It packs `01 02 00 05 00 06`: the 9 is dropped, no error. The same row with the rounds `[{"2": 5}, {"1": 9, "2": 6}]` packs `01 02 00 05 01 09 06`.
- The Rust `pack` documentation says a field under `flags` or `when` "is not aligned per round". The README does not describe the per-name form; the statement lives in the Rust `pack` API docs and the Rust component description.
- AZ-2086 AC-4 covers only rows that came from unpack, which carry the rounds. The C# pack throws for the same gap (AZ-2088).
- Reading the code, a member under a `when` whose condition matches already fails with `PackError::Missing`; the silent loss is the `flags` case.

## Outcome

- A value kept for a member that sits under a `flags` or a `when` of a `times`, with no rounds given, is a pack error that names the member and says to give the rounds under `__times_<anchor>`.
- Nothing else changes: rows with rounds, per-name lists for direct members, and rows with no such value pack as today.

## Scope

### Included
- The map-form `pack` of a `times` without `__times_<anchor>`.
- A per-name value (a list, or a single value, which counts as a list of one item) under the name of a member found at any depth below a `flags` or `when` of that `times`.
- The `pack` API documentation and the Rust component description.

### Excluded
- Typed schemes (their `Vec<E>` rows keep every round).
- Option C of the ticket (an aligned list value that holds nulls): API growth, not taken.
- Members of a `group` (they already fail with `PackError::Missing`) and split-form flag bits (their names are sliced per round; a gap in the middle of a list cannot be expressed, as before).
- Unpack, and the rounds form (`__times_<anchor>`).

## Acceptance Criteria

**AC-1: A member under `flags` with a per-name value is refused**
Given `[u8 "0", times(1, "0", [flags(1, "f", [u8 "1"]), u8 "2"])]` and values `"0" = 2`, `"1" = [9]`, `"2" = [5, 6]`, no `__times_1`
When it is packed
Then `PackError::Type` names `"1"`, and no bytes are returned (today `01 02 00 05 00 06`).

**AC-2: A member under `when` with a per-name value is refused**
Given a `times` whose body holds `u8 "2"` and a `when` on `"2"` equal to 1 over `u8 "3"`, values `"2" = [1, 2]`, `"3" = [7]`, no rounds
When it is packed
Then `PackError::Type` names `"3"` (today `PackError::Missing` when the `when` matches).

**AC-3: Rounds still pack**
Given the AC-1 scheme with the rounds `[{"2": 5}, {"1": 9, "2": 6}]` under `__times_1`, and a row read by unpack and packed again
When they are packed
Then both give `01 02 00 05 01 09 06`.

**AC-4: Direct members and absent members are unchanged**
Given `[u8 "0", times(1, "0", [i32 "1", i32 "2"])]` with lists `"1" = [10, 30]`, `"2" = [20, 40]`; and the AC-1 scheme with no value for `"1"` at all
When they are packed
Then the first gives `01 02 0a000000 14000000 1e000000 28000000` and the second gives `01 02 00 05 00 06`, with no error.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that packed without losing a value are unchanged.

**Reliability**
- Pack returns bytes that hold every value it was given, or an error; it never drops one.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | map `times` with a member under `flags`, per-name lists only | `PackError::Type` naming `"1"` |
| AC-2 | member under `when`, per-name lists only | `PackError::Type` naming `"3"` |
| AC-3 | rounds form and unpack then pack | `01 02 00 05 01 09 06` both |
| AC-4 | direct members; absent member under `flags` | bytes as above; no error |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `01020005010906` unpacked with the map API | repack | identical 7 bytes | Compatibility |

## Constraints

- ADR-001: Rust's own walker; C# AZ-2088 is the behavioural reference only.
- Pack errors are `PackError` values; construction failures stay panics.
- No wire change and no public API change; the documented per-name form narrows.
- Wire bytes in the ACs come from the ticket probes and AZ-2086 AC-4; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller edits the per-name lists of an unpacked row and drops `__times_<anchor>`**
- *Risk*: the documented way to change a value after unpack stops working for rows with a member under `flags` or `when`; before, it silently lost that member.
- *Mitigation*: the error names the member and the rounds key; the `pack` docs say to edit the rounds for such members.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| DECISION: A) refuse (recommended; these ACs); B) leave it, documented; C) add an aligned list value with nulls. A narrows the documented per-name list form, so the owner confirms the option before implementation | owner | open | Medium |
| Ticket text says the value vanishes under `flags` or `when`; reading the code, a matching `when` already fails with `PackError::Missing`, so the new rule changes the error there and adds one when no round matches. Confirm that a value kept for a member whose `when` matches no round also errors | owner | open | Low |
| A single (non-list) value kept for such a member is treated like a list of one item, as the rounds check does; the ticket text names lists only | implementer | open | Low |

## Owner decision (2026-10-06)

DECIDED, the proposed default: option A: refuse a map `times` list under `flags`. The open DECISION rows above are resolved by this section.

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 1), option A. An empty per-name list holds no value and still packs (review finding F1); a non-empty list or a single value under a member below `flags` or `when`, with no `__times_<anchor>`, is refused. Known limit: the check works on the flat name map, so an outer field that shares its name with such a member is refused as if it were the member's.
