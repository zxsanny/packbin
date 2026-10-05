---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ unpack keeps flag-byte values per scope

**Task**: AZ-2078_cpp_flag_byte_scope
**Name**: C++ flag-byte scope
**Description**: Unpack reads each `flag_bit` against the flag byte it was bound to at construction, so a container that reuses a flag-byte number no longer corrupts the outer bits. A `repeat` round that reads 0 bytes ends the repeat (bytes left → `TrailingBytes`). The host suite runs the shared hostile vectors.
**Complexity**: 2 points
**Dependencies**: AZ-2070_hostile_vectors
**Component**: cpp
**Tracker**: AZ-2078
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C05 (C++ part), C03 (C++ part); discovery `scan_rust_cpp.md` LB6, C6; probes C-P1, C-P3.

### Defect 1: pack and unpack disagree on which flag byte a bit belongs to

- **Construction** binds each `flag_bit` to one flag-byte table entry. `resolve` (`cpp/include/packbin/order.hpp:138-156`) stores the index in `Field::ref`. `find_flag_byte` (`order.hpp:112-126`) searches only the enclosing container scope and skips whole containers that end before the bit.
- **Pack** follows that binding. `pack_flag_byte` (`cpp/src/core/pack.cpp:74-83`) sets bit `t[j].bit` only for bits whose `ref == i`.
- **Unpack** forgets it:
  - `Walk::flag_bytes[8]` (`cpp/src/core/unpack.cpp:16`) keeps one value per flag-byte **number**;
  - `Kind::FlagByte` stores into `flag_bytes[f.size]` (`unpack.cpp:232`);
  - `Kind::FlagBit` reads `flag_bytes[w.t[f.ref].size]` (`unpack.cpp:234`).
- **Effect.** A `flag_byte(0)` inside a container's items overwrites the outer `flag_byte(0)` slot, so an outer `flag_bit(0, …)` after the container reads the last item's byte.

**Reproduction (probe C-P1, Apple clang 21, `-fno-exceptions -fno-rtti`).** Types, scheme and row:

```
struct It1 { Opt<std::uint8_t> x; };
struct R1  { std::uint8_t n; Array<It1, 4> items; Opt<std::uint16_t> tail; };
scheme<R1>(1, u8<&R1::n>(0), flag_byte(0),
           times<&R1::items>(1, 0, flag_byte(0), flag_bit(0, u8<&It1::x>(1))),
           flag_bit(0, u16<&R1::tail>(2)));
row: n = 1, items.count = 1 (x absent), tail = 0x0302
```

- `pack` → Ok, 6 bytes `01 01 01 00 02 03` (type, n, outer flag byte with bit 0, item flag byte 0, tail LE).
- `unpack` of those bytes → `TrailingBytes`, offset 4, field −1, `tail.has = 0`. The core cannot read its own packet.

### Defect 2: a repeat round that reads 0 bytes never ends when the repeat is unbound

- `unpack_items` (`unpack.cpp:186-213`) loops `while w.r.pos < w.r.len` for a `repeat` without checking progress.
- **C-P3:** `scheme<R>(1, u8<&R::k>(0), repeat(1))` (unbound, no children) builds with status Ok; unpack of `01 05 09` never returns (inspection of the loop; the probe did not run it).
- The bound form `repeat<&R::items>(1)` with `Array<E, 4>` stops only through `TooMany`: offset 2, field 1, `count = 4`, i.e. 4 phantom items.
- Hostile case `zero_progress_repeat_bool` (`01ff`, a repeat of a lone `boolean`) has the same shape. Task 12 makes that scheme invalid; this guard covers what remains (an empty body).
- Rust (task 06) and the other packages use the same rule. The vector outcome is `trailing_bytes`.

### Hostile vectors

- The C++ suite does not run `fixtures/hostile/cases.txt` yet.
- Task 01 decided: C++ **host** tests read the file; the QEMU vector runner stays as it is (firmware cannot read files).

