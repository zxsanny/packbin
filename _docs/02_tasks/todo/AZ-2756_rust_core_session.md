# Rust core: session without allocation

**Task**: AZ-2756_rust_core_session
**Name**: Rust core: session without allocation
**Description**: Seal and open with a caller nonce on caller buffers; same bytes as the std `PackSession`.
**Complexity**: 3 points
**Dependencies**: AZ-2755
**Component**: rust (core)
**Tracker**: AZ-2756
**Epic**: AZ-2750

## Problem

Nodes seal their reports and open one key-delivery record. The std session returns `Vec` and generates its own nonce; a node supplies the nonce and the buffers.

## Outcome

- A `session` feature: load a seed, start or join with a caller nonce, pack and unpack protected payloads in caller buffers.

## Scope

### Included
- The session on the core, sharing the hash, key-derivation and pad code with the std session.

### Excluded
- Frame mode, the 4-byte tag, the replay window and epoch keys (meshbell PB-04); randomness (the caller supplies the nonce).

## Acceptance Criteria

**AC-1: Same bytes as std (R10)**
Given the same seed and nonce
When the core session packs a row and the std `PackSession` packs it
Then the bytes are equal, and each opens the other's packet

**AC-2: No allocation**
Given the device image of AZ-2751
When the session functions are linked
Then no heap symbol is reachable

**AC-3: Refusals**
Given a wrong nonce size, a short seed, a tampered payload
When the session functions run
Then an error kind; no panic; no partial output

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | cross-open test and differential | equal |
| AC-2 | link check with the feature on | no heap symbol |
| AC-3 | bad inputs | error kinds |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.


## Risks & Mitigation

**Risk 1: A nonce reuse by the caller**
- *Mitigation*: documented in the rustdoc; not detectable by the library

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
