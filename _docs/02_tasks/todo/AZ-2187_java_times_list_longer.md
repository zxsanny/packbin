# Java `times` refuses a list longer than its count

**Task**: AZ-2187_java_times_list_longer
**Name**: Java `times` list longer than count is refused
**Description**: Java pack throws `IllegalArgumentException` naming the member when a `times` body member holds more list entries than the `times` count, instead of silently dropping the extra entries.
**Complexity**: 1 point
**Dependencies**: AZ-2089_java_forward_refs_bool (Java per-round values for `repeat` / `times`)
**Component**: java
**Tracker**: AZ-2187
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X5, T24), owner scope A on 2026-10-05: not fixed in loop 13, filed as a follow-up.

- Java packs a `times` round by round, taking entry `i` of each body member's list for round `i`. It stops after `count` rounds, so every entry past the count is dropped with no error.
- Probe: `u8 a; times(1, 0, u8 x)` with `{a: 2, x: [1, 2, 3]}` packs `01 02 01 02`. The third item is lost and the caller is not told.
- README: "The inner fields, exactly N times." AZ-2088 AC-3 (C#): "times lists must have exactly count items". C# throws, Rust and C++ refuse; TypeScript (AZ-2185) and Python (AZ-2186) have the same gap and are filed separately.
- A list shorter than the count already fails (an `IllegalArgumentException`; the round gets a null for a required value). That stays as it is.
- `repeat` has no count: its round count is the longest list, so it has no "too long" case.

## Outcome

- A `times` body member whose list has more entries than the count makes pack throw `IllegalArgumentException`, naming the member and giving the list length and the count. No bytes are returned.
- Every other row packs exactly as before.

## Scope

### Included
- Members directly in a `times` body and members under `flags`, `when` and anchored groups in that body.
- Clear pack and session pack (session pack calls clear pack).

### Excluded
- `repeat` (no count), `list` and `dict` elements.
- A list shorter than the count: its error is unchanged.
- A lone scalar for a member: it is still used for every round and has no length.
- TypeScript (AZ-2185), Python (AZ-2186); C#, Rust and C++ already refuse.

## Acceptance Criteria

**AC-1: A longer list is refused**
Given `u8 a; times(1, 0, u8 x)` and the row `{a: 2, x: [1, 2, 3]}`
When the row is packed
Then pack throws `IllegalArgumentException` naming `x` and saying the list has 3 entries for a count of 2, and no bytes are returned.

**AC-2: An exact list still packs**
Given the same scheme and `{a: 2, x: [1, 2]}`
When the row is packed
Then the bytes are `01 02 01 02`, and unpacking them returns `x = [1, 2]`.

**AC-3: A member under `flags` is checked too**
Given `u8 a; times(1, 0, flags(1, u8 x))` with `a = 2`
When it is packed with `x = [1, 2, 3]`, and then with `x = [1, null]`
Then the first throws `IllegalArgumentException` naming `x`; the second packs `01 02 01 01 00` (round 1 sets the bit, round 2 clears it).

**AC-4: Extra entries are refused whatever they hold**
Given `u8 a; times(1, 0, u8 x)` with `a = 2`
When it is packed with `x = [1, 2, null]`
Then it throws as in AC-1, because the list has 3 entries.

**AC-5: Shorter lists and scalars keep their behavior**
Given `u8 a; times(1, 0, u8 x)` with `a = 2`
When it is packed with `x = [1]`, and with a lone `x = 5`
Then the first throws the same `IllegalArgumentException` as before this task; the second packs `01 02 05 05`.

**AC-6: Valid rows and fixtures are unchanged**
Given the route fixture, the golden fixture and every `times` row in the Java tests and the handoff driver
When they are packed
Then the bytes are identical to before.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every row that packed without error before and had no extra entries are unchanged.
- Packets that dropped entries before now throw; no correct consumer could have recovered the dropped entries.

**Reliability**
- Pack either returns bytes the peer reads as the same row, or throws (AZ-2088 NFR).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `{a: 2, x: [1, 2, 3]}` | `IllegalArgumentException` naming `x`; today `01 02 01 02` |
| AC-2 | `{a: 2, x: [1, 2]}` | `01 02 01 02`; unpack returns `x = [1, 2]` |
| AC-3 | `times` over `flags(u8 x)`, `[1, 2, 3]` and `[1, null]` | throws; `01 02 01 01 00` |
| AC-4 | `x = [1, 2, null]` | throws |
| AC-5 | `x = [1]` and `x = 5` | same error as before; `01 02 05 05` |
| AC-6 | session pack of a 3-entry list; existing suite and fixtures | session pack throws too; bytes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | `fixtures/golden.hex`, route hex, `language-pair.sh` rings | Java producer and consumer | 0 mismatched bytes | Compatibility |

## Constraints

- `IllegalArgumentException` stays the pack error type; the message names the member the way Java's other pack errors do (by its field id; today's messages are "missing field 1" and "1: expected int, got null").
- Wire bytes in the ACs come from the assessment probe and the wire rules; the worker re-derives each one from a real run before pinning it.
- Java keeps its own walker (ADR-001); mirror C# (RequireNoExtraRounds), do not share code.

## Risks & Mitigation

**Risk 1: A caller reuses one list across schemes with different counts**
- *Risk*: such a row packed silently before and now throws.
- *Mitigation*: the message states the list length and the count; README upgrade note in the next docs pass.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The assessment text says a shorter list gives `missing x`; Java's shorter-list error is the null-for-a-required-value `IllegalArgumentException` and names the field id | spec corrected; worker keeps the current error unchanged | resolved | Low |
| The same refusal for TypeScript and Python is filed as AZ-2185 and AZ-2186; hostile pack vectors for it wait on AZ-2194 | follow-ups | accepted-risk | Low |
