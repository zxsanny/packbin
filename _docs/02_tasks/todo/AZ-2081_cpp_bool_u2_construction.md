---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ `bool` only inside flags; `u2` limit at construction

**Task**: AZ-2081_cpp_bool_u2_construction
**Name**: C++ bool placement and u2 limit
**Description**: A `boolean` or empty `group` is accepted only as a child of `flags` or of a `flag_bit`. Elsewhere it is a scheme construction error. A `u2` with more than 64 children is also a construction error.
**Complexity**: 1 point
**Dependencies**: AZ-2078_cpp_flag_byte_scope (same test files and vector counts)
**Component**: cpp
**Tracker**: AZ-2081
**Epic**: AZ-2069

## Problem

Sources: list-of-changes C01 (C++ part), C13 (u2 part); discovery `scan_rust_cpp.md` LB7, C7, S21 row 24; probes C-P2, C-P5.

### User decision (2026-10-05, verbatim)

> The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error.

### Defect 1: a zero-width presence field outside flags always unpacks as `true`

- Pack writes nothing for `Kind::Bool` (`cpp/src/core/pack.cpp:217-218`).
- Unpack always calls `set_bool` for `Kind::Bool` (`cpp/src/core/unpack.cpp:220-222`) and for an empty `Group` (`unpack.cpp:237-241`), whatever the bytes are.
- `check_shape` (`cpp/include/packbin/order.hpp:170-181`) only rejects `flags` with more than 8 children and `flag::Invalid`. It does not check where a `Bool` or an empty `Group` sits.

**Reproduction (C-P2).** `struct R2 { bool b = false; std::uint8_t v = 0; }; scheme<R2>(1, boolean<&R2::b>(0), u8<&R2::v>(1))`:
- construction → Ok;
- unpack `01 07` → Ok, `b = true`, `v = 7`;
- pack `{b = false, v = 7}` → `01 07`.

`b` cannot round-trip. Rust leaves the same member absent (cross-language disagreement on one scheme, project AC-3).

### Current behaviour inside flags (already conforms, keep it)

`scheme<B>(1, flag_byte(0), flag_bit(0, boolean<&B::on>(0)))` with `Opt<bool> on`:

| Row | Pack | Unpack |
|-----|------|--------|
| `on = true` | `01 01` | `has = 1`, `value = 1` |
| `on = false` | `01 00` | — |

Same under `flags(…)` (`grouped_tests.cpp` Marker vectors, `values.cpp:10-18` `flag_on`).

### Defect 2: the `u2` cap is hidden and one-sided

- `pack_u2` copies into `std::uint8_t raw[16]` (`pack.cpp:155-157`), which caps `u2` at 64 children. A 65th child makes pack fail at run time.
- `unpack_u2` (`unpack.cpp:101-116`) has no cap and reads the same scheme happily.

**Reproduction (C-P5).** A `u2` of 65 unbound `u8` children:
- construction status Ok;
- `pack` → `BadValue`, offset 1, field 0;
- unpack of 18 bytes → Ok.

## Outcome

- The bool rule above holds in C++. Schemes that place a `boolean` or empty `group` anywhere else do not build: a compile error for `constexpr`, `SchemeInvalid` for runtime.
- `u2` children ≤ 64 is checked at construction; pack never reports it at run time.
- No change to any byte of a currently valid scheme.

## Scope

### Included
- Placement check for `Kind::Bool` and span-1 `Kind::Group`: the parent entry must be `Flags` or `FlagBit`.
- A `u2` builder with more than 64 children fails at construction.
- Compile-fail cases for both, next to `cpp/tests/compile-fail/flags_overflow.cpp` and wired into the `compile-fail` target.
- Vectors in `VECTOR_TESTS` for `true` / `false` / absent under `flags` and under a `flag_bit`.

### Excluded
- Non-empty `group` (a plain group outside flags stays valid). Rust and the other packages (tasks 10, 11, 13, 14, 20). The `u2` encoding itself.

## Acceptance Criteria

**AC-1: bool outside flags is refused**
Given `scheme<R2>(1, boolean<&R2::b>(0), u8<&R2::v>(1))`
When built as `constexpr`
Then compilation fails naming field id 0. When built at run time, `validate()` returns `SchemeInvalid` with field 0, and `pack`/`unpack` return that status with 0 bytes written.

