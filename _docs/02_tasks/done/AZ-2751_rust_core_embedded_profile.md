---
loop: 50
branch: dev
---

# Rust core: embedded profile CI

**Task**: AZ-2751_rust_core_embedded_profile
**Name**: Rust core: embedded profile CI
**Description**: A CI job builds the core for `thumbv7em-none-eabihf`, decodes the golden fixture on the device image under QEMU, reports flash and stack per feature set against owner limits, and fails when a heap symbol or a panic path is linked into decode.
**Complexity**: 5 points
**Dependencies**: AZ-2749
**Component**: rust (core)
**Tracker**: AZ-2751
**Epic**: AZ-2750

## Problem

The core is only proven heap-free when a real Cortex-M4F image links and runs. The C++ core has such a job (`embedded-arm`: QEMU mps2 image, semihosting, stack meter, budgets 8,192 B flash and 512 B stack). The Rust core has none, so a heap call or a panic path could slip in unseen.

## Outcome

- A Rust static library for the target, linked into the existing QEMU image (card 3), with `panic = "abort"`.
- The golden fixture decoded on the device image; flash and stack printed per feature set.
- A heap-symbol check and a panic-path check on the decode objects, each proven to fail on a seeded mutant.
- Owner limits in one file; the job fails above them.

## Scope

### Included
- The target and toolchain step in CI (after the owner approves the download), the build recipe, the QEMU run reusing the C++ startup, linker script and stack meter, the size report, the limits file, the two link checks with mutant tests, and the CI job guards (`publish-jobs.test.sh`, wiring tests) that list job names.

### Excluded
- New field kinds; hardware cycle counts (meshbell PB-10); the ESP32 target (no stable Rust target here); anything under `cpp/src` or `cpp/include`.

## Acceptance Criteria

**AC-1: Device build and run (R12, original AC-1 device half)**
Given the core with `default-features = false`
When it is built for `thumbv7em-none-eabihf` and run under QEMU
Then it links without `std` and without an allocator, decodes the golden fixture on the 32-bit device image, and the printed values match the fixture

**AC-2: Sizes published (original AC-3)**
Given the feature sets (base, `text`, `ecc`, `session`, all)
When the job runs
Then flash and stack figures are printed for each and kept in the job log

**AC-3: Over the limits (R13)**
Given a limits file and a build above a limit (a seeded mutant)
When the job runs
Then it fails and prints the figure and the limit

**AC-4: Heap symbol**
Given the decode objects
When the check looks for `__rust_alloc`, `alloc::`, `malloc` and `free`
Then none is found; a seeded mutant that allocates makes the check fail

**AC-5: Panic path (original AC-2, link half)**
Given the decode objects
When the check looks for `core::panicking`, `unwrap_failed`, `slice_index` and `rust_begin_unwind` reachable from decode
Then none is reachable; a seeded mutant with `unwrap` makes the check fail

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | QEMU run of the golden fixture | values printed equal the fixture |
| AC-2 | size report for each feature set | a flash and a stack figure for each of the five |
| AC-3 | build with a limit lowered by one byte | job fails with the figure |
| AC-4 | mutant with a `Vec` | check fails |
| AC-5 | mutant with `unwrap` on input | check fails |

## Constraints

- Wire bytes do not change (wire-stability policy); the std API and its tests are untouched.
- Fit decisions of `_docs/02_task_plans/rust-nostd-core/feature-description.md`: the caller's row is read and written through a `Row` trait by field id (card 1); a scheme is a plain `&[Field]` slice, so host tests can build it at runtime (card 2); any format change changes the std walker and the core walker in one task and the differential test covers both (card 4).
- No `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes; lengths use checked or saturating operations.
- Source file length soft cap 500 lines; tests follow AAA; no verbose logs.
- Needs the rustup component `thumbv7em-none-eabihf` (download); ask the owner before it is installed locally.

## Risks & Mitigation

**Risk 1: Stack measurement of a Rust image is unproven here**
- *Mitigation*: card 3: the C++ stack meter and startup are reused; if a Rust static library cannot link there, stop and report (no stand-in measure)

**Risk 2: The target is not installed on this Mac or in CI**
- *Mitigation*: the rustup target download is asked for before it runs

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The first estimate of 5 points covered the whole feature; the slices sum to 34 points | owner (scope per loop) | accepted-risk | Medium |
