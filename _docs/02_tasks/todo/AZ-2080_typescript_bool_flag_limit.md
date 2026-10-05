# TypeScript bool rule and 8-bit flag limit

**Task**: AZ-2080_typescript_bool_flag_limit
**Name**: TypeScript bool presence and flag-bit limit
**Description**: A `bool` (or empty group) sets its flags bit only for `true`, is accepted only inside `flags` / a flag byte, and a ninth flag bit fails at construction.
**Complexity**: 2 points
**Dependencies**: AZ-2072_typescript_hostile_unpack (same walker code)
**Component**: typescript
**Tracker**: AZ-2080
**Epic**: AZ-2069

## Problem

**1. `false` sets the bit.** Flag presence is `present(value)`, which is `!== undefined && !== null` (`kinds.ts:9-11`), used by `bitOn` (`fields.ts:277-282`) and `groupOn` (`kinds.ts:13-23`, which counts `bool` members via `scalarChildNames`, `kinds.ts:25-44`). Unpack sets `true` whenever it meets a `bool` (`walker.ts:257-260`) and sets an empty group's member to `true` whenever its bit is set (`walker.ts:273`, `322`). Reproduced on `d108141`:

| Scheme (type 1) | Row | Pack today | Unpack today | Python today |
|-----------------|-----|-----------|--------------|--------------|
| `flags(0, [bool(0, x=>x.on)])` | `{on:false}` | `0101` | `{on:true}` | `0100`, `on` absent |
| `flagByte("m")`, `m.bit(bool(0, x=>x.on))` | `{on:false}` | `0101` | `{m:1, on:true}` | split form unusable (task 31) |
| `u8(0, x=>x.a)`, `bool(1, x=>x.on)` (bool outside flags) | `{a:1, on:false}` | `0101` | `{a:1, on:true}` | `on` never set |
| `flags(0, [group(x=>x.g, [u8(0,n), bool(1,on)])])` | `{g:{n:1, on:false}}` | `010101` | `{n:1, on:true}` | — |
| `u8(0,n)`, `group(x=>x.mark, [])` (empty group outside flags) | `{n:1}` | `0101` | `{n:1, mark:true}` | — |

The same row gives different bytes in TS and Python, which breaks project AC-3. C# has the same rule as TS today (task 10).

**2. No 8-bit limit.** `flags(anchor, fields)` (`fields.ts:125-127`) and `flagByte(...).bit` (`fields.ts:129-142`, unbounded `next++`) accept a ninth bit. With nine `u8` children and row `{f8: 7}`, pack writes `010007`: the flag byte is masked to `v & 0xff` (`walker.ts:99`), but the 9th field is still written because `flagBits` holds the unmasked value (`walker.ts:103-104`). Its own unpack then fails with a trailing error `{ok:false, field:"", needed:0, left:1}`. Python fails only at pack (task 14). C++ and Java reject at construction.

## User decision (2026-10-05), applied verbatim

> The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error.

## Outcome

- `{on:false}` and `{}` both pack to `0100`, and unpack gives `on` absent. `{on:true}` packs `0101` and unpacks `on: true`.
- A `bool` or an empty group anywhere except as the direct field of a flag bit makes `scheme(...)` throw `RangeError` naming the member.
- A ninth bit on `flags` or on a flag-byte handle throws `RangeError` at declaration or `scheme(...)` time.
- Golden hex and route fixture (`3410…01`, which uses `bool(3, straight)` inside `flags` with `true`) are unchanged.

## Scope

### Included
- Presence rule for `bool` and empty-group marks in pack (flag value) and unpack (member set to `true` only when the bit is set).
- Construction errors: `bool` / empty group outside a flag bit. That covers top level, inside a non-empty group, `when`, `repeat`, `times`, and list/dict elements.
- Ninth flag bit: short form and split form.

### Excluded
- Non-empty groups under flags. Their presence stays "any member present" (`0` is present).
- Other packages (tasks 10, 12–14, 20).
- Error label changes (C15).

## Acceptance Criteria

