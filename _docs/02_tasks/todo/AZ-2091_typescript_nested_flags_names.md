# TypeScript flags in nested groups, member-name collisions, flag-byte leak

**Task**: AZ-2091_typescript_nested_flags_names
**Name**: TypeScript nested-group structure fixes
**Description**: Flags inside a group are packed, a member name that would be silently overwritten by group flattening fails at `scheme(...)`, and the raw flag-byte value no longer appears in unpacked rows.
**Complexity**: 3 points
**Dependencies**: AZ-2080_typescript_bool_flag_limit, AZ-2090_typescript_reference_scope (same construction pass and walker)
**Component**: typescript
**Tracker**: AZ-2091
**Epic**: AZ-2069

## Problem

Three defects, all reproduced on `d108141` (node 22.23, scratch scripts importing `typescript/src/index.ts`).

**1. Flags inside a group are dropped on pack (silent loss).** On pack, a flag byte's value is `flagValueFor(allFields, id, values)` (`walker.ts:96-101` → `fields.ts:284-290`). It collects bits with `collectFlagBits` (`fields.ts:263-275`), which descends into `when`, `repeat` and `times` but **not `group`**. Bits under a group are never found, so the byte is `00` and the fields are skipped.

| Scheme (type 1) | Row | Today | Correct |
|-----------------|-----|-------|---------|
| `u8(0, a)`, `group(x=>x.g, [u8(0, b), flags(1, [u8(1, c)])])` | `{a:1, g:{b:2, c:3}}` | `01010200`: `c` lost, no error | `0101020103` |
| same with an anchored `group(1, x=>x.g, [u8(1, b), flags(2, [u8(2, c)])])` | `{a:1, b:2, c:3}` | `01010200` | `0101020103` |

Unpack already handles these (it reads bits through the per-call flag map), so the correct bytes round-trip once pack writes them.

**2. Member-name collisions overwrite silently.** Values are one flat map. `flattenValues` (`fields.ts:416-426`) merges every nested plain object into the top level, and unpack writes group members flat too. The test "packs a class instance and flattens a nested group" shows this is intended. So a nested member whose name is also used outside its group overwrites the other value, and which one wins depends on the row's key order.

| Scheme | Row | Today | Correct |
|--------|-----|-------|---------|
| `u8(0, sid)`, `group(x=>x.g, [u8(0, sid)])` | `{sid:1, g:{sid:2}}` | packs `010202` (outer `sid` written as 2); unpack `{sid:2}` | `scheme(...)` throws |
| `flags(0, [group(x=>x.session, [u16(0, s=>s.session)])])` (group name = child name) | — | the child number overwrites the group object | `scheme(...)` throws |

**3. Raw flag-byte value leaks into the unpacked row.** Unpack stores `values[f.name] = v` for every flag byte (`walker.ts:261-268`). The short form `flags(...)` becomes an anonymous `flagByte("")` (`fields.ts:107`). The golden position row therefore unpacks with an extra `"": 0` member. A split form `flagByte("motion")` adds `motion: 1`. Inside `times`, it becomes a list (`"": [1, 0]`). Other packages do not expose it, and project AC-2 counts fields in the result.

## Rules

- **Collision rule:** after flattening, every member name must have one meaning. `scheme(...)` throws `RangeError` naming the member when a name declared inside an **unanchored** group is also declared outside that group (including by the group itself or by another unanchored group). Duplicates in the same scope stay allowed, e.g. two `when` branches writing the same member with different widths.
- Flag bits are found wherever their flag byte's bits are placed in the same scope, including inside groups.
- A flag byte's value is walk state only and is never a member of the result row.

## Outcome

- Both rows in table 1 pack to `0101020103` and round-trip.
- Schemes with an ambiguous member name fail at construction. Every scheme in tests, README and drivers still constructs.
- `unpack(4001000065cd1d00a3e1110100)` gives exactly `{sid, lat, lon, profile}`, with no `""` key.

## Scope

### Included
- Bit collection through `group` (anchored and unanchored) in pack.
- Construction-time collision check.
- Removing flag-byte values from unpacked rows (short form, split form, inside `repeat`/`times`).

### Excluded
- List/dict elements of kind `group`/`flags` (task 33).
- Changing the flat-row design (TS rows stay flat; documented as C4 in the scan).
- `repeat`/`times` slicing of nested containers (see flagged concern).

