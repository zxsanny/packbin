# Rust typed schemes: unique binder names, numeric `when`, unsupported children refused

**Task**: AZ-2085_rust_typed_scheme_integrity
**Name**: Rust typed-scheme integrity
**Description**: Two bound lists or dicts in one scheme no longer overwrite each other. `when` matches by number whatever the integer width. List/dict elements and nested repeats that the walker cannot carry fail at construction instead of losing data.
**Complexity**: 3 points
**Dependencies**: AZ-2082_rust_flag_bits_bool (same order check), AZ-2075_rust_hostile_unpack
**Component**: rust
**Tracker**: AZ-2085
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C07 (parts 1, 3, 4); discovery `scan_rust_cpp.md` LB3, LB5, LB9, C3, C5, C21; probes R-P1, R-P3, R-P10, R-P11.

### Defect 1: bound lists and dicts share one internal name (silent corruption)

The container constructors hard-code the internal name:

| Constructor | Internal name | Where |
|-------------|---------------|-------|
| `list_utf8` | `"__list"` | `rust/src/scheme/bound.rs:393` |
| `dict_list_utf8` | `"__dict"` | `bound.rs:418` |
| `dict_list_dict_utf8` | `"__dict"` | `bound.rs:460-462` |
| `list_u16` | `"__list_{element_id}"` | `bound.rs:365`; `element_id` must be 0 (`rust/src/scheme/mod.rs:102-103` panics otherwise), so always `"__list_0"` |

- The typed pack copies each binder into one `HashMap` by name (`scheme/mod.rs:229-233`), so the second binder overwrites the first.
- Unpack hands the same value to both setters (`scheme/mod.rs:239-243`).
- **R-P1:**
  - scheme: `Scheme::new(1, [list_utf8(get a, set a), list_utf8(get b, set b)])`;
  - row: `a = ["x"]`, `b = ["yy", "zz"]`;
  - today's pack: `01 0200 0200 7979 0200 7a7a 0200 0200 7979 0200 7a7a`, so **b is written twice** and `a` is lost;
  - correct pack: `01 0100 0100 78 0200 0200 7979 0200 7a7a`.

### Defect 2: `when` compares `Value` variants

- `values_eq` (`rust/src/value.rs:133-157`) is true only for the same variant. It is used by pack (`rust/src/walk/pack.rs:215-219`) and unpack (`rust/src/walk/unpack.rs:165-169`).
- So `SchemeItem::when(4, eq(3, Value::U16(1)), …)` on field 3 bound as `BoundField::u8` never matches: the group is silently omitted on pack and skipped on unpack. There is no build error (found by inspection).
- `Groups` is never equal even to itself (`_ => false`).
- C++ compares the source integer as `int64` with `eq.value` (`cpp/src/core/values.cpp:86-89`) and accepts only integer or bool sources (`cpp/include/packbin/order.hpp:20-36`).

### Defect 3: composite children lose data silently

All in the map walker, which the typed scheme compiles to.

| Probe | Shape | Bytes | Behaviour today |
|-------|-------|-------|-----------------|
| R-P3 | `list("xs", flags(0, "f", [u8("a")]))` | unpack `01 0100 01 09` | `xs = [U8(1)]`: only the flag byte; member `a = 9` is lost. Pack of any row writes flag byte `00`, because `flag_member_on` (`pack.rs:133-140`) looks up `a` in a one-entry slice keyed by the flags name |
| R-P10 | `list("xs", group(0, "g", [u8("0"), u8("1")]))` | unpack `01 0100 04 05` | `Err(Short { field: "xs", needed: 0, left: 0 })`: the element is looked up by the group's name (`unpack.rs:344-364`) |
| R-P11 | `repeat(0, [u8("0"), repeat(1, [u8("1")])])` | pack `{0: 4, inner: [5]}` → `01 04 05`; unpack `01 04 05 06` | `{"0": 4}`: inner groups `5, 6` are discarded with `nested_groups` (`unpack.rs:175, 310`) |

- `u2` with more than one name as a list element carries only the first name (`field_name`, `rust/src/field/mod.rs:490`).
- `sized`/`bits`/`packed` as elements need a count that does not exist in the element scope, so they always fail at run time.
- The strings-lists-dicts restriction lets elements be "any existing field". C++ accepts bound elements only of scalar, `View`/`Text`, `Array` (nested list) and `Entry` (nested dict) shape (`cpp/include/packbin/table.hpp:333-363`) and marks others invalid at construction.

## Outcome

- Any number of bound lists/dicts in one typed scheme pack and unpack their own members.
- `when` matches on the integer value of its source field, whatever the width or signedness of `eq`'s value. A `when` on a non-integer source fails at construction.
- Shapes the Rust walker cannot carry are refused at construction with a message naming the field. No silent loss remains for list/dict elements or nested repeats.

## Scope

### Included
- Unique internal names for every bound list/dict, assigned when the typed scheme is compiled.
- Numeric `when` comparison. A construction error when the tested field or `eq`'s value is not an integer (bool presence counts as integer 0/1).
- Construction errors for:
  - list/dict elements other than integer, float, `bytes(n)`, `utf8`, `list`, `dict` (single-value kinds), and `u2` with more than one name;
  - `repeat` nested inside `repeat`, `times`, `list` or `dict`.

