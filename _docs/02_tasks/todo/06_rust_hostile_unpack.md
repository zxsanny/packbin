# Rust unpack never hangs on hostile packets

**Task**: 06_rust_hostile_unpack
**Name**: Rust hostile-packet unpack
**Description**: A `repeat` round that reads 0 bytes ends the repeat, and the bytes left become the trailing-bytes error. A `when`, count or flag bit inside `repeat`/`times` that names a field outside that container is a construction error, as in C++. Rust runs the shared hostile vectors (`fixtures/hostile/cases.txt`).
**Complexity**: 2 points
**Dependencies**: 01_hostile_vectors
**Component**: rust
**Tracker**: pending
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C03, C04; discovery `scan_rust_cpp.md` LB1, C1; probe R-P5.

1. **Reference to an outer field inside a container is accepted.**
   - `rust/src/field/order.rs:36-42` (`require_walked`) only checks that the referenced id is lower than the next id. It does not check that the id lives in the same container scope.
   - At run time the walker evaluates the reference against the container's own values, so an outer field is never visible:
     - repeat groups: `rust/src/walk/unpack.rs:171-185` (a fresh `Values` per group);
     - times rounds: `rust/src/walk/unpack.rs:287-327`;
     - pack side: `rust/src/walk/pack.rs:222-233` (the group's `Values`) and `:298-309` (`slice_times`).
   - Result: the `when` never matches, and a count named that way is always "missing".
2. **A repeat round that reads 0 bytes loops forever.**
   - `rust/src/walk/unpack.rs:172` runs `while cur.left() > 0 { unpack_fields(...); groups.push(group) }` and never checks that the cursor moved.
   - Any repeat body that can read 0 bytes spins while memory grows by one `Values` per round. Two such bodies:
     - an empty `repeat(…, vec![])`;
     - a body whose only member is a `when` on an outer field (item 1).
   - `times` with the same body loops `count` times. The count is read from the packet and can be up to 2⁶⁴ (a u64 count field), which is effectively a hang.
3. **Reproduction (R-P5, map walker, cargo 1.79 debug).**
   - Scheme: `MapScheme::new(1, vec![u8("0"), repeat(1, vec![when(1, eq("0", Value::U8(1)), vec![u8("1")])])])`.
   - Construction succeeds. `unpack(&s, &[0x01, 0x01, 0x09])` does not return within 3 s, and memory grows without bound.
   - The same shape is reachable through the public typed API:
     `Scheme::new(1, [BoundField::u8(0, …).into(), SchemeItem::Field(repeat(1, vec![when(1, eq(0, Value::U8(1)), vec![u8("1")])]))])`, then `BinaryPacker::unpack_with(&[0x01, 0x01, 0x09], …)`.
4. **Cross-language comparison.**
   - C++ resolves every `when`/count/flag-bit reference only inside the enclosing container (`cpp/include/packbin/order.hpp:96-126`, `resolve` scope argument at `:166`).
   - The same scheme in C++ is `SchemeInvalid` with field id 1 (probe C-P4).
   - The project rule (list-of-changes C04): a reference must name an earlier field in the same scope.
5. **Other hostile cases already return errors in Rust today.** No panic was found for:
   - negative count (`as_usize` → `None`);
   - oversize count (`Cursor::take` short);
   - invalid UTF-8 (`unpack.rs:332`);
   - count behind a clear flag bit (count absent).

   They are mapped to `UnpackError::Short { needed: 0 }`. The label is decided later (C15); this task only guarantees "error value, no panic, no hang".

## Outcome

- No packet makes Rust unpack loop without progress. Every `unpack` case in `fixtures/hostile/cases.txt` returns an `Err` within 1 s, and every `construct` case owned by this task is refused at construction.
- A scheme whose container references a field outside that container cannot be built, matching C++.
- Existing tests, the golden hex and the route fixture stay byte-identical.

## Scope

### Included
- Scope-aware reference check at construction for `when`, `sized`, `bits`, `packed`, `times` counts and flag bits inside `repeat` / `times`. Covers both the map layout check and the typed `Scheme::new`.
- A run-time guard: a `repeat` round that consumes 0 bytes ends the repeat. That round's partial group is dropped, and the bytes left give `UnpackError::Trailing` (vector outcome `trailing_bytes`).
- A Rust test reads `fixtures/hostile/cases.txt` by path (like `rust/src/packbin_tests.rs:68` reads `golden.hex`) and writes each case's scheme by hand from `fixtures/hostile/README.md` (ADR-001: the file holds no schemes).
  - In this task it covers every `unpack` case, plus `when_names_later_field`, `count_names_later_field` and `when_names_outer_field_in_repeat`.
  - The cases `nine_flag_bits`, `nine_flag_bits_split`, `bool_outside_flags` and `empty_group_outside_flags` are added by task 13, which fixes them.
- Replay first: run each case on the current tree and record what happens before fixing (task 01 "Hex provenance"). Correct `cases.txt` if a derived hex does not reproduce.

### Excluded
- Error kind names and labels (C15, undecided).
- `list`/`dict` element scopes. They already start at 0 and cannot see the parent.
- Flag-bit numbering and the 8-bit limit (task 13). Typed-scheme fixes (tasks 16, 17).

## Acceptance Criteria

**AC-1: Outer `when` inside a container is refused**
Given a scheme `u8(0)`, `repeat(1, [when(1, eq(0, 1), [u8(1)])])` (map or typed form)
When it is constructed
Then construction fails. The message names field id 0 and says it is not in the same scope. Schemes built: 0.

**AC-2: Outer count inside `times` is refused**
Given `u8(0)`, `u8(1)`, `times(2, 0, [u8(2), sized(3, 1)])`, where `sized` names id 1 from outside the `times`
When it is constructed
Then construction fails naming id 1.

**AC-3: Same-scope references still build**
Given the route scheme in `rust/src/borrowed_count_tests.rs` and `repeat(1, [u8(1), when(2, eq(1, 1), [u8(2)])])`
When they are constructed and the route is packed and unpacked
Then construction succeeds and the route bytes equal `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`.

**AC-4: Zero-progress repeat ends with an error**
Given `MapScheme::new(1, vec![u8("0"), repeat(1, vec![])])` and the bytes `01 05 09`
When it is unpacked
Then unpack returns `Err(UnpackError::Trailing { left: 2 })` within 1 s. No value is returned and no panic occurs.

**AC-5: Hostile vectors**
Given the cases in `fixtures/hostile/cases.txt`
When the Rust suite builds each case's scheme and, for `unpack` cases, unpacks its hex
Then each case gives an outcome its `expected` column allows. Until C15, any `Err` that is not a panic is accepted, and the test name records the Rust variant returned. Every case finishes within 1 s, with 0 panics.

## Non-Functional Requirements

**Performance**
- AC-10 (100 000 position round trips ≤ 1 s) still passes. The progress check is one integer compare per repeat round.

**Reliability**
- Unpack of any byte string terminates: the work is bounded by the input length for `repeat` and by input length × body width for `times`.

## Unit Tests

Add these first; they must fail (or time out) on the current tree.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `#[should_panic]` build of the R-P5 scheme (map) and of the typed `SchemeItem::Field(repeat(…when…))` form | panics with "field id 0" (today: builds) |
| AC-2 | `#[should_panic]` build of `times` whose `sized` names an outer id | panics naming id 1 (today: builds) |
| AC-3 | existing `route_matches_fixture_and_rejects_a_short_tail`, `times_stops_so_the_next_field_is_read`, `repeat_groups_and_leftover` | unchanged, green |
| AC-4 | unpack of an empty `repeat` with bytes `01 05 09`, run on a thread with a 1 s `recv_timeout` | `Err(Trailing { left: 2 })` (today: timeout) |
| AC-4 | `repeat` round with a real body and 1 leftover byte (AC-7 of the project) | still `Short` naming the field, needed and left |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4, AC-5 | `zero_progress_repeat_bool` `01ff` (repeat of a lone bool; before task 13 the bool builds) | unpack | today: hang. After: `Trailing { left: 1 }` (`trailing_bytes`); after task 13: construction panic (`scheme_error`) | Reliability |
| AC-1, AC-5 | `zero_progress_repeat_when` `0100ff` and `when_names_outer_field_in_repeat` | build | construction panic naming id 0 (`scheme_error`). Today: builds, then unpack hangs | Reliability |
| AC-5 | `negative_count` `01ff61` (`i8` n = −1, `sized`) | unpack | `Err(Short)` today (`as_usize` → None), no panic | Reliability |
| AC-5 | `oversize_count` `01ffffffff61`, `oversize_count_times` `01ffffffff00`, `oversize_list_count` `01ffff` | unpack | `Err(Short)`. Each returns < 1 s; no allocation sized by the count (the list path uses `Vec::with_capacity(count)` ≤ 65535, so acceptable) | Reliability |
| AC-5 | `invalid_utf8` `010200c328`, `invalid_utf8_dict_key` `0101000100ff00` | unpack | `Err(Short)` today (label → C15), no panic | — |
| AC-5 | `count_behind_clear_flag` `0100`, `count_behind_clear_flag_bits` `0100` | unpack | `Err(Short { needed: 0 })` today, no panic | — |
| AC-5 | `when_names_later_field`, `count_names_later_field` | build | construction panic (already today, `order.rs:36-42`) | — |
| AC-3 | `fixtures/golden.hex` position row; route hex | pack and unpack | byte-identical | AC-10 |

## Constraints

- ADR-001: Rust keeps its own walker and order check. No code is shared with C++ or any other package. The C++ scope rule is the specification, not a dependency.
- Wire bytes unchanged. Only schemes that could never round-trip become construction errors.
- Construction failures stay panics with a message naming the field id, as the existing order errors are (scheme-field-order AC-4).

## Risks & Mitigation

**Risk 1: A caller relies on an outer reference inside `repeat`**
- *Risk*: such a scheme built before but never worked. It now fails at construction.
- *Mitigation*: the panic message names the id and the rule. The README "When" section already says the tested field must have been read.

**Risk 2: The hostile vector shape differs from these examples**
- *Risk*: task 01 picks a different zero-progress shape.
- *Mitigation*: the guard is shape-independent (bytes consumed per round). AC-5 accepts a construction error only where the vector says so.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Rust maps hostile cases to `UnpackError::Short { needed: 0 }`. Vector error-kind labels cannot be asserted until C15 decides labels | user (C15) | open | Medium |
| Building a previously accepted scheme now panics (outer reference). Behavior change on a public constructor, but those schemes never round-tripped | refactor owner | accepted-risk | Low |
