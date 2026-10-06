# Rust unpack refuses rounds above the scheme's limits

**Task**: AZ-2219_rust_round_limits
**Name**: Rust round and slot limits on unpack (map scheme and typed scheme)
**Description**: A Rust `MapScheme` and a typed `Scheme<T>` carry `max_rounds` and `max_slots` (defaults 65,535 and 4,194,304); an unpack that would create more rounds or slots, including typed `times` rows and a `times` inside a `repeat`, is refused with the interim bad-value error when the round that crosses a limit would start, and a caller can raise or lower the limits per scheme with `with_limits`.
**Complexity**: 3 points
**Dependencies**: None (the shared hostile case and the README are AZ-2220, which lands after this task)
**Component**: rust
**Tracker**: AZ-2219
**Epic**: AZ-2069

## Problem

Loop 15, finding F10 (`_docs/05_security/security_report.md`), owner option A, decisions D1 to D7 in `_docs/02_task_plans/unpack-limits-and-ci-hardening/problem.md`.

Unpack of a `repeat` or `times` round has no budget. Facts on the current code (`b45335d`):

- The `Repeat` arm of `unpack_one` (`walk/unpack.rs:174-193`) loops `while cur.left() > 0`; the `Times` arm (`:296-344`) loops a `usize` count. Every round builds a `Values` map; `times` then clones every value into per-name lists (`round_lists`, `walk/times.rs:6-16`) and keeps the rounds as `Value::Groups`. A round must read at least one byte, so rounds are bounded only by the bytes left.
- Cost (audit, README `README.md:1081`): a 1 MiB packet of one-byte rounds is about 311 MB peak, and about 1.4 GB when each round sets eight flag bits. A scratch run on the current code of a `repeat` whose round is a `flags` byte with eight bools, packet of 1,048,576 bytes `ff`, measured 1.01 GB resident. About 300 bytes per round whatever the names, so only a rounds limit bounds Rust; the slot limit is the same rule as in the other packages (D2).
- The only defence today is the README sentence "cap the packet length where you read it".
- The unpack entry points cannot take an extra argument: `pub fn unpack(scheme: &MapScheme, bytes)` (`walk/mod.rs:60`, defined `walk/unpack.rs:404-434`), `BinaryPacker::unpack_with(bytes, handlers)` (`scheme/mod.rs:266`) and the trait method `DispatchHandler::handle(&mut self, body)` (`scheme/mod.rs:237-252`). The typed `Scheme<T>` (`scheme/mod.rs:22-26`) holds a `layout: MapScheme` and unpacks with `walk::unpack(&scheme.layout, bytes)` (`:261-264`), so one limits pair on `MapScheme` serves both. So the limits live on the scheme (D1).
- `MapScheme` (`field/map_scheme.rs:3-10`) derives `Clone, Debug`; its constructor `MapScheme::new` panics on an invalid scheme (`:46-60`) and counts fields with `count_fields` (`:12-37`).
- `Cursor` (`walk/unpack.rs:9-32`) is created once per call in `unpack` (`:405`) and passed to every nested `unpack_one`, list and dict elements included: it is the per-call carrier.
- The typed `times` (`scheme/times.rs:43-60`) rebuilds one element per round with `build_row` (`scheme/mod.rs:104-112`) after the map walk; its rounds are the same `Values` rounds, so the walk limits cover it.
- A `times` inside a `repeat` round is allowed (`field/shape.rs:96-108`; `round_tests.rs:33-35` and `:135`); a `repeat` in a round and a `times` in a `times` round are refused at construction. A `list` or `dict` element cannot hold `times` or `repeat`.
- Error mechanism: `Result<_, UnpackError>`; a bad value is `UnpackError::Short(ShortPacket { field, needed: 0, left })`; the zero-width `times` round uses the field `"times"` (`walk/unpack.rs:331-337`); a zero-width `repeat` round is `Trailing` (`:188-190`). The enum has no `#[non_exhaustive]` and C15 (a real kind and label) is the owner's open decision, so no new variant: the refusal is `Short` with `needed` 0.
- The largest existing Rust use is 300 rounds; the full Rust suite passes with both defaults in a scratch prototype of this design (159 unit and all integration tests).

## Outcome

