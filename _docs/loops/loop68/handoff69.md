# Handoff to loop 69

From the loop 68 record (`record68.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) is empty after close.

## Shipped in loop 68

The arm embedded stage has a `cpp-m33f` row (nRF54L15 core): the whole C++ core with codec and error correction, run on QEMU `mps2-an505` (code at 0x10000000, RAM at 0x38000000) with the vector runner. Ceilings 64 KB flash and 8 KB stack; pins 25,720 B and 724 B (`m33f_*` in `cpp/embedded/lib.sh`). The M4F row and pins (7,712 B / 540 B) stay. Retro of loops 64 to 68 and the LESSONS trim. Jira AZ-3189 (In Testing).

## First actions of loop 69

0. CI of the loop 68 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read the `embedded-arm` job first (the new row), then `scaffold` and `ring`.
1. No retro is due (next after loop 73, or an incident).

## Owner input needed

- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; whether to close U24 in the C++ package.
- Whether to drop the M4F row (it stays as the small-part bar until you say).
- What the next loop is: with the budgets chip-scale, byte-shaving of the C++ core has no consumer.

## Candidates (not specs yet)

- A Cortex-M33F build of the Rust embedded stage (it still builds for M4F with a 512 B stack figure).
- A non-secure (TrustZone) image with 128 KiB of RAM on `mps2-an505`, to check the part's smaller RAM view.
- Unchanged: Go window floor of 10 s; `item` pointer removal; `session_core` clippy; ring driver for `nostd`.

## Risks

- **L68-1**: QEMU `mps2-an505` is not the part: a green row proves architecture and byte figures, not the memory map, TrustZone partitioning or timing.
- **L68-2**: `cpp-m33f` compares its packet with `m3-all-kinds.hex` written by `cpp-m3-qemu`; a single-row run needs that file in the results folder.
- A new row of the arm stage is five edits (`run.sh`, `arm.sh`, `run-parts.test.sh`, every stub block and count in `lib.test.sh`, notes); see `AGENT_GOTCHAS.md`.
- The `covers()` rule marks the whole publish gate as RUN when a file is added under `cpp/embedded/`: about 6 to 10 minutes of step 11 on a quiet host.
- A wall-clock heartbeat counts laptop sleep and DST changes: read the share logs' own end lines before calling a long gate a stall.
- Host `cpp/build/` can hold ELF objects after a `gcc:16` run: `make -C cpp clean` before a Mac `make test`.