## Acceptance Criteria

**AC-1: flags in an unanchored group are packed**
Given `u8(0, a)`, `group(x=>x.g, [u8(0, b), flags(1, [u8(1, c)])])`
When `{a:1, g:{b:2, c:3}}` is packed and unpacked
Then the bytes are `0101020103` and the row has `a 1, b 2, c 3`

**AC-2: flags in an anchored group are packed**
Given the anchored variant
When `{a:1, b:2, c:3}` is packed
Then the bytes are `0101020103`; `{a:1, b:2}` gives `01010200`

**AC-3: nested name equal to an outer name fails construction**
Given `u8(0, sid)`, `group(x=>x.g, [u8(0, sid)])`
When `scheme(...)` is called
Then it throws `RangeError` naming `sid`

**AC-4: group name equal to a child name fails construction**
Given `group(x=>x.session, [u16(0, s=>s.session)])` under `flags`
When `scheme(...)` is called
Then it throws `RangeError` naming `session`

**AC-5: same-scope duplicates still allowed**
Given `u8(0, kind)`, `when(1, eq(0, 0), [u8(1, shape)])`, `when(2, eq(0, 1), [u16(2, shape)])`
When constructed and `{kind:1, shape:300}` is packed
Then construction succeeds and the bytes are `01012c01`

**AC-6: no flag-byte member in rows**
Given the golden position scheme, a split-form scheme `flagByte("motion")`, and a `times` body with `flags`
When their packets are unpacked
Then no row has a `""` or `motion` member, and the golden row's keys are exactly `sid, lat, lon, profile`

**AC-7: fixtures unchanged**
Given `fixtures/golden.hex`, the route fixture and the language-pair handoffs
When packed and unpacked
Then the bytes are unchanged

## Non-Functional Requirements

**Performance**
- The AC-10 loop stays ≤ 1 s.

**Compatibility**
- Wire bytes change only for schemes that dropped fields (table 1), and they now match what unpack already expected.

## Unit Tests

| AC Ref | Test name | Input | Required outcome (fails today) |
|--------|-----------|-------|-------------------------------|
| AC-1 | `flags inside a nested group are packed` | AC-1 row | `0101020103` (today `01010200`) |
| AC-2 | `flags inside an anchored group are packed` | AC-2 row | `0101020103` |
| AC-3 | `nested member shadowing an outer member is a scheme error` | AC-3 scheme | `RangeError` (today constructs) |
| AC-4 | `group name equal to child name is a scheme error` | AC-4 scheme | `RangeError` |
| AC-5 | `alternate when branches may share a member` | AC-5 | constructs, `01012c01` |
| AC-6 | `unpacked row has no flag byte member` | golden hex | keys exactly 4 (today 5, incl. `""`) |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-7 | `fixtures/golden.hex`, route fixture | pack/unpack | bytes unchanged | project AC-1/3 |
| AC-7 | language-pair handoffs (`user`, `nested`, `session`) | TS producer and consumer | unchanged, consumers pass | project AC-3 |
| AC-6 | language-pair `nested` consumer | compare fields | no extra member | project AC-2 |
| — | `fixtures/hostile/` (task 01) | unpack | still errors | Reliability |

## Constraints

- ADR-001: TS only.
- Browser-safe `src`.
- Scheme errors are `RangeError`.

## Risks & Mitigation

**Risk 1: A caller reads the flag byte from the row**
- *Risk*: `row.motion` or `row[""]` disappear.
- *Mitigation*: They were never part of the documented API. Note it in the v0.2.0 release notes.

**Risk 2: The collision rule rejects a legitimate scheme**
- *Mitigation*: The rule targets only names that flattening overwrites; same-scope duplicates stay legal (AC-5).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loop 12 (AZ-2129): the TypeScript `Scheme` constructor now runs every scheme check and `scheme()` delegates to it; put this task's new construction checks in the constructor, not only in `scheme(...)`, or `new Scheme` diverges again | coordinator | open | Low |
| Nested containers inside `repeat`/`times` are not sliced per item on pack (repro in task 21's concerns). It belongs with this structural work, but is not in the plan's scope for task 22 | coordinator | open | Medium |
| TS keeps flat rows while `Scheme<T>` suggests nested objects (scan C4). Design question, not fixed here | user | open | Low |
