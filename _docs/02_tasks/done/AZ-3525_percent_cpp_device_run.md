---
loop: 98
branch: dev
---
# Percentage test on the C++ device images

**Task**: AZ-3525_percent_cpp_device_run
**Name**: percent_cpp_device_run
**Description**: The C++ vector runner runs a percentage test on QEMU Cortex-M3 and Cortex-M33F.
**Complexity**: 3 points
**Dependencies**: None
**Component**: C++ package (embedded stage)
**Tracker**: AZ-3525
**Epic**: none

## Problem

The C++ percentage is proven on the host and in the ring. The embedded stage only proves size, stack and link for it: the percentage tests need files and an operating system, and the vector runner on the device runs the target-safe tests only. The rounding, the 32 cap and the lowered repair limit never run on a 32-bit target with hard float.

## Outcome

- A percentage test with no file or OS need runs inside the vector runner on both QEMU machines.
- The test fails when the rounding is wrong.

## Scope

### Included
- A target-safe percentage test with its rows compiled in, added to the tests the device runner executes.
- The embedded stage asserting its per-file check count.
- The measured flash and stack of the images that grow, held to the existing pins.

### Excluded
- The host percentage tests and the fixture (unchanged).
- A physical board (QEMU `mps2-an505` stands for the Cortex-M33F; same as the existing rows).
- Changing any pin without the owner's yes.

## Acceptance Criteria

**AC-1: The test covers the percentage**
Given the vector runner
When it runs the percentage test
Then at least 12 cases pass: p = 1, 10, 25, 50 and 100 against clear lengths that hit the round-up and the 32 cap, p = 0 giving the bytes of a scheme without parity, p = 101 refused as a bad scheme, and a pack, damage and repair round trip whose repair limit above n / 2 is lowered to n / 2.

**AC-2: It runs on both machines with the same bytes**
Given the embedded stage
When it runs the vector runner on QEMU `mps2-an385` (Cortex-M3) and `mps2-an505` (Cortex-M33F)
Then both report 0 failures, the per-file check count the stage asserts matches, and the packets they print for the percentage rows are identical.

**AC-3: The test bites**
Given the rounding in the C++ computation changed to round down
When the stage runs
Then it fails on both machines; with the change reverted it passes.

**AC-4: Pins hold**
Given the images that include the new test
When their flash and stack are measured
Then every existing pin holds, or the moved figure is shown and kept unpinned until the owner agrees; no image gains a heap or panic reference.

## Non-Functional Requirements

**Reliability**
- The existing embedded checks (heap, panic, read-only data, RAM end) stay as strict as before.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the new percentage test on the host build | all cases pass on the host first |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | embedded stage in the `packbin-embedded` image | run M3 and M33F vector runners | FAILURES 0 on both; same packets | heap/panic checks |
| AC-3 | rounding mutated | the stage | exits non-zero on both machines | - |
| AC-4 | the built images | size and stack report | within the pins, or reported | pins |

## Constraints

- One setting per unpack call, the rules of `contracts/library/message-ecc.md`, and the README table of the percentage are the oracle.
- No new test dependency; the test uses the same check harness as the other vector tests.

## Risks & Mitigation

**Risk 1: The Cortex-M4F or M3 flash pin has little margin**
- *Risk*: a test image grows past a pin (margin was 32 B in loop 20).
- *Mitigation*: the test lives only in the vector image, which has no flash pin, and the stage reports the size of every image it builds.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A pin moves because of the test | owner approves any re-pin | open | Medium |
| QEMU `mps2-an505` models, not is, the nRF54L15 | accepted: the existing M33F rows use the same machine | accepted-risk | Low |
