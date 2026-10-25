
# Rust embedded: Cortex-M33F row for the nRF54L15

**Task**: AZ-3231_rust_m33f_embedded_row
**Name**: Rust Cortex-M33F row with pins per feature set in the Rust embedded stage
**Description**: Add a `rust-m33f` row that builds the five feature sets of the Rust probe for `thumbv8m.main-none-eabihf`, runs them on QEMU `mps2-an505`, applies the heap, panic-path and static-RAM checks, and holds flash and stack to the chip-scale ceilings and to pins measured with the CI toolchain.
**Complexity**: 3 points
**Dependencies**: AZ-3189 (C++ M33F row, shipped), AZ-2751 (Rust embedded stage, shipped)
**Component**: Rust embedded harness (`rust/embedded`)
**Tracker**: AZ-3231
**Epic**: AZ-2750

## Problem

The Rust heap-free API (`packbin::nostd`) is proven only on a Cortex-M4F image. The owner's target part is the nRF54L15 (Cortex-M33F, 256 KB of RAM, about 1.5 MB of NVM, 128 KiB of RAM in a non-secure image); the C++ core has a `cpp-m33f` row since loop 68, the Rust side none. Nothing checks the Rust sets (text, ecc, session, frame) on the part's architecture or pins their size there.

## Outcome

- The Rust embedded stage has a `rust-m33f` row after `rust-m4f`: five sets built for `thumbv8m.main-none-eabihf`, linked into the C++ stage's image with the `mps2-an505` linker script, run on QEMU, checked for heap, panic path and static RAM, and measured.
- Flash and net stack per set are held to 64 KB / 8 KB and to pins measured on HEAD with Rust 1.98.
- The M4F row, its limits and the seeded-defect mutants stay as they are.

## Scope

### Included
- `rust/embedded/run.sh` (libraries for both targets), `rust/embedded/target.sh` (`target_rust_m33f`, shared helpers), `rust/embedded/limits-m33f.txt`, `rust/embedded/checks.sh` and `checks.test.sh` (limits check for the second file), `rust/.gitignore` (build folder), `.github/workflows/test.yml` (target install), `rust/embedded/README.md`.
- `_docs/AGENT_GOTCHAS.md`, the Rust description and `tests.md`.

### Excluded
- `rust/src`, `cpp/src/core`, `cpp/include`, other packages.
- Real hardware, TrustZone non-secure images, the RISC-V coprocessor, cycle timing.
- Dropping the M4F row; a M33F mutants row (the link checks read symbol names, not the architecture).

## Acceptance Criteria

See `_docs/02_task_plans/rust-m33f-row/acceptance_criteria.md` (AC-1 to AC-10).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-5, AC-8 | `checks.test.sh`: `unlimited_sets` on a made-up M33F limits file | lists a set without numbers, none for a full file |
| AC-8 | `run-parts.test.sh` and the publish-jobs tests that read `test.yml` | pass with the new step |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-5, AC-7 | HEAD with the change | `docker compose -f docker-compose.test.yml run --rm rust-embedded` after `run.sh libs` | `rust-m4f`, `rust-mutants`, `rust-m33f` pass; per-set figures within ceilings and pins | — |
| AC-6 | copy of the stage with a pin 1 B low | row fails naming figure, set and pin | — | — |
| AC-8 | pushed commit | `embedded-arm` job of `test.yml` | green; CI figures within the pins | — |

## Constraints

- Figures come from a run on HEAD in this loop with Rust 1.98 (CI's toolchain), pasted in the batch report; not from an earlier table.
- The stage runs in `packbin-embedded` (QEMU 8.2.2, GCC 13.2.1): code at 0x10000000, RAM at 0x38000000.
- Wait for host load below 6 before timing.

## Risks & Mitigation

**Risk 1: CI toolchain gives other figures than the local one**
- *Risk*: pins from a local run fail on CI (loop 69 saw +2 to 4% between Rust 1.79 and 1.98).
- *Mitigation*: build the pin run with 1.98; read the CI figure after the push; a gap is a named blocker.

**Risk 2: the AN505 machine differs from the part**
- *Mitigation*: ceilings leave a factor of 2 or more; the gap is recorded under `## Not walked`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Figures an AC names are read from a run on HEAD with the CI toolchain | AGENT_GOTCHAS | open until measured | Medium |
| Pins are exact measured figures, not measured plus 5% as the M4F limits | follows the AZ-3189 convention (owner, 2026-10-25) | accepted-risk | Low |
| QEMU is not the part | recorded under Not walked | accepted-risk | Low |