### Excluded
- `flags`/`when`/`group` inside `times` (task 17 makes `times` element rows). Generic typed list/dict element binding (C18 parity, undecided). Removing `list_u16`'s `element_id` parameter (public API, C18). Error labels (C15).

## Acceptance Criteria

**AC-1: Two bound lists**
Given `Scheme::new(1, [list_utf8(a), list_utf8(b)])` with `a = ["x"]`, `b = ["yy", "zz"]`
When packed and unpacked through `unpack_with`
Then the bytes are `01 0100 0100 78 0200 0200 7979 0200 7a7a`, and the row comes back with `a = ["x"]`, `b = ["yy", "zz"]`.

**AC-2: Two bound dicts and two `list_u16`**
Given two `dict_list_utf8` members (different maps), and separately two `list_u16` members
When packed and unpacked
Then each member round-trips with its own content.

**AC-3: F-AC-1 user row unchanged**
Given the user row in `rust/tests/scheme_tests.rs` (`username`, `roles`, `access`)
When packed
Then the bytes equal the 103-byte F-AC-1 hex.

**AC-4: `when` by number**
Given the marker scheme of `rust/tests/field_id_tests.rs` with `eq(3, Value::U16(1))` (and with `Value::I64(1)`) on the `u8` field 3, and `kind = 1, kind_id = Some(7)`
When packed and unpacked
Then the bytes equal those of the `Value::U8(1)` form, and `kind_id` round-trips.

**AC-5: Non-integer `when` refused**
Given a `when` whose tested field is `f32`/`utf8`, or whose `eq` value is `F32`/`Str`
When constructed
Then construction fails naming the tested id.

**AC-6: Uncarriable children refused**
Given each shape from R-P3, R-P10, R-P11, `list(u2([a, b]))` and `list(sized(…))`
When constructed
Then construction fails naming the list/dict/repeat. `list(list(u8))`, `dict(list(utf8))`, `dict(list(dict(utf8)))` and `list(be(u16))` still build and round-trip (F-AC-5, F-AC-6).

## Non-Functional Requirements

**Compatibility**
- No byte changes for schemes that worked. F-AC-1…F-AC-10 vectors and the golden hex are unchanged.

**Performance**
- AC-10 holds. Name assignment and checks happen at construction only.

## Unit Tests

Add these first; AC-1, AC-2, AC-4, AC-5 and AC-6 fail today.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | R-P1 scheme pack | `01010001007802000200797902007a7a` (today: b written twice) |
| AC-1 | R-P1 unpack | `a`, `b` distinct |
| AC-2 | two `dict_list_utf8`; two `list_u16` | each round-trips |
| AC-4 | marker scheme with `eq(3, U16(1))`, `eq(3, I64(1))` | same bytes as `U8(1)` |
| AC-5 | `#[should_panic]` when on `f32` source / `F32` eq | construction panic |
| AC-6 | `#[should_panic]` R-P3, R-P10, R-P11 shapes | construction panic (today: silent loss) |
| AC-3, AC-6 | existing `counted_list`, `dictionary_field`, `user_handler_reads_first_byte` | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | language-pair `user` and `nested` rows (`.github/workflows/drivers/handoff-rust`) | Rust ↔ C#/TS/Python/Java/C++ | 0 mismatched bytes | AC-3 (project), F-AC-1 |
| AC-6 | `fixtures/hostile/cases.txt` `invalid_utf8` (`010200c328`) through a typed `utf8` field and `oversize_list_count` (`01ffff`) through a typed `list_utf8` | `unpack_with` | `Err`, no panic, < 1 s | Reliability |
| AC-6 | `invalid_utf8_dict_key` (`0101000100ff00`) through a typed `dict_list_utf8` scheme (key `ff` invalid) | `unpack_with` | `Err`, no panic | Reliability |
| AC-4 | route fixture `3410…1101` (`when` on bool `straight`) | map pack/unpack | byte-identical | — |

## Constraints

- ADR-001: Rust's own walker; the C++ element rule is the reference, not shared code.
- No public signature changes in this task. Internal names stay private and are never on the wire.
- Construction failures are panics naming the field (existing convention).

## Risks & Mitigation

**Risk 1: Narrowing "elements may be any field"**
- *Risk*: refusing composite elements narrows the strings-lists-dicts restriction for Rust.
- *Mitigation*: those shapes lose data today, so refusing them is strictly safer. Full support is C18 (decision pending). Record the gap in the Rust component doc.

**Risk 2: Numeric compare of u64 above i64::MAX**
- *Risk*: u64 values above `i64::MAX` do not fit an `int64` compare.
- *Mitigation*: compare in a type that holds both u64 and i64 (e.g. i128), and test `u64::MAX`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Composite list/dict elements become construction errors in Rust while other packages may carry them | C18 parity (user, undecided) | open | Medium |
| `list_u16(…, element_id)` keeps a parameter that must be 0; removing it is a public API change | C18 / C13 | open | Low |
| `when` on a non-integer source was accepted before (never matched usefully); now panics at construction | refactor owner | accepted-risk | Low |
