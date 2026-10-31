---
loop: 95
branch: dev
---

# Run the string-free, ECC-free C++ build on a Cortex-M33F

**Task**: AZ-3483_arm_no_text_no_ecc_run
**Name**: Run the string-free, ECC-free C++ build on a Cortex-M33F
**Description**: Add a run of the core built with `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC` on the Cortex-M33F to the arm test stage, run-only, with the stage's link checks.
**Complexity**: 3 points
**Dependencies**: None (AZ-3189, AZ-3469 and AZ-3479 shipped)
**Component**: cpp embedded stage (`cpp/embedded`), CI and docs wording about the reduced build
**Tracker**: AZ-3483
**Epic**: none

## Problem

A board that only carries packets builds the C++ core with no string codec and no message error correction. Since loop 94 dropped the Cortex-M4F row, that configuration is only built and run on the host (each flag alone) and linked, not run, for the Uno. A heap call, an exception, a data section or a wrong-width type added to it is caught only if it also breaks the host or Uno build.

## Outcome

- The arm stage runs a small image built from the core with both flags on, for the Cortex-M33F on QEMU `mps2-an505`, and fails when it fails.
- The image is held to the stage's link checks (no exception, no heap, no OS random reference, the 128 KiB window).
- Run-only: no new flash or stack pin, no new budget.

## Scope

### Included
- `cpp/embedded`: a step in the M33F target that builds the core objects with both flags, builds the two existing reduced-build host test sources unchanged for the M33F, links one small runner image, runs it on QEMU and checks the result; the runner source under `cpp/embedded/arm/`.
- The README, `_docs/AGENT_GOTCHAS.md` and script comments that say the reduced build has no ARM run; the living docs under `_docs/02_document` that describe the arm stage (update-docs step).

### Excluded
- Any change under `cpp/src`, `cpp/include`, `rust/src`; any change to the host `no-text-test`, `no-ecc-test`, `object-check` targets, the Uno build or the AVR `chacha20` run.
- A flash or stack pin or budget for the reduced image (owner choice).
- A Cortex-M4F, TrustZone non-secure or hardware run.

## Acceptance Criteria

Full wording with the baseline rule is in `_docs/02_task_plans/arm-no-text-no-ecc-run/acceptance_criteria.md`; the list below is the task's contract.

**AC-1: Both flags run on the M33F**
Given the arm stage
When it runs
Then the core built with both flags for `cortex-m33` links into an image that runs on QEMU `mps2-an505` and ends with `FAILURES 0`, with 0 compile and link warnings and inside the stage's 300 s limit

**AC-2: The run checks something**
Given that image
When it runs
Then the sites run per source file equal the `expect(` calls in that file, and the checks cover a scheme without string and parity fields (pack, unpack, repack equal), a `Packed` string read around and forwarded without the codec, and a scheme with parity bytes refused

**AC-3: Link checks on the reduced image**
Given the linked image and its core objects
When `image_checks`, the RAM-window check and `check-objects.sh` run
Then exception references and OS random references are 0, the stack top equals the 128 KiB window end, and no core object references an allocator or the exception runtime (the heap check reads the core objects because the image links newlib stdio for the tests' output)

**AC-4: No codec, no parity in the image**
Given the linked image and its core objects
When their symbols and sections are read
Then the codec and message-ECC symbols named by `tests/core/check-objects.sh` count 0 and the core objects' data plus bss is 0 B

**AC-5: The step goes red when it should**
Given scratch copies of the repository
When (a) one expected value in the reduced test is changed, (b) a `malloc` call is added to a core source, (c) the reduced core objects are built without `-DPACKBIN_NO_TEXT`
Then the stage fails each time with a message naming the cause, and passes on the unchanged tree

**AC-6: Other rows unchanged**
Given the change
When the arm and Rust embedded stages run
Then the M0+, M3, M33F, s390x, AVR and Rust M33F rows show the baseline figures (M33F: 315 of 315 vectors, flash 25,760 B, stack 724 B, frame 8,416 B / 912 B; Rust pins of `limits-m33f.txt`) and nothing under `cpp/src`, `cpp/include` or `rust/src` changes

**AC-7: Stage time**
Given the arm stage time before and after, measured on the same host
When compared
Then the new step adds at most 60 s

**AC-8: Stage tests follow**
Given the change
When `lib.test.sh`, `run-parts.test.sh` and `rust/embedded/checks.test.sh` run
Then all pass, and the two stage tests are unchanged because the row table is unchanged

**AC-9: Words match**
Given the change
Then no sentence in the README, `AGENT_GOTCHAS.md`, the scripts' comments, `.github/workflows/test.yml` or `scripts/loop-tests.sh` says the reduced build has no ARM run, and the living docs of the arm stage are corrected in the update-docs step

**AC-10: One CI-shaped run**
Given the change
When `scripts/loop-tests.sh --only cpp-embedded-arm` runs
Then it passes with 0 failed

## Non-Functional Requirements

**Performance**
- Added arm stage time at most 60 s (AC-7).

**Reliability**
- A missing QEMU or toolchain, or a hang, fails the step; no silent skip.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-2 | the two existing host tests (`no_text_tests.cpp`, `no_ecc_tests.cpp`) built with both flags | they run unchanged and every site runs |
| AC-8 | `lib.test.sh`, `run-parts.test.sh`, `rust/embedded/checks.test.sh` | all cases pass |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2, AC-3, AC-4, AC-6 | `bash cpp/embedded/run.sh host arm` | the M33F row with the new step | row PASS; reduced image `FAILURES 0`, link checks 0, baseline figures unchanged | stage time |
| AC-5 | scratch copies (a), (b), (c) | the arm stage | FAIL naming the cause each time | - |
| AC-7 | the stage before and after | wall time | added at most 60 s | stage time |
| AC-10 | `scripts/loop-tests.sh --only cpp-embedded-arm` | the CI-shaped run | `N passed, 0 failed` | - |

## Constraints

- The two host test sources are compiled unchanged; the runner renames their `main` with a compile definition. If either does not compile with both flags together, the batch report names it and the task stops for a decision (one flag per image is the fallback, owner call).
- The step reuses the existing M33F helpers and the AN505 linker script; no new linker script or startup file.
- `cpp/embedded/arm.sh` stays under 500 lines or the new step moves to its own sourced file.

## Risks & Mitigation

**Risk 1: A host test does not build with both flags**
- *Risk*: `no_text_tests.cpp` or `no_ecc_tests.cpp` may rely on the other feature being on.
- *Mitigation*: try the compile first in the batch; the fallback is one image per flag.

**Risk 2: The semihosting printf of the test files pulls the heap**
- *Risk*: `printf` and `puts` in the host tests link newlib stdio, which references the allocator (the image shows `heap_symbols=1`, as `vectors.elf` does; `vectors.elf` is exempt from the image heap check).
- *Mitigation*: the heap and exception checks read the core objects (`check-objects.sh`), where an allocator reference is an undefined symbol; resolved in the batch (see the batch report).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Run-only: the reduced image's flash and stack are not pinned | owner chose run-only on 2026-10-31 | accepted-risk | Low |
| Stage time grows by one core rebuild and one QEMU run | measure before and after (AC-7) | open | Low |
| The heap check cannot apply to an image with newlib stdio (Risk 2) | applied to the core objects instead; image carries 1 stdio heap symbol like `vectors.elf` | resolved | Low |
