# TypeScript dict keys must not flatten into the row

**Task**: AZ-2184_typescript_dict_keys_not_flattened
**Name**: TypeScript dict entries stay out of the row's members
**Description**: On pack, the keys of a dictionary value no longer become members of the row, so a key equal to a member name cannot overwrite or supply that member, and only declared unanchored groups are flattened.
**Complexity**: 2 points
**Dependencies**: AZ-2091_typescript_nested_flags_names (flat rows and the flattening rule for nested groups)
**Component**: typescript
**Tracker**: AZ-2184
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (T33, G1), owner scope A on 2026-10-05.

TypeScript rows are flat: before packing, every nested plain object in the row is merged into the top level. A dictionary value is a plain object, so each of its keys becomes a member of the row.

- A dict key equal to a member name overwrites that member, and which one wins depends on the key order of the row. Probe (verified): `u8(0, a)`, `dict(x => x.m, u8(0, x => x.v))`. `{a:1, m:{a:9}}` packs `01 09 01 00 01 00 61 09` (a = 9); `{m:{a:9}, a:1}` packs `01 01 01 00 01 00 61 09` (a = 1).
- A dict key equal to the dictionary's own member name replaces it: `{a:1, m:{m:9}}` throws `m: expected dictionary`.
- A key can supply a member that the row lacks: `{m:{a:9}}` (no top-level `a`) packs a = 9 instead of throwing `missing a`.
- A decoded `__proto__` entry that holds an object takes part too. Scheme `u8(0, a)`, `dict(m, dict(n, u8))`, wire `01 01 01 00 09 00 5f5f70726f746f5f5f 01 00 01 00 61 09` unpacks to `a = 1` with the dictionary `m` holding an own `__proto__` entry `{a:9}`, and the unpacked row repacks to `01 09 ...`: `a` silently changes from 1 to 9. (The ticket text said such a row repacks to the same bytes; the probe shows it does not.)
- AZ-2091 Problem 2 names the rule: "a nested member whose name is also used outside its group overwrites the other value, and which one wins depends on the row's key order". AZ-2102 (dict of group) shares the root cause for dict-of-group only; flat rows stay (AZ-2102 Excluded).

## Outcome

- Both key orders pack the same bytes, and the dictionary's keys never change another member.
- Unpack then repack of a wire gives the same bytes, including a `__proto__` entry.
- A missing top-level member is still reported as missing, whatever the dictionary holds.
- Only the members of a declared unanchored group are flattened into the row.

## Scope

### Included
- The flattening of a row's values before pack: dictionary values (at any depth) are not flattened.
- Tests for the probes above.

### Excluded
- Packing a group element per item in a list or dict (AZ-2102); this task does not add it. If the change here already gives AZ-2102 AC-3 its bytes, AZ-2102 only adds its own tests.
- Changing the flat-row design (scan C4); the unpack side.
- A `__proto__` key in a dict being kept as an ordinary key on unpack (done in AZ-2122).

## Acceptance Criteria

**AC-1: Key order does not matter**
Given `u8(0, a)`, `dict(x => x.m, u8(0, x => x.v))`
When `{a:1, m:{a:9}}` and `{m:{a:9}, a:1}` are packed
Then both give `01 01 01 00 01 00 61 09` (a = 1, one entry `a` = 9).

**AC-2: A key named like the dictionary keeps its entry**
Given the scheme of AC-1
When `{a:1, m:{m:9}}` is packed
Then the bytes are `01 01 01 00 01 00 6d 09`; a key named `v` still packs as `01 01 01 00 01 00 76 09`.

**AC-3: A key does not supply a missing member**
Given the scheme of AC-1
When `{m:{a:9}}` and `{m:{b:9}}` are packed
Then both throw `RangeError` `missing a`.

**AC-4: Nested dictionaries keep to themselves**
Given `u8(0, a)`, `dict(m, dict(n, u8))`
When `{a:1, m:{x:{a:9}}}` is packed
Then the bytes are `01 01 01 00 01 00 78 01 00 01 00 61 09`.

**AC-5: A decoded `__proto__` entry repacks identically**
Given the scheme of AC-4 and the wire `01 01 01 00 09 00 5f5f70726f746f5f5f 01 00 01 00 61 09`
When it is unpacked and the row is packed again
Then the unpacked row has `a = 1` and its dictionary `m` has an own `__proto__` entry, and the second pack equals the wire.

**AC-6: Declared unanchored groups still flatten**
Given `u8(0, a)`, `group(x => x.g, [u8(0, b)])`, and the same with an inner `group(x => x.h, [u8(0, c)])`
When `{a:1, g:{b:2}}`, a class instance with the same members, and `{a:1, g:{b:2, h:{c:3}}}` are packed
Then the bytes are `01 01 02`, `01 01 02` and `01 01 02 03`.

**AC-7: Fixtures unchanged**
Given `fixtures/golden.hex`, the route fixture and the language-pair `user` and `nested` handoffs (they use dictionaries)
When they are packed and unpacked
Then the bytes are unchanged.

## Non-Functional Requirements

**Reliability**
- A row built from untrusted JSON cannot change the row's other members or prototype through a dictionary key.

**Compatibility**
- Wire bytes change only for rows whose dictionary keys collided with a member name.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | both key orders | same bytes, a = 1 (fails today for the first order) |
| AC-2 | key `m`, key `v` | packs the entry (key `m` throws today) |
| AC-3 | `{m:{a:9}}`, `{m:{b:9}}` | `RangeError` `missing a` (first packs today) |
| AC-4 | dict of dict with a key `a` | a stays 1 |
| AC-5 | unpack the `__proto__` wire, repack | identical bytes (today `a` becomes 9) |
| AC-6 | unanchored group, class instance, nested group | `01 01 02`, `01 01 02`, `01 01 02 03` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-7 | `fixtures/golden.hex`, route fixture, `user` and `nested` handoffs | pack and unpack | unchanged hex; consumers pass | project AC-3 |

## Constraints

- ADR-001: TypeScript only; browser-safe `src`; no public API change.
- Wire bytes in the ACs come from probes of the current code (the key-order bytes) and from the layout rules (the corrected bytes); the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller relied on a dictionary key supplying a member**
- *Risk*: a row that packed only because a dict key matched a missing member now throws `missing a`.
- *Mitigation*: that was a silent mix-up of two values; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| An anchored group given as a nested object (`{a:1, g:{b:2}}`) packs today only because every nested object is flattened (verified: `01 01 02`). The ticket lists only unanchored groups. Recommendation: keep accepting it, same bytes; the owner confirms before implementation | owner | open | Medium |
| AZ-2102 AC-3 (dict of group keeps each entry) shares this root cause; land both in one loop or let the second only add tests | coordinator | open | Low |

## Owner decision (2026-10-06)

DECIDED, the proposed default: keep accepting an anchored group given as a nested object; the bytes are the same. The open DECISION rows above are resolved by this section.
