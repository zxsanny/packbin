# TypeScript list and dictionary elements of kind group and flags

**Task**: 33_typescript_list_group_elements
**Name**: TypeScript group/flags as list and dict elements
**Description**: `list(acc, group(...))`, `list(acc, flags(...))`, `dict(acc, group(...))` and `dict(acc, flags(...))` pack each item from its own object and unpack each item to its own object, with the same bytes as Python.
**Complexity**: 3 points
**Dependencies**: 21_typescript_reference_scope (element id scope), 22_typescript_nested_flags_names (flag collection and the flat-name rule)
**Component**: typescript
**Tracker**: pending
**Epic**: AZ-2069

## Problem

The strings-lists-dicts restrictions say "List and dictionary elements may be any existing field, including string, list, and dictionary. `repeat` is not an element." In TypeScript, `group` elements corrupt or lose data silently, and `flags` elements cannot be declared at all. Reproduced on `d108141`; the Python bytes come from the same rows with item accessors.

| # | Scheme (type 1) | Row / bytes | TS today | Python today (reference) |
|---|-----------------|-------------|----------|--------------------------|
| 1 | `list(x=>x.pts, group(x=>x.p, [u8(0, p=>p.a), u8(1, p=>p.b)]))` | pack `{pts:[{a:1,b:2},{a:3,b:4}]}` | throws `RangeError: missing a`: the element is packed from the **row's** values, not from the item (`walker.ts:179-190`, slice `{...values, [child]: item}`) | `01020001020304` |
| 2 | same | unpack `01020001020304` | `{ok:true}` with `pts: [null, null]`: **silent loss**. The group writes `a`/`b` into the element map and `items.push(one[child])` reads the group's own name, which is never set (`walker.ts:382-399`) | `pts == [{a:1,b:2},{a:3,b:4}]` |
| 3 | `dict(x=>x.m, group(x=>x.p, [u8(0,a), u8(1,b)]))` | pack `{m:{y:{a:3,b:4}, x:{a:1,b:2}}}` | `01020001007801020100790102`: **silent corruption**. `flattenValues` (`fields.ts:416-426`) flattens the item objects into the row, `x`'s `a`/`b` overwrite `y`'s, and both entries are written as `01 02` | `01020001007801020100790304` |
| 4 | `list(x=>x.pts, flags(0, [u8(0, p=>p.a), u16(1, p=>p.b)]))` | declare | `RangeError: list element must be one field`, because `flatten` turns `flags` into a flag byte + bits (`fields.ts:244-250`, same in `dict` `252-261`) | constructs; `{pts:[{a:1},{},{b:2}]}` → `010300010100020200`, round-trips |

## Outcome

- A `group` or `flags` element packs each item from that item's own members and unpacks to one object per item, holding the element's members. Bytes equal Python's.
- Element ids restart at 0 (unchanged rule). References inside the element resolve in the element scope (task 21).
- Leaf elements (`u16`, `utf8`, nested `list`/`dict`) keep today's behavior and bytes, e.g. the handoff `user`/`nested` fixtures.

## Scope

### Included
- `list` and `dict` with element kinds `group` (unanchored, i.e. nested object) and `flags` (short form).
- Construction accepts a `flags` element.
- Items are objects (plain or class instances). An absent member in an item follows the usual rule: required members throw on pack, members under flags clear their bit.

### Excluded
- `when` or `times` as a direct element. Python supports them; these are not in this task's plan line. See flagged concern.
- `repeat` elements (stay forbidden).
- Changing how top-level rows are flattened.

## Acceptance Criteria

**AC-1: list of group packs per item**
Given scheme 1
When `{pts:[{a:1,b:2},{a:3,b:4}]}` is packed
Then the bytes are `01020001020304`

**AC-2: list of group unpacks per item**
Given scheme 1
When `01020001020304` (Python's bytes) is unpacked
Then `ok` is true and `pts` deep-equals `[{a:1,b:2},{a:3,b:4}]`

**AC-3: dict of group keeps each entry**
Given scheme 3
When `{m:{y:{a:3,b:4}, x:{a:1,b:2}}}` is packed and unpacked
Then the bytes are `01020001007801020100790304`, and `m` deep-equals `{x:{a:1,b:2}, y:{a:3,b:4}}`

**AC-4: flags element is accepted and matches Python**
Given scheme 4
When `{pts:[{a:1},{},{b:2}]}` is packed and unpacked
Then the bytes are `010300010100020200`, and the items are `{a:1}`, `{}`, `{b:2}` (no flag-byte member, per task 22)

**AC-5: short element is an error with no row**
Given scheme 1
When `010200010203` (second item missing `b`) is unpacked
Then the result is `{ok:false, field:"b", needed:1, left:0}` and the handler is not called

**AC-6: leaf elements unchanged**
Given the existing list/dict tests and the language-pair `user` and `nested` fixtures
When packed and unpacked
Then the bytes are unchanged

## Non-Functional Requirements

**Performance**
- The AC-10 loop stays ≤ 1 s. It has no lists.

**Compatibility**
- Wire format unchanged. These schemes now produce the bytes every other package expects.

## Unit Tests

| AC Ref | Test name | Input | Required outcome (fails today) |
|--------|-----------|-------|-------------------------------|
| AC-1 | `list of group packs each item` | row 1 | `01020001020304` (today throws) |
| AC-2 | `list of group unpacks each item` | `01020001020304` | objects (today `[null, null]`) |
| AC-3 | `dict of group keeps each entry` | row 3 | `…0304` tail (today `…0102`) |
| AC-4 | `list of flags round trip` | row 4 | `010300010100020200` (today construction error) |
| AC-5 | `short group element` | `010200010203` | short error on `b` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | bytes `01020001020304` produced by Python | TS unpack | same items | project AC-3 |
| AC-3 | bytes `01020001007801020100790304` produced by Python | TS unpack | same entries | project AC-3 |
| AC-6 | language-pair `user`, `nested` handoffs | unchanged | unchanged | project AC-3 |
| — | `fixtures/hostile/` `oversize_count` (list count `ffff`) | unpack | still a short error | Reliability |

## Constraints

- ADR-001: TS only. Python is a byte reference, not a code source.
- Browser-safe `src`.
- strings-lists-dicts rules unchanged: u16 count, ≤ 65535, dict keys ordered by unsigned UTF-8 bytes.

## Risks & Mitigation

**Risk 1: Element objects vs flat rows**
- *Risk*: Top-level rows are flat while element items become objects, so callers see two shapes.
- *Mitigation*: An element has its own id scope and its own values. It is documented as "one object per item", which matches Python.

**Risk 2: Interaction with the collision rule (task 22)**
- *Mitigation*: Element member names live in the element's own namespace and do not collide with row names.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `when` / `times` / anchored `group` as direct elements are allowed by the spec text but not covered here | coordinator | open | Low |
| No cross-language fixture covers list/dict of group or flags; this task's Python-produced hex should go into the shared vectors | task 01 owner | open | Low |
