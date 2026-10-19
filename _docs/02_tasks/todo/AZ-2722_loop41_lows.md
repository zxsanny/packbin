# Loop 41 Lows: scheme check, repair arrays, string capacity, payload type checks

**Task**: AZ-2722_loop41_lows
**Name**: Loop 41 Lows (F57, F59, F60, F19 instances)
**Description**: The cheap Low findings of the loop 41 audit, fixed in the packages they name.
**Complexity**: 3 points
**Dependencies**: None
**Component**: C++, C#, Go, Rust, Python, TypeScript packages
**Tracker**: AZ-2722
**Epic**: AZ-2645

## Problem

`_docs/05_security/security_report.md` "Loop 41 addendum": F57, F59, F60 and the new F19 instances are open Lows. F58 (Python session pad cost) is deferred by the owner (loop 42 intake, 2026-10-19: accept all recommended).

## Outcome

- F57: a C++ session unpack with a scheme whose status is not Ok answers `SchemeInvalid` before it touches the buffer or spends a receive position (as the non-session `unpack_repair`).
- F59: C# and Go ECC repair allocate fixed arrays of n + 1 bytes, not one per step.
- F60: a Rust decoded string has no spare capacity beyond its length.
- F19: the Python and TypeScript session `unpack` check the payload type before the receive index moves; Python refuses a `str` or `int` payload with the package's existing type error and keeps the index; TypeScript refuses a string or number payload (it does not turn them into an empty or zero-filled buffer).

## Acceptance Criteria

**AC-1** (F57): a C++ session unpack with an invalid scheme returns `SchemeInvalid`, leaves the buffer unchanged and the next valid call reads at the same receive position.
**AC-2** (F59): C# and Go repair of the worst case (n 32, t 16, N 254) give the same bytes as before and allocate no more than a few arrays of n + 1 bytes (a test counts allocations where the language allows it).
**AC-3** (F60): `capacity() == len()` for strings the Rust text decoder returns (test on a max-length text).
**AC-4** (F19): after a refused wrong-type payload, Python and TypeScript sessions still unpack the next valid packet at the same index.
**AC-5**: existing vectors, ring and golden packet unchanged.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| C++ session/codec edits vs the Cortex-M4F flash margin | `AGENT_GOTCHAS.md` (60 B) | open | Medium |
