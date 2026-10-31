---
loop: 93
branch: dev
---

# M33F rows run in a 128 KiB RAM window

**Task**: AZ-3469_m33f_128k_ram_window
**Name**: M33F rows run in a 128 KiB RAM window
**Description**: The `cpp-m33f` and `rust-m33f` rows link and run their images in a 128 KiB RAM window and fail when an image needs more or the window moves.
**Complexity**: 3 points
**Dependencies**: None (AZ-3189 and AZ-3231 shipped)
**Component**: cpp embedded stage (`cpp/embedded`: `mps2-an505.ld`, `arm.sh`, `lib.sh`) and Rust embedded stage (`rust/embedded/target.sh`)
**Tracker**: AZ-3469
**Epic**: none

## Problem

The owner's target part is the nRF54L15 (Cortex-M33F): 256 KB of RAM, 128 KiB of it in a non-secure image. The two M33F rows link into a 4 MB RAM region, so nothing stops an image from needing more RAM than the part gives a non-secure image. The flash and stack ceilings are far below 128 KiB, but no row links or runs inside that window. Probe on HEAD dac8d6f in a scratch copy: with a 128 KiB window both rows pass with unchanged figures.

## Outcome

- Every M33F image of both rows links into a 128 KiB RAM region and runs with its stack top at the region end.
- An image that needs more than 128 KiB of static RAM turns its row red.
- A later edit that moves the window turns both rows red.

## Scope

### Included
- The RAM length of the shared AN505 linker script (`mps2-an505.ld`), read by exactly two rows.
- One check of the stack-top symbol of each linked M33F image, in both rows, against one value kept with the other M33F numbers in `lib.sh`.
- The script header and the `lib.sh` comment: say that the run is a 128 KiB window in the secure alias.

### Excluded
- A real non-secure (TrustZone) image, RRAM, the part's peripheral memory map, cycle timing: QEMU `mps2-an505` starts in Secure state and code linked at the non-secure alias locks up (the script header says so).
- Any change under `cpp/src`, `cpp/include` or `rust/src`; any new row; the M3, M4F, s390x and AVR rows.
- A separate RAM-use budget below the window (the existing flash and stack ceilings and pins stay the only byte rules).

## Acceptance Criteria

**AC-1: Window**
Given the M33F images of `cpp-m33f` (all-kinds, vector runner, baseline, frame) and of `rust-m33f` (baseline and the four feature sets)
When they are linked
Then each has its stack top at 0x38020000 (128 KiB above the RAM start 0x38000000) and the link reports no region overflow (9 of 9 images)

**AC-2: Figures unchanged**
Given the figures of HEAD
When both rows run in the window
Then `cpp-m33f` passes with 315 of 315 vectors, all-kinds flash 25,760 B, stack 724 B, frame flash 8,416 B and stack 912 B, and `rust-m33f` passes with the pins of `limits-m33f.txt` (base 15,132 B and 456 B, text 27,268 B and 2,736 B, ecc 18,764 B and 744 B, frame 20,404 B and 1,728 B)

**AC-3: Overflow**
Given a scratch copy where the all-kinds image carries a zero-initialised array of 130 KiB
When `cpp-m33f` runs
Then the row fails and its log shows the linker's RAM-overflow message

**AC-4: Window moved**
Given a scratch copy where the script's RAM length is 4 MB
When `cpp-m33f` runs and when `rust-m33f` runs
Then each row fails and names the expected stack top 0x38020000 and the one found

**AC-5: Nothing else moves**
Given the change
When the stage runs
Then 0 compile warnings, no file under `cpp/src`, `cpp/include` or `rust/src` changes, the M3, M4F, s390x and AVR rows give the same figures, and `lib.test.sh` and `run-parts.test.sh` pass unchanged (no row added)

**AC-6: Words match**
Given the script header, the `lib.sh` comment on the M33F target and the README
When read after the change
Then each says that the M33F images run in a 128 KiB RAM window of the secure alias and that this is not a TrustZone non-secure image (0 of the stale "4 MB" statements left)

## Non-Functional Requirements

**Performance**
- The added check is one `nm` per image; the stage time moves by under 2 s (measured in the task and written in the record).

**Compatibility**
- The Rust M33F row links into the same script; its pins in `limits-m33f.txt` stay.

**Reliability**
- Deterministic: no clock, no random input.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5 | `cpp/embedded/lib.test.sh` and `run-parts.test.sh` fakes | pass unchanged |
| AC-5 | `rust/embedded/checks.test.sh` | passes unchanged |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | the `packbin-embedded` image, HEAD plus the change | `cpp/embedded/run.sh arm` (`cpp-m33f` row) | PASS; the log shows the stack top 0x38020000 for 4 images and the HEAD figures | Reliability |
| AC-1, AC-2 | libs built with Rust 1.98 | `rust/embedded/run.sh image` (`rust-m33f` row) | PASS; stack top 0x38020000 for 5 images; pins met | Reliability |
| AC-3 | a 130 KiB array added in a scratch copy | the same `cpp-m33f` run | row FAIL with the linker's overflow message; scratch copy deleted | Reliability |
| AC-4 | script length set to 4 MB in a scratch copy | both rows | both FAIL naming 0x38020000 | Reliability |
| AC-6 | `git grep` of the stale wording | the three texts | 0 matches | — |

## Constraints

- One value for the window end, kept with the other M33F numbers in `cpp/embedded/lib.sh`; the script keeps its own `LENGTH` (a linker script cannot read the shell), and AC-4 is what ties the two together.
- Failure runs happen in scratch copies, never in the working tree.

## Risks & Mitigation

**Risk 1: The Rust row fails at 128 KiB in CI only**
- *Risk*: the Rust libs need Rust 1.98; a different toolchain gives other figures.
- *Mitigation*: run the Rust row locally with 1.98 before the commit (probe already green on HEAD with 1.98.1).

**Risk 2: The vector runner uses newlib's heap**
- *Risk*: its heap grows from the end of bss toward the stack and a 128 KiB window is smaller than 4 MB.
- *Mitigation*: the probe ran it green (315 of 315); AC-2 keeps it in the proof.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The run is a 128 KiB window in the secure alias, not a TrustZone non-secure image; the part's memory map, RRAM and timing stay unchecked | owner chose the candidate knowing it (2026-10-31) | accepted-risk | Medium |
| The check pins the window end, so a deliberate later change of the window needs one edit in the script and one in `lib.sh` | none stated | open | Low |
