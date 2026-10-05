# TypeScript references resolve in their own id scope

**Task**: AZ-2090_typescript_reference_scope
**Name**: TypeScript `when`/count reference resolution
**Description**: Every `eq(id, …)` and every count id (`sized`, `bits`, `packed`, `times`) must name an earlier field in the same id scope, checked once at `scheme(...)`. 64-bit values compare numerically, so a `when` on a `u64`/`i64` matches on unpack too.
**Complexity**: 3 points
**Dependencies**: AZ-2072_typescript_hostile_unpack, AZ-2080_typescript_bool_flag_limit (same walker and validation code)
**Component**: typescript
**Tracker**: AZ-2090
**Epic**: AZ-2069

## Problem

`validateFieldIds` (`fields.ts:355-410`) checks value-field and anchor order but never checks the ids inside `eq(...)` or a count. At pack/unpack time every reference is looked up by `nameById(allFields, id)` (`fields.ts:314-320`, `findNameById` `322-353`). That is a depth-first search from the top of the whole scheme, repeated on every call (`walker.ts:45`, `113`, `143`, `152`, `297`, `328`, `345`). It returns the first field with that id anywhere. Reproduced on `d108141`:

| # | Scheme (type 1) | Row / bytes | Today | Correct |
|---|-----------------|-------------|-------|---------|
| 1 | `u8(0, kind)`, `group(x=>x.g, [u8(0, inner), when(1, eq(0, 5), [u8(1, extra)])])`. Inside the unanchored group ids restart at 0, so `eq(0, …)` means `inner` | `{kind:5, g:{inner:9, extra:7}}` | packs `01050907`: matched the **outer** `kind` | `010509` (`inner` is 9 ≠ 5) |
| 2 | `when(0, eq(1, 5), [u8(0, a)])`, `u8(1, k)`: refers to a **later** field | `{a:7, k:5}` | constructs; packs `010705`; own unpack → `{ok:false, field:"", needed:0, left:1}` | `scheme(...)` throws |
| 3 | `u8(0, k)`, `when(1, eq(9, 5), [u8(1, a)])`: id 9 does not exist | — | constructs; pack throws `RangeError: unknown field id 9` | `scheme(...)` throws |
| 4 | `u8(0, n)`, `list(x=>x.xs, sized(0, x=>x.p, 0))`: inside the element scope, count id 0 is the `sized` itself | — | constructs | `scheme(...)` throws (no earlier field in scope) |
| 5 | `u64(0, k)`, `when(1, eq(0, 1), [u8(1, v)])` | `{k:1, v:9}` | packs `01010000000000000009`; unpack reads `k` as `1n`, `1n === 1` is false, group skipped → `{ok:false, field:"", needed:0, left:1}` | unpack `{k:1n, v:9}` |
| 5b | same with `eq(0, 1n)` and row `{k:1}` | — | pack: `1 === 1n` false → group not written | group written |

C++ already enforces the rule (`cpp/include/packbin/order.hpp:94-170`, `find_ref`). The scope is the nearest enclosing `repeat`/`times`/`list`/`dict`. `group`/`flags`/`when` are transparent, and a reference must name an earlier count-source field in that scope. TypeScript also has the unanchored (nested-object) `group`, whose ids restart at 0, so it opens a scope as well. Java, C# and Rust are fixed under tasks 18/20/06.

## Rule (from C04, C++ precedent)

- A **scope** is the scheme top level, or the body of `repeat`, `times`, a `list`/`dict` element, or an **unanchored** `group` (ids restart at 0). `flags`, flag bits, anchored `group` and `when` do not open a scope.
- A reference (`eq` field id, or the count id of `sized`/`bits`/`packed`/`times`) must name a value field that appears **before** the referencing field in the **same scope**. Fields inside an earlier `flags`/anchored group/`when` of that scope count. Fields inside an earlier nested scope do not.
- Count references must name an integer field. `eq` may name any value field (the route fixture uses `eq(3, true)` on a `bool` in `flags`).
- Violations throw `RangeError` from `scheme(...)` naming the referencing id and the referenced id.
- `eq` on an integer field compares numerically: `1`, `1n` and an unpacked `1n` are equal.

## Outcome

- References are resolved once at construction. Pack/unpack no longer search the scheme per call.
- Cases 2–4 fail at `scheme(...)`. Case 1 binds to `inner`. Cases 5/5b round-trip.
- All existing schemes in tests, README and drivers still construct and give the same bytes.

## Scope

### Included
- Construction-time validation and binding of references for `when`, `sized`, `bits`, `packed`, `times`.
- Numeric comparison for `eq` on 64-bit (and any integer) fields.

