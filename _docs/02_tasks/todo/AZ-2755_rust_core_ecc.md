# Rust core: message ECC without allocation

**Task**: AZ-2755_rust_core_ecc
**Name**: Rust core: message ECC without allocation
**Description**: Parity bytes, repair in place and the 254-byte limit in the heap-free core; `ecc` off refuses parity schemes.
**Complexity**: 3 points
**Dependencies**: AZ-2749
**Component**: rust (core)
**Tracker**: AZ-2755
**Epic**: AZ-2750

## Problem

Radio messages are protected with Reed-Solomon parity. The std module uses `Cow` and `Vec` at its edges; the algorithm itself is constant tables and fixed-size arrays.

## Outcome

- An `ecc` feature (off by default): pack with parity, unpack with detection or repair up to a limit, repair in the caller's writable buffer.

## Scope

### Included
- Making the algorithm shareable by both walkers without changing its output; the core wrappers; the feature switch.

### Excluded
- Dispatch over several schemes with different parity (the C++ rule: one parity count per dispatch) unless the core has a dispatch by then.

## Acceptance Criteria

**AC-1: Repair (R9)**
Given `fixtures/ecc` vectors and a protected message with up to the limit of wrong bytes
When the core unpacks with repair
Then the message is repaired in place and `repaired` counts the bytes; with more wrong bytes `Uncorrectable`

**AC-2: Too long (R9)**
Given a protected message above 254 bytes, or fields above 254 minus the parity count on pack
When pack or unpack runs
Then `TooLong`

**AC-3: ecc off (R8)**
Given a scheme that declares parity bytes, built without `ecc`
When validate runs
Then refused; a scheme with parity 0 is the plain scheme

**AC-4: Same bytes as std**
Given the protected vectors
When the core packs
Then the bytes equal the std bytes

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | ecc vectors with k wrong bytes for k up to the limit and above | repaired / `Uncorrectable` |
| AC-2 | 255-byte message | `TooLong` |
| AC-3 | build without the feature | refused |
| AC-4 | differential | equal |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.


## Risks & Mitigation

**Risk 1: Sharing the algorithm changes the std module**
- *Mitigation*: the std ecc suite and the ring run unchanged

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
