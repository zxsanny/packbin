---
loop: 98
branch: dev
---
# Percentage in the Rust ecc device probe

**Task**: AZ-3526_percent_rust_device_run
**Name**: percent_rust_device_run
**Description**: The Rust ecc probe packs, damages and repairs with a percentage on the Cortex-M4F and Cortex-M33F rows.
**Complexity**: 3 points
**Dependencies**: None
**Component**: Rust package (embedded stage)
**Tracker**: AZ-3526
**Epic**: none

## Problem

The heap-free Rust scheme takes a percentage behind the `ecc` feature, but the embedded probe packs with a count of 4 only. The percentage code is linked into the ecc image and never run on a device.

## Outcome

- The ecc probe runs a percentage round trip on both Rust QEMU rows.
- A wrong rounding makes the run fail.

## Scope

### Included
- A percentage round trip in the ecc probe (pack with a percentage, damage bytes, repair, read back, compare the clear bytes), beside the existing count round trip.
- The re-measured flash and stack of the ecc and larger feature sets against their pins.

### Excluded
- The `std` Rust API and the host tests (unchanged).
- Raising any pin without the owner's yes.

## Acceptance Criteria

**AC-1: The percentage round trip passes on the device**
Given the ecc feature set
When the probe packs a message with a percentage, damages two bytes and repairs with a limit above the lowered limit
Then the repaired count and the clear values equal the sent ones, and the probe result is 0.

**AC-2: Both rows agree**
Given the Cortex-M4F row and the `rust-m33f` row (`mps2-an505`)
When both run the ecc probe
Then both return 0 and the packed bytes of the percentage message are identical.

**AC-3: The count round trip and the test's bite**
Given the existing count round trip and a rounding changed to round down
When the stage runs
Then the count round trip still returns 0 on the unmutated tree, and the mutated tree fails the percentage round trip on both rows.

**AC-4: Pins hold**
Given the feature sets that include ecc
When their flash and stack are measured
Then every existing pin and ceiling holds, or the new figure is shown and not pinned until the owner agrees; the heap and panic-path checks stay clean.

## Non-Functional Requirements

**Reliability**
- The probe uses no heap and no panic path, as the other sets.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the `nostd` percentage round trip on the host | passes before it goes to the device |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | embedded stage, ecc set, both QEMU machines | run the probes | result 0 on both; identical bytes | no heap, no panic |
| AC-3 | rounding mutated | the stage | non-zero on both rows | - |
| AC-4 | built images | size and stack report | within pins or reported | pins |

## Constraints

- The oracle is the C++/reference percentage rows (`fixtures/ecc/percent-vectors.txt`) and the README table.

## Risks & Mitigation

**Risk 1: Flash pin of the ecc set has little margin**
- *Risk*: the added code crosses the pin.
- *Mitigation*: measure first; report the figure and ask before any re-pin.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A pin moves because of the probe | owner approves any re-pin | open | Medium |