### Excluded
- Flags in nested groups, name collisions, flag-byte leak (task 22).
- List/dict elements of kind `group`/`flags` (task 33).
- The slicing of nested containers inside `repeat`/`times` (see flagged concern).

## Acceptance Criteria

**AC-1: nested scope binds to its own field**
Given scheme 1
When `{kind:5, g:{inner:9, extra:7}}` is packed
Then the bytes are `010509`; and with `inner:5` they are `01050507`, which unpacks with `extra === 7`

**AC-2: later field is a scheme error**
Given scheme 2
When `scheme(...)` is called
Then it throws `RangeError` mentioning ids 0 (the `when`) and 1

**AC-3: unknown id is a scheme error**
Given scheme 3
When `scheme(...)` is called
Then it throws `RangeError` mentioning id 9 (today it throws only at pack)

**AC-4: element self-reference is a scheme error**
Given scheme 4
When `scheme(...)` is called
Then it throws `RangeError`

**AC-5: 64-bit when matches both ways**
Given scheme 5
When `{k:1, v:9}` is packed and unpacked, and when `eq(0, 1n)` is used with `{k:1}`
Then pack gives `01010000000000000009`, unpack gives `ok:true` with `v === 9`, and the `1n` form packs the same bytes

**AC-6: existing schemes unchanged**
Given every scheme in `typescript/tests`, the route fixture (`times(7, 5, …)`, `when(9, eq(3, true), [packed(1, 9, mask, 5, -1)])`), the README examples and `.github/workflows/drivers/*.ts`
When constructed, packed and unpacked
Then they construct and the bytes are unchanged

## Non-Functional Requirements

**Performance**
- The AC-10 loop stays ≤ 1 s. Lookups move from per call to construction, so the loop should get faster.

**Compatibility**
- Browser-safe `src`. Public builder signatures are unchanged.

## Unit Tests

| AC Ref | Test name | Input | Required outcome (fails today) |
|--------|-----------|-------|-------------------------------|
| AC-1 | `when in nested group uses the group's ids` | scheme 1, row | `010509` (today `01050907`) |
| AC-2 | `when naming a later field is a scheme error` | scheme 2 | `RangeError` (today constructs) |
| AC-3 | `unknown reference id is a scheme error` | scheme 3 | `RangeError` at `scheme` |
| AC-4 | `count naming itself in an element is a scheme error` | scheme 4 | `RangeError` |
| AC-4 | `count naming a field inside an earlier times is a scheme error` | `u8(0, c)`, `times(1, 0, [u8(1, n)])`, `sized(2, p, 1)` | `RangeError` |
| AC-5 | `u64 when matches on unpack` | scheme 5 | `ok:true`, `v 9` (today trailing error) |
| AC-5 | `bigint eq value matches number field value` | `eq(0, 1n)`, `{k:1}` | group written |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | route fixture `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` | pack/unpack | unchanged | project AC-3 |
| AC-6 | `fixtures/golden.hex`, language-pair handoffs | unchanged | unchanged | project AC-1/3 |
| — | `fixtures/hostile/` `count_behind_clear_flag` (task 01) | unpack | still an error (task 03), now through the construction-bound reference | Reliability |

## Constraints

- ADR-001: TS only. The rule mirrors C++ by specification, not by shared code.
- Browser-safe `src`.
- Scheme errors are `RangeError`, like the existing id-order errors.

## Risks & Mitigation

**Risk 1: A caller's scheme referenced an outer field from inside `repeat`/`times`**
- *Risk*: It now fails construction.
- *Mitigation*: Inside those bodies the outer value was never per-item. C++ already rejects this. The message names both ids.

**Risk 2: Scope of the unanchored group differs from other languages**
- *Mitigation*: Only TS has a nested-object group; documented under C3 in the scan.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loop 12 (AZ-2129): the TypeScript `Scheme` constructor now runs every scheme check and `scheme()` delegates to it; put this task's new construction checks in the constructor, not only in `scheme(...)`, or `new Scheme` diverges again | coordinator | open | Low |
| The unanchored `group` opens a scope in TS only (ids restart at 0); other packages have no such group | coordinator / C04 | accepted-risk | Low |
| Found while writing this spec: `repeat`/`times` pack only per-item slices of **direct** children. `u8(0, n)`, `times(1, 0, [u8(1, mode), when(2, eq(1, 1), [u8(2, v)])])` with `{n:2, mode:[1,1], v:[3,4]}` throws `RangeError: expected number` on pack; same for an anchored `group(1, g, [u8(1, a)])` inside `times`. Not owned by any task. Proposal: add it to task 22 or open a new TS task | coordinator | resolved (owner decision 2026-10-05: fixed in AZ-2091, the TypeScript part of AZ-2134) | Medium |
