---
loop: 94
branch: dev
---

# Drop the Cortex-M4F rows from the arm stage

**Task**: AZ-3479_drop_m4f_rows
**Name**: Drop the Cortex-M4F rows from the arm stage
**Description**: Remove the C++ row `cpp-m4f` and the Rust row `rust-m4f` from the embedded stage, with their budgets, pins, helpers, tests and wording; the M33F rows become the small-part bar.
**Complexity**: 3 points
**Dependencies**: None (AZ-3189, AZ-3231 and AZ-3469 shipped)
**Component**: cpp embedded stage (`cpp/embedded`), Rust embedded stage (`rust/embedded`), CI step names and the docs that quote the M4F figures
**Tracker**: AZ-3479
**Epic**: none

## Problem

The owner's target part is the nRF54L15 (Cortex-M33F). The stage still holds the C++ core to a Cortex-M4F small-part bar (8,192 B flash, 2,048 B stack, pins 7,712 B and 540 B in `cpp-m4f`) and runs the Rust API on a Cortex-M4F (`rust-m4f`). No target part needs that bar. The rows cost stage time and exact pins, and they gate edits of the core that no part would notice. `rust-m33f` also depends on them: it compares each set's route packet with the `rust-m4f` run and fails when that run is missing.

## Outcome

- `cpp-m4f` and `rust-m4f` are gone from the row tables, the report, the stage tests, the CI step names and the docs that quote their figures.
- The budgets, pins and helpers only they used are gone.
- `rust-m33f` and `rust-mutants` run without them; the other rows keep their figures.

## Scope

### Included
- `cpp/embedded`: the `cpp-m4f` row in `run.sh`, `target_m4f`, `max_frame`, `arm_no_text_core_objects`, `arm/size_main.cpp` and the `flash_budget`, `stack_budget`, `flash_pin`, `stack_pin` variables in `lib.sh`; the row names in `lib.test.sh` and `run-parts.test.sh`; the header of `arm/mps2.ld`.
- `rust/embedded`: `rust-m4f` and `target_rust_m4f`, the route-packet comparison (`rust_same_as`), the Cortex-M4F defaults of the shared helpers, the seeded-probe build and link of `rust-mutants` moved to `thumbv8m.main-none-eabihf`, `limits.txt` merged into `limits-m33f.txt` (or kept as the one limits file), README and probe description.
- Step names and `rustup target add` in `.github/workflows/test.yml`, the comment in `scripts/loop-tests.sh`, comments in `cpp/Makefile` and `cpp/CMakeLists.txt` that name the M4F as a current bar.
- README sentences that name the M4F row or quote its figures as current; `_docs/AGENT_GOTCHAS.md` M4F lines condensed to one line saying the rows were dropped in loop 94 and the M33F pins are the bar.
- Living docs under `_docs/02_document` that describe the stage today (list in `_docs/02_task_plans/drop-m4f-rows/acceptance_criteria.md` AC-7), in the update-docs step.

### Excluded
- Any change under `cpp/src`, `cpp/include`, `rust/src`; measurement comments in `cpp/src` and `cpp/tests` that were true when written.
- The `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC` options and their host tests and Uno example (they stay).
- The M0+, M3, M33F, s390x and AVR rows' behavior, and the pins of `limits-m33f.txt`.
- Dated history (changelog paragraphs of past releases, `_docs/LESSONS.md`, loop records, finished task specs, retros, loop-dated test docs).
- A replacement small-part bar (the owner chose to drop it).

## Acceptance Criteria

Full wording with the baseline rule is in `_docs/02_task_plans/drop-m4f-rows/acceptance_criteria.md`; the list below is the task's contract.

**AC-1: Rows gone**
Given the change
When `cpp/embedded/run.sh` and `rust/embedded/run.sh` list their rows and the report CSV is written
Then neither table nor the CSV has `cpp-m4f` or `rust-m4f`, and `cpp-m0plus`, `cpp-m3-qemu`, `cpp-m33f`, `cpp-s390x`, `cpp-avr-uno`, `rust-m33f` and `rust-mutants` are still listed

**AC-2: No reader left, nothing still read removed**
Given the change
When `git grep` runs for `target_m4f`, `target_rust_m4f`, `flash_budget`, `stack_budget`, `flash_pin`, `stack_pin`, `size_main`, `arm_no_text_core_objects`, `max_frame`, `rust_same_as`, `thumbv7em`, `mps2-an386` and `build/rust-m4f` in the scripts, tests, workflows and compose files
Then each has 0 hits (or is a helper a remaining row still calls, named in the batch report), and every remaining row passes

