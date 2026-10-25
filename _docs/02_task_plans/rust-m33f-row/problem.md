---
loop: 70
branch: dev
---

# Loop 70: Rust Cortex-M33F row in the Rust embedded stage

## What

The Rust embedded stage (`rust/embedded`) builds the heap-free `packbin::nostd` API only for `thumbv7em-none-eabihf` (Cortex-M4F) and measures it on QEMU `mps2-an505`'s sibling machine. The owner's target part is the nRF54L15 (Cortex-M33F). Loop 68 added the `cpp-m33f` row for the C++ core; the Rust side has no row for that architecture. Add a Rust Cortex-M33F row next to it, with its own flash and stack pins.

Owner words (2026-10-25, loop 69 choice, accepted as recommended): "Rust on the Cortex-M33F"; moved from loop 69 to loop 70; chosen again at loop 70 start (AskUserQuestion, recommended option).

## Code sections / UI locations for this loop

Owner words: "Code: rust/src/nostd and the Rust embedded stage"; the handoff names the places to follow:

- Rust embedded stage: `rust/embedded/` (`target.sh`, `run.sh`, `feature-sets.txt`, `limits.txt`, `checks.sh`, `probe/`).
- The C++ M33F row to mirror: `cpp/embedded/arm/mps2-an505.ld`, `m33f_*` in `cpp/embedded/lib.sh`, `target_m33f` in `cpp/embedded/arm.sh`.

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| Figures an AC names are read from a run on HEAD in this loop | AGENT_GOTCHAS | open until measured | Medium |
