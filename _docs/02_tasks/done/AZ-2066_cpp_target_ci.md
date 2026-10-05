---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ embedded targets in CI

**Task**: AZ-2066_cpp_target_ci
**Name**: C++ target CI
**Description**: CI builds the core for every embedded target, runs the vectors and the session on QEMU Cortex-M3 and a big-endian host, checks for heap and exception references, and reports size and stack.
**Complexity**: 3 points
**Dependencies**: AZ-2062_cpp_core_grouped_kinds, AZ-2063_cpp_core_counted_kinds, AZ-2065_cpp_core_session
**Component**: cpp
**Tracker**: AZ-2066
**Epic**: AZ-2059

## Problem

Nothing proves the golden bytes on a microcontroller CPU; CI runs C++ on the Ubuntu host only (`problem.md` blocker 10).

## Outcome

- One CI job builds every AC-1 target and runs AC-2, AC-3, AC-10 on QEMU `mps2-an385` and AC-4 on a big-endian host, writing one report row per target.
- The same vector table as the host suite (AZ-2064) drives the firmware runner; vectors run equals vectors asserted.

## Scope

### Included
- CI container with arm-none-eabi GCC 13, ESP-IDF 5.x, QEMU system (`mps2-an385`) and QEMU user (`s390x` or `ppc64`); test compose service for local runs.
- Vector-runner firmware; link wrappers that abort on malloc/new; link-map check for `__cxa_throw` and `__cxa_allocate_exception`.
- Size (`arm-none-eabi-size`) and stack (`-fstack-usage`) report rows.

### Excluded
- Hardware boards; registry publishing (AZ-2067).

## Acceptance Criteria

**AC-1: Builds the embedded way**
Given the core and `-std=c++17 -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror`
When it is compiled for Cortex-M0+, Cortex-M4F, ESP32-S3 and ESP32-C3
Then each build has 0 errors and 0 warnings (feature AC-1).

**AC-2: No heap, no exceptions**
Given a firmware that packs and unpacks a scheme using every field kind, linked with malloc/calloc/realloc/new wrappers that abort
When it is linked and run on QEMU `mps2-an385`
Then `__cxa_throw` and `__cxa_allocate_exception` references are 0 and wrapper calls are 0 (feature AC-2).

**AC-3: Same bytes on the target**
Given every vector in the shared vector table and the `fixtures/golden.hex` row
When the firmware runs them on QEMU `mps2-an385`
Then mismatched bytes are 0, mismatched fields are 0, and vectors run equals vectors asserted (feature AC-3).

**AC-4: Same bytes on a big-endian CPU**
Given the same vectors
When the core test runs under QEMU user `s390x` or `ppc64`
Then mismatched bytes and fields are 0 (S7; feature AC-4).

**AC-5: Flash and stack budget**
Given the AC-2 firmware on the reference target (Cortex-M4F, GCC 13, newlib-nano)
When size and stack reports are read
Then core code plus one 14-field table is ≤ 8 KB flash, the deepest pack/unpack call is ≤ 512 B stack, and core `.data`/`.bss` is 0 B (feature AC-5).

**AC-6: Session on the board**
Given the session vectors
When the firmware runs them on QEMU
Then padded bytes are equal, and OS random references in the image are 0 (feature AC-10).

**AC-7: Every target in CI**
Given a push to any branch
When `test.yml` runs
Then the embedded job writes one row per target to the report table, and a failing target fails the workflow (feature AC-13).

## Non-Functional Requirements

**Performance**
- AC-5 budget is the performance gate for the embedded profile.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | link map grep | 0 `__cxa_*` references |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | four toolchains | build | 0 errors, 0 warnings | — |
| AC-2 | wrapped firmware on QEMU | run | 0 wrapper calls | — |
| AC-3 | vector table on QEMU | run | 0 mismatches, run == asserted | — |
| AC-4 | QEMU user big-endian | run | 0 mismatches | — |
| AC-5 | size + stack reports | read | ≤ 8 KB, ≤ 512 B, 0 B | AC-5 |
| AC-6 | session vectors on QEMU | run | equal bytes | — |
| AC-7 | CI run | report rows | one per target, fail on any failure | — |

## Constraints

- Feature out-of-scope: no hardware CI; QEMU and toolchain builds are the proof.
- Report rows go into the existing report table (`report-row.sh`).

## Risks & Mitigation

**Risk 1: Container size and CI time**
- *Risk*: ESP-IDF plus QEMU makes a large image.
- *Mitigation*: one embedded image, cached; ESP-IDF targets build only (no run).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| No embedded toolchain on the maintainer laptop | CI container is the local run path too | accepted-risk | Low |
