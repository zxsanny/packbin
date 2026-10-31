# Acceptance criteria - arm-no-text-no-ecc-run

Inherits the ACs of AZ-2656 (`PACKBIN_NO_TEXT`, no codec linked), AZ-2688 (`PACKBIN_NO_ECC`, no message error correction linked), AZ-3189 (`cpp-m33f` machine, flags, link checks) and AZ-3469 (128 KiB window) unchanged. Baseline figures are read from a run on HEAD at the start of the implement step (log lines kept in the batch report), not copied from an earlier loop.

**AC-1 Both flags run on the M33F.** Given the arm stage, when it runs, then the core sources built with `-DPACKBIN_NO_TEXT -DPACKBIN_NO_ECC` for `cortex-m33` (hard float, `fpv5-sp-d16`) with the stage flags link into an image that runs on QEMU `mps2-an505` and ends with `FAILURES 0`, the compile and link warning count is 0, and the run takes no more than the stage's 300 s limit.

**AC-2 The run checks something.** Given that image, when it runs, then at least one check of each kind is executed and counted, and the run prints the number of assert sites run per source file; the count of sites run equals the count of `expect(` calls in each source (the rule `check_vectors` applies to the vector runner). The kinds are: (a) a scheme without string and parity fields packs, unpacks and repacks to the same bytes; (b) a string held as `Packed` is read around, skipped by its count and forwarded as it is, with no codec; (c) a scheme that declares parity bytes is refused at construction (the `PACKBIN_NO_ECC` contract).

**AC-3 Link checks on the reduced image.** Given the linked reduced image, when `image_checks` and the RAM-window check run, then `__cxa_throw` and `__cxa_allocate_exception` count 0, OS random references count 0 and the stack top equals the end of the 128 KiB window (`m33f_ram_end`); and given its core objects, when `check-objects.sh` reads them, then none references an allocator (`malloc`, `calloc`, `realloc`, `operator new`) or the exception runtime. The heap check reads the core objects, not the image, because the image links newlib stdio for the tests' output (the same exemption `vectors.elf` has); there is no `WRAPPER_CALLS` line for this image.

**AC-4 No codec, no parity in the image.** Given the linked reduced image, when its symbols and the core objects are read, then the codec and message error correction symbols that `tests/core/check-objects.sh --no-text --no-ecc` names count 0 in the image, and the core objects' `.data` plus `.bss` is 0 B.

**AC-5 The step goes red when it should.** Given scratch copies of the repository, when each of these is applied, then the stage fails with a message naming the cause, and the same stage passes on the unchanged tree: (a) one expected value in the reduced test changed (a check fails: `FAILURES` above 0 or sites run differ from asserted); (b) a heap call (`malloc`) added to a core source (the core objects reference an allocator); (c) the core objects of the reduced image built without `-DPACKBIN_NO_TEXT` (a codec symbol found, AC-4).

**AC-6 Other rows unchanged.** Given the change, when the arm and Rust embedded stages run, then the M0+, M3, M33F, s390x, AVR and Rust M33F rows show the figures of the baseline run (M33F: 315 of 315 vectors, flash 25,760 B, stack 724 B, frame 8,416 B / 912 B; Rust pins of `limits-m33f.txt`), and nothing under `cpp/src`, `cpp/include` or `rust/src` changes.

**AC-7 Stage time.** Given the baseline arm stage time and the time with the new step, both measured on the same host in the same loop, then the new step adds no more than 60 s.

**AC-8 Stage tests follow.** Given the change, when `bash cpp/embedded/lib.test.sh`, `bash cpp/embedded/run-parts.test.sh` and `bash rust/embedded/checks.test.sh` run, then all pass; if the row table gained a row, both stage tests name it; if the step sits inside an existing row, neither test changes.

**AC-9 Words match.** Given the change, then no sentence in the README, `_docs/AGENT_GOTCHAS.md`, the scripts' comments, `.github/workflows/test.yml` and `scripts/loop-tests.sh` says the string-free, ECC-free build has no ARM run (the loop 94 sentence in `AGENT_GOTCHAS.md` is corrected to say it runs on the M33F, run-only), and the living docs under `_docs/02_document` that describe the arm stage are corrected in the update-docs step; dated history (`_docs/loops/`, retros, `done/`, `LESSONS.md`) is out of scope.

**AC-10 One CI-shaped run.** Given the change, when `scripts/loop-tests.sh --only cpp-embedded-arm` runs, then it passes with 0 failed.

## Out of scope

- A flash or stack pin or budget for the reduced image (owner, 2026-10-31: run-only).
- A Cortex-M4F, TrustZone non-secure or hardware run.
- Any change to the host `no-text-test`, `no-ecc-test` and `object-check` targets, the Uno build or the AVR `chacha20` run.
- Any change under `cpp/src`, `cpp/include`, `rust/src` (a defect the new run finds there is a separate ticket).
