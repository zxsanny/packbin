---
loop: 23
branch: dev
---

# Rust refuses repeat values it would drop

**Task**: AZ-2433_rust_repeat_dropped_values_refused
**Name**: Rust refuses repeat values it would drop: lists beside __repeat__ groups and nested round names (U22, F37)
**Description**: The Rust map form drops given values in two `repeat` shapes without a word; refuse both at pack.
**Complexity**: 2 points
**Dependencies**: none
**Component**: rust
**Tracker**: AZ-2433
**Epic**: AZ-2069

## Problem

Owner decision U22 A (2026-10-13); review22 finding 5; security F37. AZ-2412 (U13) refuses per-name `repeat` lists given without `__repeat__` groups, but two shapes still drop values silently: (a) per-name lists given beside `__repeat__` groups: `{__repeat__: [{n:1,x:5}], n: [1]}` packs `010105`; (b) names of a `times`/`repeat` nested in the repeat body are not collected (`collect_below`, `rust/src/walk/times.rs`): `repeat { u8 n; times(n) { u8 w } }` with `{w: [1]}` and no groups packs `01`. A `times` refuses (a) with `check_lists`; `repeat` (`check_repeat_lists`) does not.

## Outcome

- (a) A per-name value given beside `__repeat__` groups for a name in the repeat body is refused with a `PackError` naming it, as `check_lists` does for `times`.
- (b) A name of a round nested in a `repeat` body, given outside groups, is refused with the U13 message naming it.
- Rows that pack at HEAD with groups only, or with no extra names, keep their bytes.

## Scope

### Included
- `rust/src/walk/times.rs` (`check_repeat_lists`, `collect_below`) and Rust tests.

### Excluded
- U18 (`when` inside `times`: README exception only); review finding 10 (`names_below` per round); rustfmt of files not otherwise touched.

## Acceptance Criteria

**AC-1: lists beside groups**
Given `repeat { u8 n; u8 x }` and `{__repeat__: [{n:1,x:5}], n: [2]}` (a kept value the rounds do not hold; also a shorter list, a lone value, an empty list beside rounds that hold the name)
When packed
Then `PackError` naming `n` (`repeat at id N: list for 'n' disagrees with its rounds`, as `check_lists` for `times`).
(Amended 2026-10-13: the review's example `n: [1]` agrees with its round and packs `010105`, as through a `times`; U22 A is "like `times` `check_lists`", which refuses only a disagreeing value.)

**AC-2: nested round names**
Given `repeat { u8 n; times(n) { u8 w } }` and `{w: [1]}` with no groups (a `repeat` nested in a `repeat` cannot be built in Rust: construction panics, so it is not covered)
When packed
Then `PackError` naming `w`.

**AC-3: unchanged rows**
Given groups-only rows, rows with no repeat names, and the existing repeat tests
When packed
Then bytes as at HEAD (b8b2809).

**AC-4: times unchanged**
Given the existing `times` list tests (incl. AZ-2414 short list under `flags`)
When run
Then green, unchanged.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | list beside groups | refused, name in message |
| AC-2 | nested times / repeat names | refused, name in message |
| AC-3 | groups-only rows | hex unchanged |
| AC-4 | times suite | green |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | hostile loader (rust), 65 cases | `cargo test` | all pass | — |

## Constraints

- No `cargo fmt` on files the task does not otherwise change.
