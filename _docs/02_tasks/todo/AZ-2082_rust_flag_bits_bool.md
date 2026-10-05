---
loop: 12
---

# Rust flag bits from field order, 8-bit limit, `bool` only inside flags

**Task**: AZ-2082_rust_flag_bits_bool
**Name**: Rust flag bits and bool rule
**Description**: Flag-bit positions come from the order of the fields, not from a counter shared on the `FlagByte` handle. A 9th member or bit is a construction error. A bool (empty group) is accepted only inside `flags` or under a flag-byte bit, and unpacks there correctly.
**Complexity**: 2 points
**Dependencies**: AZ-2075_rust_hostile_unpack (same order check in `rust/src/field/order.rs`)
**Component**: rust
**Tracker**: AZ-2082
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C01, C02, C05 (Rust parts); discovery `scan_rust_cpp.md` LB2, LB8, C2, C14; probes R-P2, R-P8, R-P13.

### User decision (2026-10-05, verbatim)

> The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error.

In Rust a bool is `BoundField::bool_flag` (an empty `group`, `rust/src/scheme/bound.rs:338-357`), or a map `group(id, name, vec![])`.

### Defect 1: bit numbers come from a shared counter

- `FlagByte::bit` (`rust/src/field/mod.rs:140-155`) takes the next value of `next_bit: Rc<RefCell<u8>>` (`:120-123`). The bit number therefore depends on how many `.bit()` calls were made on that handle, across all schemes.
- **R-P13:** `let m = flag_byte("m");` then two schemes `[m.byte(), m.bit(u8("x"))]` with `x = 5`:
  - the first packs `01 01 05`;
  - the second packs `01 02 05` — the same field list, different bytes.
- The C++ rule: a bit's position is its order among the bits of that flag byte in the table (`cpp/include/packbin/order.hpp:129-136` `bit_position`).

### Defect 2: no 8-bit limit

- Neither `check_order` (`rust/src/field/order.rs:76-81`) nor `FlagByte::bit` (`saturating_add`, `field/mod.rs:144`) limits members/bits to 8.
- Pack shifts a `u8` by the member index (`rust/src/walk/pack.rs:182,187`) or bit number (`:97,204`); unpack does the same (`rust/src/walk/unpack.rs:128,155`).
- **R-P2:** `flags(0, "f", [u8("0") … u8("8")])` (9 members) with only `"8" = 7`:
  - debug: panic `attempt to shift left with overflow` at `pack.rs:182`;
  - `--release`: the shift wraps to bit 0 and pack returns `Err(Missing("0"))`. With member `"0"` present it would write member 0 instead of 8.
- **R-P8:** a `flag_byte` with 9 `.bit()` fields, only `x8 = 3`: debug panic at `pack.rs:97`; release `Err(Missing("x0"))`.
- C++ and Java reject both at construction (`cpp/tests/compile-fail/flags_overflow.cpp`).

### Defect 3: bool placement and the flag-byte bool

- **Outside flags** (R-P13): `[group(0, "0", vec![]), u8("1")]` with `"0" = 1, "1" = 7`:
  - pack → `01 07` (the bool vanishes);
  - unpack → `{"1": 7}` (absent).
  - Construction accepts it. C++ unpacks the same shape as `true`, so the two packages disagree.
- **Under a flag-byte bit** (R-P13): `[f.byte(), f.bit(group(1, "1", vec![]))]` with `"1" = 1`:
  - pack → `01 01` (bit set);
  - unpack → `{"f": 1}`, with the bool **missing**.
  - Cause: only the `flags` branch inserts the presence marker for an empty group (`unpack.rs:130-137`); the `FlagBit` branch (`:153-158`) does not. C++ sets it (`unpack.cpp:237-241`).
- **Value rule:**
  - typed `bool_flag` already maps `Some(true)` → bit set and `Some(false)`/`None` → clear (`bound.rs:347-353`);
  - the map walker treats **any** present value as true (`pack.rs:111-114` `group_on`, `:96`), so a map value `U8(0)` sets the bit.

## Outcome

- One field list always packs the same bytes, however the `FlagByte` handle was used before.
- More than 8 bits per byte cannot be built; no shift-overflow panic is reachable.
- `bool` follows the decision in Rust: bit only for true, only inside `flags` / a flag byte, round-trips in both places, and is a construction error elsewhere.

## Scope

### Included
- Bit positions assigned at scheme construction from field order within the flag byte's scope. A `FlagByte` handle no longer carries mutable numbering state.
- Construction errors:
  - `flags` with more than 8 members;
  - a flag byte with more than 8 bits;
  - an empty group (typed `bool_flag` or map `group(…, vec![])`) whose parent is not `flags` or a flag-byte bit.
- The flag-byte-bit bool unpacks as present (true) when its bit is set.
- The map walker sets a bool bit only for a true value (`U8(1)`); `U8(0)` leaves it clear.
- Add the hostile `construct` cases `nine_flag_bits`, `nine_flag_bits_split`, `bool_outside_flags`, `empty_group_outside_flags` to the Rust hostile runner from task 06. `zero_progress_repeat_bool` moves from `trailing_bytes` to `scheme_error`.

### Excluded
- Non-empty `group` (unchanged). Typed flag-byte API (C18 parity, undecided). Error label kinds (C15).

## Acceptance Criteria

**AC-1: Bits from field order**
Given one `flag_byte("m")` handle used to build two schemes `[m.byte(), m.bit(u8("x"))]`
When both pack `x = 5`
Then both produce `01 01 05`.

**AC-2: Split-form golden unchanged**
Given the split-form tests (`split_flag_byte_and_be`), the motion schema.md example and the golden hex `4001000065cd1d00a3e1110100`
When packed
Then the bytes are unchanged.

**AC-3: Ninth member or bit refused**
Given `flags` with 9 members, or a `flag_byte` with 9 bits
When constructed
Then construction fails with a message naming the 9th field's id/name. 8 members/bits still build and round-trip.

**AC-4: Bool outside flags refused**
Given `[group(0, "0", vec![]), u8("1")]`, or a typed `BoundField::bool_flag(0, …)` at top level, or inside `when`/`times`/plain `group`
When constructed
Then construction fails naming id 0.

**AC-5: Bool inside flags and flag byte**
Given typed `SchemeItem::flags(0, [bool_flag(0), u8(1)])`, and map `[f.byte(), f.bit(group(1, "1", vec![]))]`
When packed with true and unpacked
Then:
- the flags scheme gives `01 03 07` for `true, n = 7` and `01 02 07` for `false, n = 7`;
- the flag-byte scheme gives `01 01`;
- unpack returns `Some(true)` for a set bit and `None` for a clear one.
Given the map value `U8(0)` for the bool
Then the bit stays clear.

## Non-Functional Requirements

**Compatibility**
- No byte changes for valid schemes. The only new failures are schemes that panicked, aliased bits, or lost the bool.

**Reliability**
- No reachable `attempt to shift left with overflow` on any scheme that constructs.

## Unit Tests

Add these first; they fail today.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | two schemes from one handle (R-P13) | both `010105` (today second is `010205`) |
| AC-3 | `#[should_panic]` 9-member flags, 9-bit flag byte | construction panic (today: builds, then shift panic in debug) |
| AC-3 | 8-member flags with member 7 present | bit 7 set, round-trip |
| AC-4 | `#[should_panic]` top-level empty group; typed `bool_flag` at top level | construction panic (today: builds) |
| AC-5 | flag-byte-bit bool pack/unpack | unpack contains the bool (today: missing) |
| AC-5 | map bool `U8(0)` under flags | bit clear (today: set) |
| AC-2 | existing `split_flag_byte_and_be`, `ac4_flags_and_stored_zero`, `empty_group_flag`, `field_id_ac3_flags_child_accessors` | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | cross-language bool vector (C01) | Rust typed pack/unpack | same hex as the other packages (`true` set, `false`/absent clear) | AC-3 (project) |
| AC-2 | `fixtures/golden.hex`, language-pair e2e (C# → Rust, Rust → TS, …) | pack/unpack | 0 mismatched bytes | AC-1, AC-3 |
| AC-3 | `fixtures/hostile/cases.txt` `nine_flag_bits` (flags with 9 `u8`), `nine_flag_bits_split` (flag byte + 9 bits), added to the Rust hostile runner from task 06 | build | construction panic (`scheme_error`); today: builds, then debug shift panic | Reliability |
| AC-4 | `bool_outside_flags` (id0 `u8 a`, id1 bool), `empty_group_outside_flags` (id0 `u8 a`, id1 empty group), `zero_progress_repeat_bool` `01ff` | build | construction panic (`scheme_error`); today: builds (bool silently absent / repeat ends `Trailing` after task 06) | — |
| AC-5 | `count_behind_clear_flag` `0100`, `count_behind_clear_flag_bits` `0100` | unpack | `Err`, no panic (unchanged by this task) | Reliability |

## Constraints

- ADR-001: Rust implements the rule in its own order check and walker.
- Construction failures stay panics with an id-naming message (existing scheme-field-order convention).
- Wire bytes unchanged except for the decided bool rule. The `U8(0)` map case is not reachable through the typed public API.

## Risks & Mitigation

**Risk 1: Callers rely on the handle counter**
- *Risk*: code that builds bits through helper functions may have depended on the shifted numbering.
- *Mitigation*: the shifted numbering never matched the other packages. AC-1/AC-2 pin the order-based result.

**Risk 2: Scope of a flag byte**
- *Risk*: bits inside `repeat`/`times` must bind to a flag byte in the same container (task 06 scope rule).
- *Mitigation*: reuse the scope rule from task 06; add one test with a flag byte inside `times`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `FlagByte::bit` keeps its signature, but `FlagByte` loses its interior counter. Not an API break, but `Clone` semantics change (no longer shares state) | refactor owner | accepted-risk | Low |
| Typed API has no flag-byte form; the flag-byte bool is reachable only through raw `SchemeItem::Field` | C18 parity (undecided) | open | Low |