**AC-1: false leaves the bit clear**
Given `flags(0, [bool(0, x=>x.on)])`
When `{on:false}`, `{}` and `{on:true}` are packed
Then the bytes are `0100`, `0100` and `0101`

**AC-2: unpack sets true only for a set bit**
Given the same scheme
When `0100` and `0101` are unpacked
Then the first row has no `on` member and the second has `on === true`

**AC-3: split form follows the same rule**
Given `m = flagByte("m")`, `scheme(1, m, m.bit(bool(0, x=>x.on)))`
When `{on:false}` is packed
Then the bytes are `0100`; `0101` unpacks with `on === true`

**AC-4: empty-group mark follows the same rule**
Given `flags(0, [group(x=>x.mark, [])])`
When `{mark:true}`, `{mark:false}` and `{}` are packed
Then the bytes are `0101`, `0100` and `0100` (the existing "flag empty group mark" test stays green)

**AC-5: bool outside flags fails construction**
Given a `bool` at top level, inside a non-empty `group`, inside `when`, `repeat` or `times`, or as a `list`/`dict` element
When `scheme(...)` is called
Then it throws `RangeError` whose message names the bool's member

**AC-6: empty group outside flags fails construction**
Given `u8(0, n)`, `group(x=>x.mark, [])`
When `scheme(...)` is called
Then it throws `RangeError` naming `mark`

**AC-7: ninth flag bit fails construction**
Given `flags(0, [9 u8 fields])`, or a flag-byte handle given a ninth `.bit(...)`
When the scheme is declared
Then a `RangeError` is thrown before any byte is written; eight bits still work

**AC-8: fixtures unchanged**
Given the golden position row and the route fixture
When packed and unpacked
Then the bytes are `4001000065cd1d00a3e1110100` and `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`

## Non-Functional Requirements

**Compatibility**
- Wire bytes change only for rows with a `false` bool / empty-group mark (the decided fix). Every other row keeps its bytes.

**Performance**
- The AC-10 loop stays ≤ 1 s.

## Unit Tests

Write first; each must fail on `d108141`.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `bool false leaves the flag bit clear` | `{on:false}` | `0100` |
| AC-2 | `bool unpacks true only when set` | `0100`, `0101` | absent / `true` |
| AC-3 | `split form bool false` | `{on:false}` | `0100` |
| AC-4 | `empty group mark false` | `{mark:false}` | `0100` |
| AC-5 | `bool outside flags is a scheme error` | top level; in `group`; in `when`; `list` element | `RangeError` ×4 |
| AC-6 | `empty group outside flags is a scheme error` | `group(x=>x.mark, [])` at top level | `RangeError` |
| AC-7 | `ninth flag bit is a scheme error` | 9 children, short and split | `RangeError` ×2 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | cross-language bool vector (C01, added to the shared vectors) | TS packs `{on:false}` | `0100`, same as Python | project AC-3 |
| AC-8 | `fixtures/golden.hex`, route fixture, language-pair handoffs | pack/unpack | unchanged bytes | project AC-1/3 |
| — | `fixtures/hostile/` (task 01) | still all errors | unchanged by this task | Reliability |

## Constraints

- ADR-001: TS-only change. The rule is the same in all six packages because the user decided one rule, not because code is shared.
- Browser-safe `src`.
- Construction errors are `RangeError`, like the existing order errors.

## Risks & Mitigation

**Risk 1: Callers send `false` and rely on reading `true`**
- *Risk*: A caller that stored `false` used to read `true`. After the fix the member is absent on the receiver.
- *Mitigation*: That read was wrong. Call out the change in the release notes for v0.2.0.

**Risk 2: Schemes with a bool outside flags stop constructing**
- *Mitigation*: Such a bool never carried information (it always unpacked `true`). The error message says to move it into `flags`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| "Only inside flags" is read as "the direct field of a flag bit"; a bool inside a group under flags is rejected because its own value has no bit | user decision 2026-10-05 (interpretation) | open | Low |
| The empty-group mark uses the same true-only rule as `bool` | user decision 2026-10-05 (interpretation) | open | Low |
| Wire change for `false` rows needs a release note | release owner | open | Low |
