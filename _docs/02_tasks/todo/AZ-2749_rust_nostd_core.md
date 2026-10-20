---
loop: 50
branch: dev
---

# Rust: a `no_std` core for packbin

**Task**: AZ-2749_rust_nostd_core
**Name**: Rust `no_std`, heap-free core with a link-checked embedded profile
**Description**: The Rust package builds without the standard library and without an allocator for Cortex-M4F, so meshbell's nodes (nRF52840 relays, packs and smart devices, an ESP32 station radio) can use packbin; frame mode (meshbell PB-04) builds on it.
**Complexity**: 5 points
**Dependencies**: None
**Component**: rust (core, features, embedded CI)
**Tracker**: AZ-2749
**Epic**: AZ-2750

## Problem

The meshbell field mesh (sibling repository, same owner) is written entirely in Rust: node firmware for relays and packs, the smart-device profile, the station radio, the station agent, the mesh service and the simulator. Relays and packs forward application bodies as they are; packing and unpacking of bodies stays on the server (C#) and on the users' devices (Kotlin, Swift). Every node still needs packbin for its own radio-layer messages: sealing its status and unreachable reports, opening its one network-key delivery record, and a per-hop MAC-only call.

Packbin's Rust package has no `no_std` build (state at `c20bcd6`), so none of those programs can use packbin today.

## Outcome

- A Cargo feature set where `default-features = false` builds the core (schemes, flags, bits, packed, u2, lists, dicts, compact text) with `#![no_std]` and no `alloc`: callers pass buffers, results are `Result` values, there is no `unwrap`, `expect`, indexing that can panic or arithmetic that can overflow in decode paths.
- Features: `std` (default, for servers), `alloc` (optional), `text` (compact text, can be left out), `ecc` (message ECC, off by default), `session` (stream and, later, frame mode).
- CI jobs that build the profile for `thumbv7em-none-eabihf`, report flash and stack per feature set, and fail if a heap symbol or a panic path is linked into decode.
- The existing Rust vectors, the golden fixture and the `ring` job still pass with the `std` build. Wire bytes do not change.

## Scope

### Included
- Making the core `no_std`, the feature switches, the CI size report and link check

### Excluded
- Frame mode and the MAC-only call (a following task, meshbell PB-04)
- Hardware cycle counts (meshbell PB-10)
- Other packages (Swift frame mode for the iOS app is meshbell PB-06b)

## Acceptance Criteria

**AC-1: no_std build**
Given `default-features = false`
When the crate is built for `thumbv7em-none-eabihf`
Then it links without `std` and without an allocator, and decoding the golden fixture on the host with the same code matches the fixture.

**AC-2: no panic path in decode**
Given the embedded link check
When decode paths are inspected
Then no panic, unwrap or unchecked index is reachable from untrusted bytes, and the hostile corpus returns errors only.

**AC-3: sizes published**
Given the CI report
When the profile is built with and without `text`, `ecc` and `session`
Then flash and stack figures are published and stay under limits set by the owner.

**AC-4: std build unchanged**
Given the existing suite and the ring
When it runs with default features
Then every row still passes and the bytes are unchanged.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | thumbv7em build; golden fixture on host | links; match |
| AC-2 | link check; hostile corpus | no panic symbols; errors only |
| AC-3 | CI size report per feature set | published, within limits |
| AC-4 | default-feature suite and ring | green |

## Constraints

- Wire bytes do not change (the wire-stability policy applies).
- Meshbell targets: nRF52840 (relays, packs, smart devices) and ESP32 (station radio); `std` for server-side Rust components.
- Fallback if this task is declined: meshbell links packbin's heap-free C++ core through FFI, which breaks its all-Rust rule (R-34).
- Source of the requirement: meshbell `_docs/cross_repo/packbin/` (PB-04a, README) and `_docs/01_solution/solution.md` §7.5.
