# Rust typed `times` binds a `Vec<E>` and round-trips

**Task**: AZ-2086_rust_typed_times_vec
**Name**: Rust typed times
**Description**: A typed `times` binds a `Vec<E>` member of element rows. Pack writes one round per element; unpack builds one `E` per round. Typed schemes can then express the README times example and the route fixture.
**Complexity**: 3 points
**Dependencies**: AZ-2085_rust_typed_scheme_integrity (same typed compiler and binder names), AZ-2075_rust_hostile_unpack (scope rule for references inside `times`)
**Component**: rust
**Tracker**: AZ-2086
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C07 (typed `times`), C18 note; discovery `scan_rust_cpp.md` LB4, LB5 (times part), C4; probes R-P12, R-P6.

### User decision (2026-10-05, verbatim)

> Rust typed `times`: Fix it: typed `times` binds a `Vec<E>` of element rows.

### Defect 1: typed `times` binds children to scalar members of the parent row

- `SchemeItem::times(anchor, count_id, members)` (`rust/src/scheme/mod.rs:73-83`) compiles its children like any other bound field (`mod.rs:148-165`), so each child's get/set reads and writes **one scalar** of the parent row `T`.
- **Pack.** `slice_times` (`rust/src/walk/pack.rs:33-52`) takes item `i` from a `Value::List`, or the scalar for index 0 only, so rounds 1… are missing.
- **Unpack** (`rust/src/walk/unpack.rs:287-327`) builds one `Value::List` per child name. The scalar setter rejects a `List` (`rust/src/scheme/bound.rs:30-34`) and silently ignores it.
- **R-P12** (`struct R { n: u8, x: u8 }`, scheme `[BoundField::u8(0, n), SchemeItem::times(1, 0, [BoundField::u8(1, x)])]`):

| Call | Result |
|------|--------|
| pack `n = 1, x = 9` | `01 01 09` |
| pack `n = 2, x = 9` | `Err(Missing("1"))` |
| `unpack_with` of `01 01 09` | `Ok`, row `R { n: 1, x: 0 }` — **the 9 is dropped** |

- No test or driver uses typed `times` (`grep SchemeItem::times` outside `scheme/mod.rs`: 0 hits).

### Defect 2: optional fields inside `times` lose position

Map walker, R-P6. Scheme `[u8("0"), times(1, "0", [flags(1, "f", [u8("1")]), u8("2")])]`:
- unpack of `01 02 00 05 01 09 06` gives per-name lists `"1" = [9]`, `"2" = [5, 6]`. Which round had `"1"` is lost.
- repack gives `01 02 00 05 00 06`, so `9` is dropped. `slice_times` keys by the flags name, not by its members.

### Cross-language reference

C++ binds `times<&Row::items>(id, count_id, children…)` to an `Array<E, N>`:
- children bind members of `E`;
- pack requires the count field to equal the array count, else `BadValue` (`cpp/src/core/pack.cpp:195-202`);
- unpack fills one item per round, clearing optional members first (`cpp/src/core/unpack.cpp:186-205`).

The ids of `times` children continue the parent numbering (scheme-field-order AC-2): in `[u8 n (0), times(1, 0, [i32 lat (1), i32 lon (2)]), u8 tail (3)]` the elements are ids 1 and 2.

## Outcome

- A Rust caller binds `times` to `Vec<E>` with element binders on `E`. Any count packs and unpacks without loss.
- The README times vector and the route fixture pack from typed Rust rows with 0 mismatched bytes.
- Optional members inside an element (flags/when on element fields) keep their round.

## Scope

### Included
- Typed `times` takes the `Vec<E>` accessors (get/set on `T`) and element items built for `E` (`E: Default`).
- Element items may be any typed item a top-level row supports: required/optional scalars, `bytes`, `utf8`, `bool_flag` inside `flags`, `SchemeItem::flags`, `SchemeItem::when` on element fields.
- Pack: count field value ≠ `Vec` length → `PackError` naming the `times` (C++ rule). Element ids continue the parent numbering. References inside the element resolve in the element scope (task 06).
- Unpack: one `E::default()` per round, filled by the element binders, then set as the `Vec`. Unpack does not pre-allocate from a count read off the wire beyond what the bytes left can hold.
- The map-level `times` keeps per-round alignment for optional members (R-P6).

### Excluded
- Typed `repeat`, `u2`, flag byte, generic list/dict (C18 parity, undecided). `times` nested inside a `times` element (construction error with a message). Error labels (C15).

## Acceptance Criteria

**AC-1: README times vector from a typed row**
Given `struct Point { lat: i32, lon: i32 }`, `struct Row { n: u8, points: Vec<Point>, tail: u8 }`, and scheme `[u8(0, n), times(1, 0, points, [i32(1, lat), i32(2, lon)]), u8(3, tail)]` with `n = 2, points = [(10, 20), (30, 40)], tail = 7`
When packed and unpacked through `unpack_with`
Then the bytes are `01 02 0a000000 14000000 1e000000 28000000 07`, and the row comes back equal.

**AC-2: Count 0 and 1**
Given `n = 0, points = []` and `n = 1, points = [(10, 20)]`
When packed and unpacked
Then the bytes are `01 00 07` and `01 01 0a000000 14000000 07`, and both rows round-trip (R-P12 fixed: the value is not dropped).

