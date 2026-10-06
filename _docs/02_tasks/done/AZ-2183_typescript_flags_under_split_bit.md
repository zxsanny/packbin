# TypeScript packs flags under a split flag bit and flags directly inside flags

**Task**: AZ-2183_typescript_flags_under_split_bit
**Name**: TypeScript pack finds flags under a split bit and inside flags
**Description**: A `flags` that sits inside a group under a split-form flag bit, or directly inside another `flags`, is packed with its values instead of dropped, so unpack then repack gives the same bytes.
**Complexity**: 2 points
**Dependencies**: AZ-2091_typescript_nested_flags_names (flag bits found through groups, flat rows), AZ-2128_flag_group_presence_parity (group presence at any depth; still in todo)
**Component**: typescript
**Tracker**: AZ-2183
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (T14, G2) and batch 3 review F1 (Medium, pre-existing, identical before loop 13); owner scope A on 2026-10-05.

- On pack, the values of a `flags` are lost, with no error, in two shapes: a `flags` inside a group that is the field of a split-form flag bit, and a `flags` that is a direct member of another `flags`. The inner flag byte is not found, so its bits are never set and its values are skipped. Unpack already reads both shapes.
- Probe 1 (verified on the current code): `fb = flagByte("m")`, scheme `(1, fb, fb.bit(group(g, [u8 a, flags(1, [u8 c])])))`. `{g:{a:1,c:2}}` packs `01 01 01 00` (`c` lost). Unpacking `01 01 01 01 02` gives `{a:1,c:2}`, and that row repacks to `01 01 01 00`.
- Probe 2: `flags(0, [flags(0, [u8 c])])`. `{c:2}` packs `01 00`. Unpacking `01 01 01 02` gives `{c:2}`, and that row repacks to `01 00`.
- Batch 3 fuzz over schemes that allow the shape: 71 of 20 240 accepted packets change their row on repack.
- AZ-2091 Rule 2 says: "Flag bits are found wherever their flag byte's bits are placed in the same scope, including inside groups". AZ-2091 AC-1 and AC-2 cover groups reached through `flags` and anchored groups; these two shapes were not covered.

## Outcome

- Both probes pack their values: `01 01 01 01 02` and `01 01 01 02`.
- Unpack then repack of any accepted packet of these shapes gives the same bytes (the fuzz changes 0 of its accepted packets).
- A group under a split flag bit is present when any value inside it is present, at any depth (AZ-2128).

## Scope

### Included
- Pack of flag bits and flag bytes found under a split-form flag bit's group, and under a `flags` inside `flags`.
- Tests for the two probes, the absent-value cases and the repack identity.

### Excluded
- Group presence for `u2`, `bits`, `sized` and `packed` children, and the flat unpacked row of a group made only of such children: AZ-2128 (batch 3 discovered 5).
- Flat rows (scan C4): TypeScript rows stay flat; `g` is not a member of an unpacked row.
- Unpack (already correct); wire format.

## Acceptance Criteria

**AC-1: Flags under a split-form bit are packed**
Given `fb = flagByte("m")` and the scheme `(1, fb, fb.bit(group(g, [u8 a, flags(1, [u8 c])])))`
When `{g:{a:1,c:2}}` is packed
Then the bytes are `01 01 01 01 02`.

**AC-2: Unpack then repack is identical**
Given the scheme of AC-1
When `01 01 01 01 02` is unpacked and the row is packed again
Then the row is `{a:1,c:2}` and the second pack is `01 01 01 01 02`.

**AC-3: Absent values stay absent**
Given the scheme of AC-1
When `{g:{a:1}}` and `{}` are packed
Then the bytes are `01 01 01 00` and `01 00`, as today.

**AC-4: A missing required member in a present group is still named**
Given the scheme of AC-1
When `{g:{c:2}}` is packed (the group holds a value but not `a`)
Then pack throws `RangeError` naming `a`, as today (AZ-2128 AC-2).

**AC-5: `flags` directly inside `flags`**
Given `flags(0, [flags(0, [u8 c])])`
When `{c:2}` and `{}` are packed
Then the bytes are `01 01 01 02` and `01 00`; unpacking `01 01 01 02` gives `{c:2}` and repacking gives `01 01 01 02`.

**AC-6: No accepted packet changes its row on repack**
Given the batch 3 review fuzz (schemes that allow these shapes, accepted packets only)
When every accepted packet is unpacked and the row packed again
Then 0 of the accepted packets give a different row or bytes.

**AC-7: Fixtures unchanged**
Given `fixtures/golden.hex`, the route fixture and the language-pair handoff rows
When they are packed and unpacked
Then the bytes are unchanged (golden `4001000065cd1d00a3e1110100`).

## Non-Functional Requirements

**Compatibility**
- Wire bytes change only for rows that dropped values today; they now equal what unpack already expects.

**Reliability**
- Pack returns bytes that unpack reads back as the same row, or throws.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | split-bit group holding `flags`, row `{g:{a:1,c:2}}` | `01 01 01 01 02` (fails today: `01 01 01 00`) |
| AC-2 | unpack `01 01 01 01 02`, repack | `{a:1,c:2}`, identical bytes |
| AC-3 | `{g:{a:1}}`, `{}` | `01 01 01 00`, `01 00` |
| AC-4 | `{g:{c:2}}` | `RangeError` names `a` |
| AC-5 | `flags` in `flags`, `{c:2}` and `{}` | `01 01 01 02`, `01 00`; unpack/repack identical |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | batch 3 review fuzz, or an equivalent seeded generator over the two shapes | unpack, repack, compare | 0 changed rows in the accepted packets | Reliability |
| AC-7 | `fixtures/golden.hex`, route fixture, language-pair `user`, `nested`, `session` handoffs | pack and unpack | unchanged hex; consumers pass | project AC-3 |

## Constraints

- ADR-001: TypeScript only; each package keeps its own walker.
- Browser-safe `src`; construction checks stay in the `Scheme` constructor (AZ-2129).
- No public API change (`index.d.ts` identical).
- Wire bytes in the ACs come from the batch 3 probes and from reading the unpack side; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller relied on the dropped value**
- *Risk*: a row that packed `01 01 01 00` now packs `01 01 01 01 02`.
- *Mitigation*: the old bytes lost caller data and unpacked to a different row than the one sent; README upgrade note in the next docs pass.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| AZ-2128 (group presence at any depth, TypeScript included) is still in todo; AC-4 holds today, and the presence of a group whose only value sits in nested `flags` follows it | coordinator (land AZ-2128 first or in the same loop) | open | Medium |
| Flat unpacked row of a group made only of flag-bit, `u2` or `sized` members does not repack (batch 3 discovered 5) | AZ-2128 | open | Low |

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 2). Root causes: a `flags` inside a group under a split bit got a new flag byte on every walk, and a `flags` directly inside `flags` was packed against the wrong field list. A `when`, `times` or `repeat` under a split bit's group still has no presence: the open concern of AZ-2128, held for the C# loop by the owner.