## Outcome

- Every packet the core packs unpacks to the same row, including schemes where a container reuses a flag-byte number.
- No unpack loops without progress.
- Every hostile case gives an outcome its `expected` column allows, or the documented C++ exception (Flagged concerns).
- Embedded runner counts, flash and stack budgets still pass.

## Scope

### Included
- Unpack reads each flag bit from the flag byte it is bound to. A byte read inside a container's items does not change what the outer scope sees after the container.
- A `repeat` round that consumes 0 bytes ends the repeat, bound or unbound. The round adds no item, and `finish` reports the bytes left as `TrailingBytes`.
- C-P1, its mirror (AC-2) and the zero-progress cases as vectors in `VECTOR_TESTS` files (`grouped_tests.cpp`, `container_tests.cpp`). They run on the host and on QEMU.
- A host-only test (in `HOST_TESTS`, e.g. `host_tests.cpp`) that reads `fixtures/hostile/cases.txt`, builds each case's scheme by hand from `fixtures/hostile/README.md`, and checks the outcome. It runs each case under a watchdog thread (1 s).
  - Rule: C++ count sources must be bound members (`order.hpp:104`), so the hand-written schemes bind every count.
  - Replay each case on the current tree first (task 01 "Hex provenance").

### Excluded
- `boolean`/empty group placement and the `u2` limit (task 12), whose construct cases `bool_outside_flags` and `empty_group_outside_flags` task 12 adds to the runner. UTF-8 validation in the core (Flagged concerns). Error labels (C15). Moving internals out of the public namespace (C13).

## Acceptance Criteria

**AC-1: Reused flag-byte number round-trips**
Given the C-P1 scheme and row
When the row is packed and the bytes unpacked
Then pack writes `01 01 01 00 02 03`, and unpack returns Ok with offset 6, `tail.has = 1`, `tail = 0x0302`, `items.count = 1`, `items[0].x.has = 0`.

**AC-2: Inner bits still read their own byte**
Given the same scheme with `items[0].x = 7` and `tail` absent
When packed and unpacked
Then the bytes are `01 01 00 01 07`, and the row round-trips (x present, tail absent).

**AC-3: Zero-progress repeat**
Given `scheme<R>(1, u8<&R::k>(0), repeat(1))` (unbound) and `repeat<&R::items>(1)` (bound), with bytes `01 05 09`
When unpacked
Then both return `TrailingBytes` at offset 2. The call returns, and the bound array's count is 0.

**AC-4: Hostile vectors on the host**
Given each case of `fixtures/hostile/cases.txt`
When the host runner builds and (for `unpack` cases) unpacks it
Then the outcome is one its `expected` column allows (proposed C++ results below), each case finishes within 1 s, and 0 bytes are written outside the row.

| Case | C++ result |
|------|-----------|
| `zero_progress_repeat_bool` | `TrailingBytes` (this task); `SchemeInvalid` after task 12 |
| `zero_progress_repeat_when`, `when_names_outer_field_in_repeat` | `SchemeInvalid` (already, C-P4) |
| `negative_count`, `count_behind_clear_flag`, `count_behind_clear_flag_bits` | `BadValue` (`unpack.cpp:52-55, 72-79`) |
| `oversize_count` | `ShortPacket` |
| `oversize_count_times` | `TooMany` with a bound `Array` (`unpack.cpp:177-180`), `ShortPacket` unbound |
| `oversize_list_count` | `TooMany` (bound `Array<u8, N>`, allowed) |
| `invalid_utf8`, `invalid_utf8_dict_key` | Ok today (see Flagged concerns) |
| `nine_flag_bits`, `nine_flag_bits_split`, `when_names_later_field`, `count_names_later_field` | `SchemeInvalid` (already) |

