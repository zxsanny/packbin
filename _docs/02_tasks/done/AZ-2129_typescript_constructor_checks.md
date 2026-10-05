---
loop: 12
---

# TypeScript `Scheme` constructor runs the scheme checks; pin non-true bool values

**Task**: AZ-2129_typescript_constructor_checks
**Name**: TypeScript constructor checks
**Description**: `new Scheme(...)` refuses every scheme `scheme(...)` refuses; a bool value other than `true` is pinned to a clear bit; the TS driver joins the `bitwhen` ring.
**Complexity**: 2 points
**Dependencies**: AZ-2080_typescript_bool_flag_limit
**Component**: typescript
**Tracker**: AZ-2129
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment (`_docs/loops/loop12/assessment12.md` U1, G3, U4).

- **U1**: the `Scheme` class is exported and its constructor skips every check `scheme()` runs (field ids, flag-bit scope, bool / empty-group placement). `new Scheme(1, [bool(0, x => x.on)])` builds, packs `{on:true}` as `01`, and every unpack returns `on: true` — the behavior AZ-2080 removed.
- **G3**: `{on: 1}` and `{on: "yes"}` pack `0100` (true-only rule), but no test pins it.
- **U4**: Cross-language `bitwhen` vector (owner decision U4, 2026-10-05): scheme type 1 = `u8 k` (id 0), split flag byte `m`, `when(eq(k, 1), [m.bit(u8 v)])`. Row `{k:0, v:5}` packs `010001` (the bit is set from the row even though the `when` is not taken; unpack checks the `when` first and never reads it); row `{k:1, v:5}` packs `01010105`. Driver contract: `pack-bitwhen` prints the hex of `{k:0, v:5}`; `unpack-bitwhen <hex>` exits 0 only if unpack is ok, `k == 0` and `v` is absent.

## Owner decisions (2026-10-05)

U1: A — the constructor runs the same checks (no signature change). U4: A — keep the bytes, pin them with one shared vector.

## Acceptance Criteria

**AC-1: constructor refuses what `scheme()` refuses**
Given `new Scheme(1, [bool(0, x => x.on)])`, a scheme with a wrong field id, and a split bit outside its flag byte's scope
When each is constructed with `new`
Then each throws the same `RangeError` message `scheme(...)` gives

**AC-2: valid schemes unchanged**
Given every scheme the existing tests build through `scheme()` or `new Scheme`
When the suite runs
Then all pass with identical bytes (golden, route fixture)

**AC-3: non-true values clear the bit**
Given `flags(0, [bool(0, x => x.on)])`
When `{on: 1}` and `{on: "yes"}` are packed
Then both are `0100`, and unpack of `0100` has no `on`

**AC-4: bitwhen vector**
Given the `bitwhen` scheme
When `{k:0, v:5}` and `{k:1, v:5}` are packed and unpacked
Then `010001` (unpacks `k: 0`, no `v`) and `01010105` (round-trips); the driver implements `pack-bitwhen` / `unpack-bitwhen`

## Constraints

- ADR-001; files ≤ 500 lines; strict `tsc` clean.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | — | — |
