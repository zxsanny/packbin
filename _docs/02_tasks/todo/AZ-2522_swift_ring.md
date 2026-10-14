---
loop: 26
branch: dev
---

# Swift in the language-pair ring

**Task**: AZ-2522_swift_ring
**Name**: Swift in the language-pair ring
**Description**: Swift joins each ring kind in both directions with every member, the session ring and the position check.
**Complexity**: 3 points
**Dependencies**: AZ-2518
**Component**: swift
**Tracker**: AZ-2522
**Epic**: AZ-2223

## Problem

The ring proves bytes cross languages; SW-7 and fit decision 3 put Swift in every kind both ways, so an iOS or macOS app and a server in any ring language exchange the same rows.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-7; scenarios S1 and S7 owned).

## Outcome

- A Swift driver implements the driver contract (`pack-<kind>`, `unpack-<kind> <hex>`, `unpack-<kind>-short <hex>`, exit 2 on an unknown command) for all 15 kinds and the session.
- Swift packs and each member of a kind's ring unpacks; each member packs and Swift unpacks.

## Scope

### Included

- `drivers/handoff-swift/` (its own `Package.swift` depending on the repository's root package by path), a position program printing the golden hex; `ring-swift.sh` building the drivers once per run (Swift on the runner, else the `swift:${RING_SWIFT}` image); `run_lang swift`; the handoff lines; `RING_SWIFT` in the ring job (any new `uses:` pinned to a commit SHA); the toolchain check; wiring guards for the Swift lines.
- The Swift wiring guards go in a new sibling test file run by the ring job next to `ring-wiring.test.sh`, which is at the 500-line cap and is not grown (its split is a handoff26 small item, not this task).
- Owns (exclusive write): `.github/workflows/drivers/handoff-swift/**` (handoff and position programs), `.github/workflows/ring-swift.sh`, `.github/workflows/language-pair.sh`, `.github/workflows/ring-toolchains.sh`, the new Swift ring-wiring test file, `.github/workflows/test.yml` (ring job only)

### Excluded

- publish-position (AZ-2523 consumes the position program)

## Acceptance Criteria

**AC-1: Every kind both ways (SW-7, S1, S7)**
Given the 15 kinds and each kind's ring members (C#, TypeScript, Python, Rust, C++, Java, Go as each kind runs them)
When `language-pair.sh` runs
Then Swift→member and member→Swift handoffs pass for every kind, including the payloads the v0.2.2 packages write; the three `-short` kinds refused by Swift with no row; failed handoffs 0

**AC-2: Session and position (SW-7)**
Given seed 1..32, value `01`+15 zero bytes
When Swift `pack-session` runs, and the Swift position program runs
Then `pack-session` prints `b55d0a29c56c203712b241232e` and the session ring both ways passes; the position program prints `4001000065cd1d00a3e1110100`

**AC-3: Wiring guarded (SW-7)**
Given a copy of `language-pair.sh` with one Swift line removed
When the Swift ring-wiring test runs
Then it fails naming the missing line

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-3 | Swift ring-wiring test | guards the Swift lines |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | ring job | `language-pair.sh` | 0 failed handoffs | SW-7 |

## Constraints

- Swift copies TypeScript at HEAD row for row (loop 26 fit decision 4). A ring disagreement is reported to the parent, not decided inside the task (probe-first).
- ADR-001: the driver uses the `Packbin` library only; no other package imported, no C target.
- On the owner's Mac the drivers build with the local Swift 6.3.3; on CI with Swift on the runner or `swift:${RING_SWIFT}`. Every shell step ends on its own (stdin closed, bounded time).
- Errors are thrown as the typed `PackbinError`; a driver maps a thrown error to the contract's refusal exit, and a trap is a failed handoff.

## Risks & Mitigation

**Risk 1: Ring time**
- *Risk*: Swift both ways with every member adds about one more language to the ring job, and `swift build` is slow cold.
- *Mitigation*: Build the Swift drivers once per run (release build to a temp location), as Java compiles once and Go builds once; call the built binary per handoff.

**Risk 2: File caps**
- *Risk*: `language-pair.sh` (343 lines) grows with 15 Swift kinds.
- *Mitigation*: Keep it at or under 500 lines; if a table form is needed to stay under, report to the parent first.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `ring-wiring.test.sh` is at 500 lines; the Swift guards go in a new sibling file | sibling file confirmed (parent, 2026-10-14) | resolved | Low |