**AC-5: Embedded profile and budgets hold**
Given the embedded job (`cpp/embedded`)
When it runs
Then the following all hold:
- `VECTORS_RUN` equals the `expect(` count per `VECTOR_TESTS` file;
- the Cortex-M4F core plus the 14-field table is ≤ 8192 B flash;
- the deepest pack/unpack is ≤ 512 B stack;
- 0 B `.data`/`.bss`;
- 0 `malloc`/`new`/`__cxa_*` references;
- 0 mismatches on the big-endian host.

## Non-Functional Requirements

**Performance**
- Host AC-10 (100 000 position round trips ≤ 1 s; baseline 13 ms) holds.

**Compatibility**
- No wire byte changes. Every existing hex vector, `fixtures/golden.hex` and the language pairs are unchanged.

**Reliability**
- Unpack terminates on any input: repeat rounds ≤ input length.

## Unit Tests

Add these first; AC-1 and AC-3 fail (or hang) today.

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | C-P1 scheme pack + unpack | Ok, row equal (today: `TrailingBytes` at 4) |
| AC-2 | inner bit set, outer clear | `01 01 00 01 07`, round-trip |
| AC-3 | unbound empty `repeat`, `01 05 09` | `TrailingBytes` at 2 (today: no return) |
| AC-3 | bound empty `repeat` | `TrailingBytes`, count 0 (today: `TooMany`, count 4) |
| — | existing grouped/container vectors (motion split form, route) | unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | `fixtures/hostile/cases.txt`, all 17 ids (the 2 placement cases join with task 12) | host runner | table in AC-4; < 1 s each; no write past `offset` | Reliability |
| AC-5 | QEMU `mps2-an385` vector runner, M4F size/stack report, big-endian s390x | embedded job | runs == asserted, ≤ 8192 B flash, ≤ 512 B stack, 0 mismatches | AC-5 (feature) |
| AC-1 | language-pair e2e and golden row | pack/unpack | unchanged bytes | AC-3 (project) |

## Constraints

- **Embedded profile** (restrictions § Embedded profile):
  - no heap, no exceptions, no RTTI;
  - allowed headers only: `<cstdint> <cstddef> <cstring> <type_traits> <limits> <array> <utility>`;
  - no static mutable state; reentrant.
  Any per-scope flag-byte state lives on the walk's stack, within the 512 B budget. File reading and threads stay in `HOST_TESTS` only.
- ADR-001: the C++ walker stays its own; schemes in the hostile runner are written by hand.
- Every `expect(` in a `VECTOR_TESTS` file must run on the firmware (no host-only branch inside those files), or the runs == asserted check fails.

## Risks & Mitigation

**Risk 1: Stack budget**
- *Risk*: per-scope flag-byte state adds stack to the recursive `unpack_one` / `unpack_items`.
- *Mitigation*: keep it ≤ 8 B per container level, out of the leaf helpers. Check the `-fstack-usage` row before merging.

**Risk 2: Vector count drift**
- *Risk*: new vectors change the `expect(` counts.
- *Mitigation*: the runner compares counts per file automatically. The hostile runner is host-only and does not affect the counts.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The core does not validate UTF-8 (zero-copy `View`), so `invalid_utf8` / `invalid_utf8_dict_key` unpack Ok in C++ while the vector expects `bad_value\|short_packet`. Choose: validate in the core (measure flash against 8192 B), or mark C++ "borrowed, unchecked" in `cases.txt` and the README | user | open | Medium |
| `oversize_count_times` expects `short_packet` only. C++ with a bound `Array` returns `TooMany` before reading (capacity first). Propose `short_packet\|too_many` in `cases.txt`, as `oversize_list_count` already has | task 01 owner | open | Low |
| The zero-progress guard and hostile runner are added here; the plan row names only the flag-byte fix. They share the `unpack_items` loop. Split into a separate C++ task if preferred | coordinator | open | Low |
| Error labels for hostile cases depend on C15 | user (C15) | open | Low |