**AC-3: Rust M33F without the M4F reference**
Given `rust-m33f` run alone with no `rust-m4f` log in the results folder
When it runs
Then each of base, text, ecc and frame links, runs, decodes the golden fixture (`GOLDEN_OK 1`), unpacks the sample route on the device (`FAILURES 0`) and shows the flash and stack of `limits-m33f.txt` (15,132/456, 27,268/2,736, 18,764/744, 20,404/1,728); the route-packet comparison is removed

**AC-4: Mutants on the M33F**
Given `rust-mutants` built for `thumbv8m.main-none-eabihf` and linked with the M33F script
When the seeded panic probe and the seeded heap probe are linked
Then the panic check and the heap check each report the seeded symbol; with the clean probe in place of the seeded one (scratch copy) the row fails

**AC-5: Figures unchanged**
Given a baseline run on HEAD at the start of the implement step
When the arm and Rust embedded stages run after the change
Then the M0+, M3, M33F, s390x, AVR and Rust M33F rows show the baseline figures (M33F 315 of 315 vectors, flash 25,760 B, stack 724 B, frame 8,416 B and 912 B), 0 compile warnings, and no file under `cpp/src`, `cpp/include` or `rust/src` changed

**AC-6: Stage tests follow**
Given the change
When `bash cpp/embedded/lib.test.sh`, `bash cpp/embedded/run-parts.test.sh` and `bash rust/embedded/checks.test.sh` run
Then all pass; no case names `cpp-m4f`, and the failing-pipeline and errexit cases still run against a row that exists

**AC-7: Words match**
Given the README, `_docs/AGENT_GOTCHAS.md`, `rust/embedded/README.md`, script and build comments, `.github/workflows/test.yml`, `scripts/loop-tests.sh` and the living docs of AC-7 in the plan folder
When read after the change
Then none says a Cortex-M4F row exists or quotes its figures as current, the present-tense Rust frame figures in the README are the M33F ones (20,404 B and 1,728 B), the CI step names say Cortex-M33F, and `rustup target add` lists only `thumbv8m.main-none-eabihf`

**AC-8: One CI-shaped run**
Given the change
When `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded` runs
Then it passes with 0 failed

## Non-Functional Requirements

**Performance**
- The arm stage gets shorter (the M4F row builds a second set of core objects); the stage time before and after is written in the record. No rule on the size of the gain.

**Compatibility**
- The published packages are untouched; only the test stage, the CI job and docs change.

**Reliability**
- Deterministic; no new row, no new file except what a merge of the limits files needs.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-6 | `cpp/embedded/lib.test.sh` stubs and `run-parts.test.sh` row table without `cpp-m4f` | all cases pass against rows that exist |
| AC-6 | `rust/embedded/checks.test.sh` (panic and heap link checks) | passes unchanged |
| AC-2 | `git grep` of the removed names (E3 of the plan's expected results) | 0 hits outside the allowed history |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-5 | HEAD baseline run first, then after the change | `bash cpp/embedded/run.sh host arm` | rows as E1; baseline figures | none |
| AC-1, AC-3, AC-5 | no `rust-m4f` log | `docker compose -f docker-compose.test.yml run --rm rust-embedded` | rows as E2 | none |
| AC-4 | scratch copy with the seeded panic probe replaced by the clean one | `rust-mutants` | row FAIL with "found nothing" message | none |
| AC-8 | clean tree | `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded` | 0 failed | none |

## Constraints

- One canonical path: the Rust M33F row keeps its own helpers (`rust_row`, `check_ram_end`); do not add a second comparison mechanism in place of `rust_same_as`.
- The rows have no `PACKBIN_NO_ECC`/`NO_TEXT` ARM run after this change; host and Uno builds remain.
- Rust 1.98 toolchain figures (pins of `limits-m33f.txt`) are the reference; build libs with `PACKBIN_EMBEDDED_RUST`.

## Risks & Mitigation

**Risk 1: A helper another row reads is removed with the M4F row**
- *Risk*: `arm.sh` and `lib.sh` helpers are shared by sourcing; a removed variable breaks `cpp-m33f`, `rust-m33f` or the Uno row.
- *Mitigation*: AC-2 requires a `git grep` of every removed name and the full arm and Rust stage run (AC-5, AC-8).

**Risk 2: The mutants row no longer proves what it did**
- *Risk*: the seeded probes are rebuilt for a different target; a link check that silently sees nothing would pass.
- *Mitigation*: AC-4 shows the row failing with the clean probe in place of the seeded one.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| The only ARM run of the `PACKBIN_NO_TEXT` + `PACKBIN_NO_ECC` build and its 8 KB flash bar go with the row | owner chose to drop both rows knowing the target part is the M33F (2026-10-31); host and Uno builds of the same configuration stay | accepted-risk | Medium |
| Rust route packet is no longer compared across targets | the device unpack of the sample and the golden decode stay; owner not asked separately (simplest option, recorded in `scenarios.md`) | accepted-risk | Low |