- `MapScheme` and `Scheme<T>` have `max_rounds()` (default 65,535) and `max_slots()` (default 4,194,304). `with_limits(max_rounds, max_slots)` returns a scheme with other values.
- An unpack that would start more than `max_rounds` rounds of one `repeat` or `times` field, or whose rounds together would hold more than `max_slots` slots (every round of a `times` inside a `repeat` counts), returns `Err(UnpackError::Short(ShortPacket { field, needed: 0, left }))`, the handler is not called, no row is visible.
- A refused 1 MiB packet costs memory bounded by the limits, not by the packet length (about 68 MB resident in the scratch run above, against 1.01 GB).
- A packet at or below the limits unpacks exactly as before. Pack, wire bytes and result shapes do not change.

## Public surface (the names the implementer must use)

- `pub const DEFAULT_MAX_ROUNDS: usize = 65_535` and `pub const DEFAULT_MAX_SLOTS: usize = 4_194_304`, exported from the crate root next to `NONCE_SIZE` and `SEED_SIZE`.
- `MapScheme::with_limits(self, max_rounds: usize, max_slots: usize) -> Self` and `Scheme<T>::with_limits(self, ...)` (consuming builders, the Rust idiom; `MapScheme` is `Clone`, so clone first to keep the original); `max_rounds(&self) -> usize` and `max_slots(&self) -> usize` on both. Both arguments are given; pass the constant to change only one.
- Construction error (D6): `max_rounds == 0` or `max_slots == 0` panics with a message naming `max_rounds` or `max_slots`, as `MapScheme::new` panics for an invalid scheme. No "unlimited" value: `usize::MAX` is valid.
- The doc comment of `walk::unpack` (`walk/mod.rs:42-59`) names the refusal.

## What is counted and when it is checked (D2, D5)

- Rounds: the rounds one `repeat` or `times` field starts in one walk of that field. A `times` inside a `repeat` round is walked once per outer round and counts afresh each time; its rounds also count toward the slot total.
- Slots: for each round started, `count_fields(members)` of that field (`field/map_scheme.rs:12-37`: `flags` and `group` count themselves plus their members, a `u2` counts each name, a nested `times` counts its members), added to one total shared by every field of the unpack call. Compute it once per field when the scheme is built, not per round.
- `repeat`: at the start of a round (only when bytes are left), refuse if the field has already started `max_rounds` rounds or if total slots + this round's count > `max_slots`.
- `times`: the same check at the start of each round: refuse the (`max_rounds` + 1)th round, or a round that would take total slots above `max_slots`. The count field is not refused up front (D5, lazy, 2026-10-06): a huge count whose packet ends early gives today's short read.
- `left` is `cur.left()` at the refusal (the packet includes the type byte).
- Label (D4): `"times"` for `times`, as the zero-width round; `"repeat"` for `repeat` (no label exists today for a `repeat` error).

## Scope

### Included
- `MapScheme` and `Scheme<T>`: the two limits, `with_limits`, getters, defaults, validation; the constants.
- The refusal in the `Repeat` and `Times` arms, the counters on `Cursor`.
- Typed `times` rows and a `times` inside a `repeat` (tests below).
- New tests (below); the doc comment.

### Excluded
- Pack, wire bytes, result shapes, session and dispatch behavior (D7); list and dict counts; `bits` and `packed`.
- A distinct error kind (C15), the README, the hostile case and the docs (AZ-2220).
- A limit on the memory of one typed element `E` (`size_of::<E>()` x rounds is bounded by `max_rounds` only).
- C++ and Python.

## Acceptance Criteria

**AC-1: Defaults and surface**
Given any `MapScheme` and typed `Scheme<T>` built as today, and `map.with_limits(10, DEFAULT_MAX_SLOTS)`
When `max_rounds()`, `max_slots()`, `DEFAULT_MAX_ROUNDS` and `DEFAULT_MAX_SLOTS` are read
Then the built ones have 65,535 and 4,194,304; the constants have those values; the last has 10 and 4,194,304; a typed `Scheme<T>` built with `with_limits(10, 20)` reports 10 and 20.

**AC-2: `repeat` at the default limit**
Given `MapScheme::new(1, vec![repeat(0, vec![u8("0")])])`
When `unpack` gets type `01` followed by 65,535 one-byte rounds, and one followed by 65,536
Then the first is `Ok` and `__repeat__` holds 65,535 groups; the second is `Err(UnpackError::Short(ShortPacket { field: "repeat", needed: 0, left: 1 }))`.

