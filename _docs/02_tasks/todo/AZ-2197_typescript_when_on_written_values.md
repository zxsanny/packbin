# TypeScript pack evaluates `when` on the values it wrote

**Task**: AZ-2197_typescript_when_on_written_values
**Name**: TypeScript `when` reads what pack wrote
**Description**: A `when` whose tested field was not written reads as not matching on pack, the same rule unpack applies, so pack never returns bytes its own read rejects or misparses; the TypeScript twin of AZ-2175.
**Complexity**: 3 points
**Dependencies**: AZ-2091_typescript_nested_flags_names (aligned round values), AZ-2177_typescript_nested_round_refused
**Component**: typescript
**Tracker**: AZ-2197
**Epic**: AZ-2069

## Problem

Found by the loop 13 README writer after AZ-2175 fixed C#; not a row of the loop 13 assessment.

- TypeScript pack tests a `when` against the row the caller supplies. Unpack tests it against the fields it has read. When a `when` names a field that an earlier `when` skipped, the two disagree.
- `u8 p(0); when(1, eq(0, 0), [u8 n(1)]); when(2, eq(1, 0), [u8 v(2)])` with `{p: 1, n: 0, v: 4}` packs `01 01 04`. The first `when` does not match, so `n` is never written; the second `when` sees the supplied `n = 0` and writes `v`. Unpack of those bytes returns `{ok: false}` (`TrailingBytes`).
- Inside a `repeat` or `times` round the same shape can pack a packet that reads back with wrong data (the C# case K = [0], A = [5], B = [3] in AZ-2175 AC-2).
- README (loop 13 upgrade notes) documents it as a limitation: "TypeScript pack still tests the row you give it ... Do not test a field that something else can skip." That line is removed when this task lands.
- The same two disagreements exist for a count (`sized`, `bits`, `packed`, `times`) that names a field a `when` skipped, and for `eq(bool, false)` on a clear flag bit.

## Outcome

- Pack decides every `when` from the fields it wrote in the same scope; a tested field that was skipped or absent does not match.
- The chain above packs `01 01` and unpacks.
- A count that names a field pack did not write throws, naming the count field.
- Wire bytes of every packet that was readable before are unchanged.

## Scope

### Included
- The `when` decision on pack, at the top level and inside `repeat` / `times` rounds.
- The count check (a count names only a field that was written).
- `eq(bool, false)` on a clear flag bit does not match.
- Removing the limitation sentence from the README and `02_typescript_package/description.md`.

### Excluded
- Which field kinds a `when` or a count may name (float, bytes, utf8, bool): AZ-2126.
- Rust map-form `eq(bool, false)` still writing the body: AZ-2126.
- Other packages (Java and Rust are not affected by this shape; C# is AZ-2175).

## Acceptance Criteria

**AC-1: A skipped field does not match on pack (top level)**
Given `u8 p(0); when(1, eq(0, 0), [u8 n(1)]); when(2, eq(1, 0), [u8 v(2)])` over `{p: 1, n: 0, v: 4}`
When the row is packed
Then the bytes are `01 01`, and unpacking them returns `p = 1` with `ok: true`.

**AC-2: A skipped field does not match inside a round**
Given `repeat(0, u8 k(0), when(1, eq(0, 1), [u8 a(1)]), when(2, eq(1, 5), [u8 b(2)]))` with `k = [0]`, `a = [5]`, `b = [3]`
When it is packed and read
Then the bytes are `01 00`, and the read gives `k = [0]` with `a` and `b` `undefined` for that round.

**AC-3: Earlier written fields still decide**
Given `repeat(0, u8 k(0), when(1, eq(0, 1), [u8 v(1)]))` with `k = [1, 2]`, `v = [9]`; the route fixture; the golden fixture
When they are packed
Then the bytes are `01 01 09 02`, the route hex `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` and `4001000065cd1d00a3e1110100`, unchanged.

**AC-4: A count names only a field that was written**
Given `u8 p(0); when(1, eq(0, 0), [u8 n(1)]); sized(2, data, count 1)` and a row `p = 1`, `n = 2` with two data bytes
When it is packed
Then pack throws, naming the count field, instead of returning bytes its own read rejects; the same for `bits`, `packed` and `times` counts; counts that name a field written earlier in the same scope are unchanged.

**AC-5: A `when` on a clear flag bit does not match**
Given `eq(boolField, false)` over a bool whose bit is clear, and a row with that bool false and a value in the `when` body
When it is packed
Then the body is not written and unpack reads the packet.

**AC-6: The cross-language rings stay green**
Given `language-pair.sh` (user, nested, boolflag, booltrue, bitwhen, session, position, roundflags, roundwhen)
When it runs
Then every ring passes with the TypeScript driver in both directions.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every packet that was readable before are unchanged. Only packets that were unreadable or misparsed change.

**Reliability**
- Pack either returns bytes the peer can read as the same row, or throws (AZ-2088 NFR for C#).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | chain above, `{p: 1, n: 0, v: 4}` | `01 01`; unpack returns `p = 1` |
| AC-2 | round chain K = [0], A = [5], B = [3] | `01 00`; read K = [0] |
| AC-3 | sibling `when` in a round, route and golden fixtures | bytes unchanged |
| AC-4 | `when` skips `n`, `sized` counts `n` | pack throws naming the count; also `bits`, `packed`, `times` |
| AC-5 | `eq(bool, false)` with a clear bit | body not written; unpack reads it |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `fixtures/golden.hex`, route hex | pack and unpack | identical bytes | Compatibility |
| AC-6 | `.github/workflows/language-pair.sh` | all rings | pass | Compatibility |

## Constraints

- ADR-001: TypeScript keeps its own walker; mirror the rule C# and Java use (a `when` reads what was read), do not share code.
- No public API change.

## Risks & Mitigation

**Risk 1: A scheme that packed a readable-by-luck packet now packs fewer bytes**
- *Risk*: a `when` chain whose middle field is skipped used to write the tail; the packet was unreadable or misparsed, so no correct consumer depended on it.
- *Mitigation*: README upgrade note when this lands; the limitation sentence is replaced by the C# note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Which kinds a `when` / count may name (TypeScript accepts any value field) | AZ-2126 (decide integer or bool only everywhere) | open | Medium |
