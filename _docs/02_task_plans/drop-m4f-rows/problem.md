---
loop: 94
branch: dev
---

# Drop the Cortex-M4F rows from the arm stage

## Problem

The owner's target part is the nRF54L15 (Cortex-M33F, 128 KiB of RAM in a non-secure image, about 1.5 MB of NVM). The embedded stage still has two Cortex-M4F rows from before that target was chosen:

- `cpp-m4f` (`target_m4f` in `cpp/embedded/arm.sh`) builds the core with `PACKBIN_NO_ECC` and a string-free size probe with `PACKBIN_NO_TEXT`, and holds it to the small-part bar: 8,192 B flash and 2,048 B stack (`flash_budget`, `stack_budget` in `cpp/embedded/lib.sh`), pinned at 7,712 B and 540 B (`flash_pin`, `stack_pin`).
- `rust-m4f` (`target_rust_m4f` in `rust/embedded/target.sh`) links and runs the four Rust feature sets on a Cortex-M4F, held by `rust/embedded/limits.txt`.

No target part needs the M4F bar any more (`_docs/AGENT_GOTCHAS.md`: "the Cortex-M4F row stays as the small-part bar until the owner drops it"). The rows cost stage time and an exact pin to maintain, and they gate edits of `cpp/src/core` that no part would notice.

## Outcome

- `cpp-m4f` and `rust-m4f` no longer exist: not in the row tables of `cpp/embedded/run.sh` and `rust/embedded/run.sh`, not in the report, not in the tests that pin the row tables (`cpp/embedded/lib.test.sh`, `cpp/embedded/run-parts.test.sh`).
- The M4F-only budgets, pins and helpers are gone (`flash_budget`, `stack_budget`, `stack_pin`, `flash_pin`, `target_m4f`, the no-text core objects and size probe that only it used), and the sentences that quote the M4F figures are corrected (README, `AGENT_GOTCHAS.md`, `rust/embedded/README.md`, comments, the `embedded-arm` CI step name).
- `cpp-m0plus`, `cpp-m3-qemu`, `cpp-m33f`, `cpp-avr-uno` and `rust-m33f` still run with their figures unchanged (M33F: 315 of 315 vectors, flash 25,760 B, stack 724 B; Rust pins of `limits-m33f.txt`), and `rust-mutants` still rejects a seeded panic path and a seeded heap call.

## Origin

Candidate "the M4F row" from the loop 68 handoff, kept open through handoff 93 ("the M4F row" in the leftovers of `record93.md`). Owner picked it for loop 94 (2026-10-31, hopper empty) and chose to drop both M4F rows (C++ and Rust), place: the arm test stage and its docs.

## Change location

The embedded arm test stage and its docs (owner, 2026-10-31, verbal): `cpp/embedded/arm.sh`, `lib.sh`, `run.sh`, `lib.test.sh`, `run-parts.test.sh`; `rust/embedded/` (`run.sh`, `target.sh`, `limits.txt`, README); the `embedded-arm` step names in `.github/workflows/test.yml` and `scripts/loop-tests.sh`; the README and `_docs/AGENT_GOTCHAS.md` sentences about the M4F figures. No change under `cpp/src`, `cpp/include` or `rust/src`.

## Findings that shape the work (read on HEAD a65a2a0)

- `rust-m33f` takes `rust_same_as="$build/rust-m4f"` and fails when `rust-m4f` has not run: it compares each set's `ROUTE_HEX` with the M4F run. Without `rust-m4f` that reference is gone and needs a decision (AC-3).
- `rust-mutants` (`target_rust_mutants`) and `build_libs` link the seeded probes for `thumbv7em-none-eabihf`; with no M4F row they must build for `thumbv8m.main-none-eabihf`.
- `cpp-m33f` reads `m3-all-kinds.hex` from `cpp-m3-qemu`, not anything of the M4F row; `target_m33f` says it "reads and writes nothing of the M4F row".
- The `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC` builds stay covered on the host (`cpp/Makefile`: `no-text-test`, `no-ecc-test`, `object-check`) and on the Uno (`cpp-avr-uno` builds with both). What goes is their run on an ARM core.

## Not covered (stated limit)

Dropping the rows removes the only ARM run of the string-free, ECC-free build and the only gate on its flash and stack. A part with 8 KB of RAM or less is no longer a supported claim of the stage; the README must not still promise the M4F figures.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| The only ARM run of the `PACKBIN_NO_TEXT` + `PACKBIN_NO_ECC` build and its 8 KB flash bar go with the row | owner chose to drop both rows knowing the target part is the M33F (2026-10-31); host and Uno builds of the same configuration stay | accepted-risk | Medium |