**AC-3: `repeat` refused at the (max_rounds + 1)th round**
Given the scheme of AC-2 with `with_limits(3, DEFAULT_MAX_SLOTS)`
When `01aabbcc` and `01aabbccdd` are unpacked
Then the first is `Ok` with 3 groups; the second is `Err(Short { field: "repeat", needed: 0, left: 1 })` (refused when round 4 would start, `dd` unread).

**AC-4: `times` refused at the (max_rounds + 1)th round**
Given `MapScheme::new(1, vec![u8("0"), times(1, "0", vec![u8("1")])])` with `with_limits(3, DEFAULT_MAX_SLOTS)`
When `0103090909`, `010409090909`, `0104090909`, `01ff09` and `01030909` are unpacked
Then: `Ok` with 3 rounds; `Err(Short { field: "times", needed: 0, left: 1 })` (round 4 would start with one byte left); `Err(Short { field: "times", needed: 0, left: 0 })` (count 4, three rounds present: refused when round 4 would start, before the short read of `"1"` the old code returns); `Err(Short { field: "1", needed: 1, left: 0 })` (count 255, one round present: the limit is never reached, today's short read); and `Err(Short { field: "1", needed: 1, left: 0 })` (count 3, two rounds present: unchanged).

**AC-5: `times` at the default limit**
Given `u32 "0"; times(1, "0", [u8 "1"])` and the default limits
When a packet with count 65,535 followed by 65,535 bytes, one with count 65,536 followed by 65,536 bytes, one with count 4,294,967,295 followed by 65,536 bytes, one with count 4,294,967,295 followed by 65,535 bytes, and `01ffffffff00` are unpacked
Then: `Ok` with 65,535 rounds; `Err(Short { field: "times", needed: 0, left: 1 })`; `Err(Short { field: "times", needed: 0, left: 1 })`; `Err(Short { field: "times", needed: 0, left: 0 })`; and `Err(Short { field: "1", needed: 1, left: 0 })` (count 4,294,967,295, one round present: today's short read, unchanged).

**AC-6: Slot limit**
Given `repeat(0, [u8("0"), when(1, eq("0", Value::U8(1)), [u8("1"), u8("2")])])` (`count_fields` = 3) with `with_limits(DEFAULT_MAX_ROUNDS, 6)`
When `010000`, `01000000` and `0100000000` are unpacked
Then the first is `Ok` (2 rounds x 3 = 6, exactly the limit); the second is `Err(Short { field: "repeat", needed: 0, left: 1 })`; the third `Err(Short { field: "repeat", needed: 0, left: 2 })` (both refused when round 3 would start).

**AC-7: The slot total is per unpack call, across fields**
Given `[u8("0"), times(1, "0", [u8("1")]), times(2, "0", [u8("2")])]` and the packet `0102aabbccdd`
When unpacked with `with_limits(3, 4)` and with `with_limits(3, 3)`
Then the first is `Ok` (2 + 2 slots); the second is `Err(Short { field: "times", needed: 0, left: 1 })` (refused when round 2 of the second `times` would start).

**AC-8: A `times` inside a `repeat`**
Given `repeat(0, [u8("0"), times(1, "0", [u8("1")])])` (outer round `count_fields` 2, inner round 1)
When it is unpacked with `with_limits(2, DEFAULT_MAX_SLOTS)`: `01010701070107` (three outer rounds), `0103070707` (inner count 3, three inner rounds present), `01020707` (inner count 2); and with `with_limits(DEFAULT_MAX_ROUNDS, 5)`: `01020707` and `0102070700`
Then: `Err(Short { field: "repeat", needed: 0, left: 2 })`; `Err(Short { field: "times", needed: 0, left: 1 })` (the third inner round would start with one byte left); `Ok`; and `Ok` (2 + 1 + 1 = 4 slots); `Err(Short { field: "repeat", needed: 0, left: 1 })` (a second outer round would reach 6).

**AC-9: Typed `times` rows**
Given a typed `Scheme<Row>` (`Row { n: u8, pts: Vec<Pt> }`, `Pt { v: u8 }`, both `Default`) with `BoundField::u8(0, ...)` for `n` and `SchemeItem::times(1, 0, get, set, [BoundField::u8(1, ...)])` for `pts`, built with `with_limits(3, DEFAULT_MAX_SLOTS)`
When `[01 03 07 08 09]`, `[01 04 07 08 09 01]` and `[01 ff 07]` go through `BinaryPacker::unpack_with(bytes, &mut [&mut scheme.on(handler)])`
Then the first calls the handler with `n` 3 and three points `7, 8, 9`; the second returns `Err(Short { field: "times", needed: 0, left: 1 })`; the third `Err(Short { field: "1", needed: 1, left: 0 })` (count 255, one round present: today's short read); the handler is not called for the last two.

**AC-10: A refused 1 MiB packet is bounded by the limits**
Given (a) `repeat(0, [u8("0")])` and (b) `repeat(0, [flags(0, "f", eight bool groups)])` (the bools `group(i, i.to_string(), [])` for i in 0..8; `count_fields` 9), both with the default limits
When type `01` followed by 1,048,576 bytes (zeros for (a), `ff` for (b)) is unpacked, and the same with 65,535 bytes
Then the 1 MiB packets return `Err(Short { field: "repeat", needed: 0, left: 983041 })` (refused at round 65,536: the rest was not walked) and the 65,535-byte packets are `Ok`. The scratch run measured 68.5 MB resident for the refused (b) packet and 66.6 MB for the accepted one, against 1.01 GB with the limits off; the old code returns `Ok` for the 1 MiB packets, so the test fails on the unfixed tree.

**AC-11: Limits belong to the scheme**
Given `base` (the `repeat` map scheme of AC-2, default limits), `strict = base.clone().with_limits(3, DEFAULT_MAX_SLOTS)`, and the typed `Row` scheme of AC-9 built twice, as type 1 with the default limits and as type 2 with `with_limits(2, DEFAULT_MAX_SLOTS)`
When `01aabbccdd` is unpacked with `base` and with `strict`, and `[02 03 07 08 09]` and `[01 03 07 08 09]` go through `unpack_with` holding both typed handlers
Then `base` is `Ok` with four groups; `strict` is `Err(Short { field: "repeat", needed: 0, left: 1 })`; the type 2 packet returns `Err(Short { field: "times", needed: 0, left: 1 })` from the type 2 scheme's limit; the type 1 packet is `Ok` and its handler receives points `7, 8, 9`.

**AC-12: Invalid limits are refused at construction**
Given any scheme
When `with_limits(0, 1)` and `with_limits(1, 0)` are called, on a `MapScheme` and on a typed `Scheme<T>`, and `with_limits(usize::MAX, usize::MAX)`
Then the four zero cases panic with a message containing `max_rounds` or `max_slots` (`#[should_panic(expected = ...)]`), and the last returns a scheme that unpacks the 65,536-round packet of AC-2.

**AC-13: Nothing else changes**
Given the existing Rust tests
When `cargo test` runs
Then every test passes without an edit: the unit tests, the integration tests, the hostile replay (`oversize_count_times` stays `Short`, `01ffffffff00` still gives `Short { "1", 1, 0 }`) and the zero-width tests. No hostile vector and no test assertion changes. A scratch prototype of this (lazy) design passes the 159 unit tests and all integration tests.

## Non-Functional Requirements

**Performance**
- One comparison per round start and per `times` count; the suite time does not grow.

**Compatibility**
- A packet with more than 65,535 rounds, or more than 4,194,304 slots, that unpacked before is refused until the scheme raises the limit (upgrade note in AZ-2220). On a 32-bit target `usize` holds both defaults.

**Reliability**
- A refusal returns an error value; no panic, no partial row, no handler call.

## Unit Tests

New file `rust/tests/round_limits_tests.rs` (public API only: `unpack`, `MapScheme`, `Scheme`, `BinaryPacker`, the constants).

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | defaults, constants, `with_limits` on map and typed schemes | values as listed |
| AC-2 | 65,535 and 65,536 one-byte `repeat` rounds, defaults | `Ok` with 65,535 groups; `Short { "repeat", 0, 1 }` |
| AC-3 | `01aabbcc`, `01aabbccdd` with `max_rounds` 3 | `Ok`, 3 groups; `Short { "repeat", 0, 1 }` |
| AC-4 | five `times` packets, `max_rounds` 3 | exact shapes in AC-4 |
| AC-5 | u32-count `times`: 65,535; 65,536; max count + 65,536 bytes; max count + 65,535 bytes; `01ffffffff00` | `Ok`; `("times", 0, 1)`; `("times", 0, 1)`; `("times", 0, 0)`; `("1", 1, 0)` |
| AC-6 | three-name `repeat`, `max_slots` 6, three packets | `Ok`; `("repeat", 0, 1)`; `("repeat", 0, 2)` |
| AC-7 | two `times` fields, `max_slots` 4 and 3 | `Ok`; `("times", 0, 1)` |
| AC-8 | `times` inside `repeat`, five packets over two limit sets | shapes in AC-8 |
| AC-9 | typed `times` rows, three packets | handler called once with 3 points; the limit refusal and the short read, handler not called |
| AC-10 | 1 MiB map and flags schemes; 65,535-byte packets | `("repeat", 0, 983041)`; `Ok` |
| AC-11 | clone and `strict`; typed dispatch with two schemes, packets of type 1 and 2 | as listed |
| AC-12 | four zero limits, `usize::MAX` | four panics naming the parameter; one accepting scheme |
| AC-13 | existing suite | green, no test edited |

Run each new test against the unfixed tree first and require it to fail (AC-2 to AC-10 do).

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | default map scheme, 65,536 one-byte rounds | public `unpack` | `Short { "repeat", 0, 1 }` | Reliability |
| AC-4 | `times` scheme, `max_rounds` 3, `010409090909` | public `unpack` | `Short { "times", 0, 1 }` | Reliability |
| AC-8 | `times` in `repeat`, `max_slots` 5, `0102070700` | public `unpack` | `Short { "repeat", 0, 1 }` | Reliability |
| AC-9 | typed scheme, `max_rounds` 3, four rounds | `BinaryPacker::unpack_with` with one handler | `Short { "times", 0, 1 }`, handler not called | Reliability |
| AC-10 | 1 MiB of `ff` rounds, eight flag bits | public `unpack` | `("repeat", 0, 983041)` | Performance |
| AC-13 | existing hostile replay | `oversize_count_times` | still `Short` | Compatibility |

## Constraints

- **Owns**: `rust/**` only (`src/field/map_scheme.rs`, `src/scheme/mod.rs`, `src/walk/unpack.rs`, `src/walk/mod.rs`, `src/lib.rs` for the constants, the new `rust/tests/round_limits_tests.rs`). **Forbidden**: `fixtures/**`, `README.md`, `_docs/**`, the other packages, the workflows. The hostile `limit` replay and the `oversize_count_times` widening are AZ-2220, which lands after this task.
- Simplicity (coderule.md): two numbers on `MapScheme` (the typed scheme delegates), one set of counters on the existing `Cursor`; the per-field slot count is computed once from the field list, not per round. No static state.
- Files stay under 500 lines (`quality-thresholds.md`): `walk/unpack.rs` is 434 lines; if the checks push it past 500, move them into `walk/times.rs` or a small sibling module.
- Run `cargo fmt` and the project's CI-parity jobs before the commit; test command `cargo test` in `rust/`.
- Lesson of loop 11: a test that passes on the unfixed tree proves nothing; the 1 MiB `left` value and the `("repeat", 0, left)` shapes are what discriminate.

## Risks & Mitigation

**Risk 1: Counter lost in a new scope**
- *Risk*: a nested walk that gets its own counters lets rounds bypass the slot total.
- *Mitigation*: the `Cursor` is passed to every nested call today; AC-7 and AC-8 check totals across fields and across an outer round.

**Risk 2: Typed element memory**
- *Risk*: a typed `times` builds one `E` per round, so memory is `size_of::<E>()` x rounds beyond the `Values`.
- *Mitigation*: bounded by `max_rounds`; a scheme with a large `E` lowers `max_rounds`. Recorded in the README by AZ-2220.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D5 (lazy, owner decision 2026-10-06): a `times` count above `max_rounds` is not refused up front; the (max_rounds + 1)th round start is. The first draft (eager) changed the answer to `01ffffffff00` in three packages; lazy changes no existing result and bounds memory equally | owner (D5) | resolved | Low |
| Size: this task is 3 points but dense (two scheme types, two walker arms, nested `times`, typed rows, 13 acceptance criteria). If the typed scheme or the nested case turns up work beyond a delegating `with_limits` and a counter on `Cursor`, split it: map scheme first, typed scheme and nesting second | implementer | open | Low |
| Labels of the refusal (`"repeat"`, `"times"`) and the error kind are interim until C15; `"repeat"` is a new label, as no error of a `repeat` carried one | owner (C15) | accepted-risk | Low |
| Public surface grows by two methods and two getters per scheme type and two constants (D1, shape recorded as a default) | owner | accepted-risk | Low |
| The `max_slots` rule counts positions as `count_fields` does (duplicates counted), so it over-counts a name written by two `when` branches; the bound only gets stricter | owner | accepted-risk | Low |
