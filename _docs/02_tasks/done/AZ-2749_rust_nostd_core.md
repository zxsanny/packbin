---
loop: 50
branch: dev
---

# Rust core: features, flat schemes and the host proof

**Task**: AZ-2749_rust_nostd_core
**Name**: Rust core: features, flat schemes and the host proof
**Description**: The Rust package gets Cargo features (`std` default, `alloc`, `text`, `ecc`, `session`) and a `nostd` module (`packbin::nostd`) that builds with `#![no_std]` and no allocator: errors as values, caller buffers, a `Row` trait, plain-data schemes with construction checks, scalar and bytes fields. The golden fixture decodes on the host with the same code.
**Complexity**: 5 points
**Dependencies**: None
**Component**: rust (core)
**Tracker**: AZ-2749
**Epic**: AZ-2750

## Problem

The meshbell field mesh (sibling repository, same owner) is written in Rust: node firmware for relays and packs, the smart-device profile, the station radio, the agent, the mesh service and the simulator. Every node needs packbin for its own radio-layer messages (status and unreachable reports, one key-delivery record, a per-hop MAC-only call). The Rust package has no `no_std` build (state at `c20bcd6`): its public API is heap-bound by design (`Values` is a `HashMap<Rc<str>, Option<Value>>`, `Value` owns `Vec`, `String` and `BTreeMap`, `pack` returns `Vec<u8>`), so `no_std` needs a second, buffer-based API (owner decision B, 2026-10-20). This task is the base of that API; later tasks add field kinds and features.

## Outcome

- A Cargo feature set where `default-features = false` builds the core with `#![no_std]` and no `alloc`.
- A `core` API with the error kinds and `Result` shape of the C++ core, a `Reader` and `Writer` over caller buffers, number fields (u8 to u64, i8 to i64, f32, f64, big-endian flag; bool is a flag bit and comes with AZ-2752), fixed bytes, and construction checks that refuse an invalid scheme before any byte moves.
- The default (`std`) build is unchanged; a differential test compares std and core output.

## Scope

### Included
- Cargo features and the `no_std` crate switch; the core types and scalar and bytes fields; the `Row` trait; the scheme checks that apply to flat schemes; the differential test harness (std pack equals core pack) and the golden fixture on the host.

### Excluded
- Flags, bits, packed, sized, when (AZ-2752); repeat, group, times, lists, dicts (AZ-2753); text (AZ-2754); ecc (AZ-2755); session (AZ-2756); the embedded build and sizes (AZ-2751); the hostile corpus (AZ-2757).

## Acceptance Criteria

**AC-1: no_std build (original AC-1, host half; R12)**
Given `default-features = false` and no `alloc`
When the crate is built for the host with `std` off and `core` only
Then it builds, and decoding the golden fixture with the core matches the fixture bytes and values (the device half is AZ-2751)

**AC-2: Pack equals std (R1)**
Given a flat scheme of scalars and fixed bytes, as a status report of a relay, and a 64-byte output buffer
When `pack` runs with the core and with the std API on the same values
Then both give the same bytes and `Result.offset` is the length

**AC-3: Buffer too small (R2)**
Given an output buffer one byte short
When `pack` runs
Then `BufferFull` with the bytes needed; no byte is written past `cap`; unpack of the full packet gives back the row

**AC-4: Untrusted bytes (R3)**
Given an empty packet, a packet cut at every length, a packet with trailing bytes
When `unpack` runs
Then `ShortPacket` (with the field and bytes needed) or `TrailingBytes`; never a panic or an out-of-range read

**AC-5: Invalid scheme (R5)**
Given a scheme with a duplicate field id or an id outside the range
When `validate` runs
Then `SchemeInvalid` is returned before any byte is read or written

**AC-6: Numbers and floats (R12)**
Given an f32 with NaN bits, a 64-bit field, big-endian and little-endian fields
When the row is packed and unpacked
Then the bits come back unchanged; byte order follows the field, not the CPU

**AC-7: std build unchanged (R11, original AC-4)**
Given default features
When the existing Rust suite, the golden fixture and the ring run
Then every row passes and the bytes are unchanged

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `cargo test --no-default-features` core tests; golden fixture | match |
| AC-2 | differential test over the fixture schemes | equal bytes |
| AC-3 | pack into every capacity from 0 to the packet length | `BufferFull` below, `Ok` at length |
| AC-4 | cut and extended copies of each packet | only the two error kinds |
| AC-5 | invalid scheme cases | `SchemeInvalid`, no output |
| AC-6 | NaN, extremes, both byte orders | bit-exact |
| AC-7 | default-feature suite and `ring` | green |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.

## Risks & Mitigation

**Risk 1: A second walker drifts from the std walker**
- *Mitigation*: the differential test runs on every host run and covers every fixture; a format change names both walkers in its task

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