**AC-3: Count and length must agree**
Given `n = 2, points = [(10, 20)]` (or 3 points)
When packed
Then pack fails naming the `times` field, and 0 bytes are returned.

**AC-4: Optional members keep their round**
Given an element `E { a: Option<u8>, b: u8 }` with items `[flags(1, [opt_u8(1, a)]), u8(2, b)]`, `n = 2`, and elements `(None, 5), (Some(9), 6)`
When packed and unpacked
Then the bytes are `01 02 00 05 01 09 06`, and the row comes back equal. The map form of R-P6 repacks the same 7 bytes.

**AC-5: Typed route fixture**
Given the route as a typed scheme:
- `sid` u16 (0), `name` u16 (1);
- `flags(2, [opt_u16 unit (2), bool_flag straight (3), opt_u16 route_id (4)])`;
- `count` u8 (5), `kinds` `packed(2, 6, 5, 0)`;
- `times(7, 5, points, [i32 lat (7), i32 lon (8)])`;
- `when(9, eq(3, 1), [packed(1, 9, 5, -1) mask])`.

When the row `sid 16, name 21, unit absent, straight true, route_id 45, count 2, kinds [1, 3], points [(500000000, 300000000), (500010000, 300010000)], mask [1]` (values from `route_matches_fixture_and_rejects_a_short_tail`) is packed and the fixture unpacked
Then the bytes equal `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`, and every field round-trips.

**AC-6: Hostile counts**
Given a typed `times` and the `fixtures/hostile/cases.txt` case `oversize_count_times` (`01ffffffff00`: `u32` count 4294967295, `times` of one `u8`, 1 byte left), and `negative_count` adapted to a `times` count (`i8` −1)
When unpacked
Then `Err` is returned without panic, and without allocating storage proportional to the hostile count.

## Non-Functional Requirements

**Performance**
- AC-10 holds (the position row has no `times`). Packing N elements is O(N).

**Reliability**
- Unpack memory is bounded by the input length, never by a count field.

## Unit Tests

Add these first; AC-1, AC-2 (count 1 unpack), AC-4 and AC-5 fail today.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | README times row pack + unpack | exact hex; row equal (today: no `Vec` form; scalar form fails `Missing`) |
| AC-2 | counts 0 and 1 | `010007`, `01010a0000001400000007`; round-trip (today: count-1 unpack drops x) |
| AC-3 | count 2 with 1 element; count 2 with 3 elements | `PackError` naming the times |
| AC-4 | optional member per round (typed and map R-P6) | `01020005010906` both ways |
| AC-5 | typed route | fixture hex both ways |
| — | existing map tests `times_stops_so_the_next_field_is_read`, `route_matches_fixture_and_rejects_a_short_tail` | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | route fixture hex (schema.md "Borrowed count") | typed pack/unpack | 0 mismatched bytes | AC-3 (project) |
| AC-1 | README times bytes (other packages pack the same) | typed pack | identical | AC-3 |
| AC-6 | `fixtures/hostile/cases.txt` `oversize_count_times` through the typed `times` (`Vec<E>`) scheme | `unpack_with` | `Err(Short)` after one round, < 1 s, no panic, no `Vec` pre-sized to 4294967295 | Reliability |
| AC-6 | an `i8` count of −1 for a typed `times` (hex `01ff`) | `unpack_with` | `Err`, no panic | Reliability |

## Constraints

- ADR-001: Rust's own typed layer and walker; the C++ `Array` binding is the behavioural reference only.
- Wire bytes unchanged: typed `times` must produce exactly the map/README bytes.
- Construction failures stay panics naming the field; pack failures are `PackError` values.

## Risks & Mitigation

**Risk 1: Public API change**
- *Risk*: `SchemeItem::times` changes signature (adds `Vec<E>` accessors and an element type). The old scalar form never worked beyond count 1 and has no users in the repo.
- *Mitigation*: change it before the `v0.2.0` tag; list it in the README Rust section and the changelog.

**Risk 2: Element ids vs parent ids**
- *Risk*: element binders use ids that continue the parent numbering but live on `E`, which can confuse the order check that today threads one `next_id`.
- *Mitigation*: AC-1/AC-5 pin the numbering; reuse the parent's next id for the first element item, then resume the parent after the element.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Loop 12 (AZ-2133 discovery, Rust map): a `repeat` / `times` inside a `list` / `dict` group element builds but does not work — the map walker passes a group element only its own name: `list("L", group(0,"g",[repeat(0,[u8 "0"])]))` with `L=[1]` packs `010100` (item ignored), unpack fails `Short`; a `times` in a dict group element fails pack `Missing`. Refuse a non-empty group as a map element or fix it with the per-round rows here | coordinator | open | Medium |
| Public API change: `SchemeItem::times(anchor, count_id, members)` → a form with `Vec<E>` get/set and element items for `E` (exact name/signature chosen by the implementer, documented in README) | user decision 2026-10-05 ("fix it") | resolved | Medium |
| Typed `repeat`, `u2`, flag byte and generic list/dict remain unbindable in Rust | C18 (undecided) | open | Medium |
| `times` nested in a `times` element is refused at construction (no AC requires it) | refactor owner | accepted-risk | Low |
