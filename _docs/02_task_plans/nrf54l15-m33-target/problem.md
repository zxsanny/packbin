---
loop: 68
branch: dev
---

# Embedded budgets re-based on the nRF54L15, with a Cortex-M33F target (loop 68)

Source: owner message of 2026-10-25 ("nRF54L15 is our target, so pick that for ram budget and so on or higher") and the owner's choices of 2026-10-25 (AskUserQuestion, recommended options): re-base the budgets and add a Cortex-M33F target; flash ceiling 64 KB and stack ceiling 8 KB for the C++ core, pins stay at the measured values.

## Code sections / UI locations for this loop

Owner's words: "re-base budgets + M33F target" for the C++ embedded stage: `cpp/embedded/arm.sh`, `cpp/embedded/lib.sh` (budgets and pins), the docs that name the figures (`_docs/AGENT_GOTCHAS.md`, the C++ description). No UI. No core source change expected.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Figures an AC names (flash, stack of the M33F image) are read from a run on HEAD in this loop | `AGENT_GOTCHAS.md` (loops 60, 62, 63) | open | Medium |
| The M4F target and its pins may stay beside the M33F one; dropping the M4F target is a decision | keep M4F unless the owner says drop | open | Medium |
| QEMU must have a Cortex-M33 machine with an FPU in the embedded image (mps2-an505) | check the image first; a missing machine is a named blocker | open | Medium |
| The nRF54L15 non-secure image has 128 KiB of RAM, the secure one 256 KiB | budgets stay far under both | accepted-risk | Low |
