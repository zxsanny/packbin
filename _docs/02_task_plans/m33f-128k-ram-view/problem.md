---
loop: 93
branch: dev
---

# M33F row runs in a 128 KiB RAM window

## Problem

The owner's target part is the nRF54L15 (Cortex-M33F): 256 KB of RAM, 128 KiB of it in a non-secure image. The `cpp-m33f` row runs its images on QEMU `mps2-an505` with a 4 MB RAM region (`cpp/embedded/arm/mps2-an505.ld`), so nothing stops the whole core from growing past the RAM a non-secure image has. The ceilings (flash 64 KiB, stack 8 KiB) are far under 128 KiB, but the row never links or runs inside that window.

## Outcome

- The M33F images of both rows that use the script (`cpp-m33f` and `rust-m33f`, which links into the same script) link into a 128 KiB RAM region and run there (stack top at the region end), with the figures of HEAD unchanged.
- A change that makes an image need more than 128 KiB of static RAM turns the row red, and so does a later edit of the script that moves the window.

## Origin

Candidate "a non-secure 128 KiB image" from the loop 68 handoff, still open in handoff 93. Owner picked it for loop 93 (2026-10-31). Probe on HEAD dac8d6f in a scratch copy: with `LENGTH = 128K` the whole arm stage passes with the same figures (315 of 315 vectors, flash 25,760 B, stack 724 B), and the Rust embedded stage passes with its pins unchanged (`rust-m33f` links into the same script).

## Change location

`RAM` in `cpp/embedded/arm/mps2-an505.ld` (`LENGTH = 4M` now), `target_m33f` in `cpp/embedded/arm.sh` and `rust_row` in `rust/embedded/target.sh` (owner, 2026-10-31, verbal; the loop 92 handoff names the row).

## Not covered (stated limit)

QEMU `mps2-an505` starts in Secure state and code linked at the non-secure alias locks up (see the linker script header). The run is a 128 KiB window in the secure alias, not a TrustZone non-secure image, and not the part's memory map, RRAM or timing.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| The run is not a real non-secure image; it checks a 128 KiB RAM window only | stated limit, owner chose the candidate knowing it (2026-10-31) | accepted-risk | Medium |