**AC-2: empty group outside flags is refused**
Given `scheme<R>(1, group<&R::flag>(0), u8<&R::v>(1))`, or an empty group inside a plain `group`, `when`, `repeat`, `times` or `list`
When built
Then the same result as AC-1, naming the group's id.

**AC-3: bool inside flags / flag byte unchanged**
Given `flags(0, boolean<&M::on>(0), u8<&M::n>(1))` with `on = true, n = 7`; the same with `on = false`; and the flag-byte form `flag_byte(0), flag_bit(0, boolean<&B::on>(0))`
When packed and unpacked
Then:
- the `flags` scheme packs `01 03 07` (true) and `01 02 07` (false);
- the flag-byte scheme packs `01 01` (true) and `01 00` (false or absent);
- unpack gives `true` only when the bit is set (absent/false otherwise).

**AC-4: u2 over 64 children**
Given a `u2` with 65 `u8` children
When built
Then construction fails (compile error naming `u2`, or `SchemeInvalid`). A `u2` with exactly 64 children builds and round-trips 16 bytes.

**AC-5: Embedded runner and budgets**
Given the embedded job
When it runs
Then the following all hold:
- `VECTORS_RUN` equals the `expect(` count per `VECTOR_TESTS` file;
- the M4F core plus the 14-field table is ≤ 8192 B flash;
- stack is ≤ 512 B;
- every compile-fail case passes on host and in the container.

## Non-Functional Requirements

**Compatibility**
- Golden hex, the language-pair vectors and every existing C++ vector are unchanged. Only schemes that could not round-trip become invalid.

**Performance**
- The check runs at construction only (compile time for `constexpr`). No pack/unpack cost.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | runtime-built C-P2 scheme `status` | `SchemeInvalid`, field 0 (today: Ok) |
| AC-1 | compile-fail `bool_outside_flags.cpp` | error text matches `breaks_order<0>` |
| AC-2 | runtime empty `group<&R::flag>(0)` at top level and inside `group(…)` | `SchemeInvalid` |
| AC-3 | Marker vectors (`grouped_tests.cpp`) plus the flag-byte bool true/false/absent | unchanged bytes; unpack `has` only for a set bit |
| AC-4 | 65-child `u2` (generated with an index sequence) | `SchemeInvalid` (today: Ok, then pack `BadValue`) |
| AC-4 | 64-child `u2` | builds; pack 17 bytes incl. type; round-trip |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | cross-language bool vector (C01, added by task 01 or 10) | C++ pack / unpack | same hex as the other packages: `true` → bit set, `false`/absent → clear | AC-3 (project) |
| AC-1, AC-2 | `fixtures/hostile/cases.txt`: `bool_outside_flags` (id0 `u8 a`, id1 `bool on`) and `empty_group_outside_flags` (id0 `u8 a`, id1 empty `group`), added to the host hostile runner from task 09 | build | `SchemeInvalid` (`scheme_error`); today: Ok | — |
| AC-1 | `zero_progress_repeat_bool` `01ff` (repeat of a lone `boolean`) | build | `SchemeInvalid`; in task 09 it was `TrailingBytes` at unpack | Reliability |
| AC-5 | QEMU vector runner, big-endian host, size/stack report | embedded job | runs == asserted, ≤ 8192 B, ≤ 512 B | AC-5 (feature) |

## Constraints

- **Embedded profile:** no heap, no exceptions, no RTTI, allowed headers only. A `constexpr` scheme reports through the existing non-constexpr marker function (a compile error naming the id), a runtime scheme through `SchemeInvalid`. Never `throw` or `static_assert` on a runtime path.
- Wire bytes unchanged for valid schemes (decision: only true sets the bit — C++ already does).
- ADR-001: C++ implements the rule itself.

## Risks & Mitigation

**Risk 1: A shipped example uses `boolean` outside flags**
- *Risk*: README, `cpp/examples/*` or a test may place one at top level.
- *Mitigation*: grep `boolean<` / `group<` in `cpp/` and README. Today all uses are under `flags`.

**Risk 2: Compile-time cost**
- *Risk*: a parent lookup per entry in `check_shape`.
- *Mitigation*: the shape check already walks children once; the parent kind is known at that point.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Behaviour change: a scheme that built in 0.1.x/loop 10 now fails. 0.2.0 is already a breaking C++ release (D-2 B); add a README note | user decision 2026-10-05 | resolved | Low |
| The `u2` cap (64) becomes a documented limit. Other packages have no cap; the cross-language wire has none (`u2` byte count is fixed by the scheme) | coordinator | accepted-risk | Low |
