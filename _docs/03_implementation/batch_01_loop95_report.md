# Batch 1 loop 95 - AZ-3483 run the string-free, ECC-free build on a Cortex-M33F

Commit 4316bff. Parent alone (no workers). Review: code-review (low), 0 findings. CI-parity: PASS (`docker compose run cpp-embedded` = the CI arm stage; `make object-check` in `gcc:16` for the edited `check-objects.sh`).

## Result

| AC | Evidence |
|----|----------|
| AC-1 | arm stage run: the new step ends `FAILURES 0`, 0 compile and link warnings, `qemu mps2-an505 exit 0` |
| AC-2 | `small no_text_tests.cpp asserted=25 run=25`, `small no_ecc_tests.cpp asserted=6 run=6`; the host tests cover the three kinds |
| AC-3 | `small: __cxa_throw=0 __cxa_allocate_exception=0 heap_symbols=1 os_rng_symbols=0 dev_urandom=0` (the 1 is newlib stdio, `vectors.elf` has the same); stack top checked; `object-check` on the 5 core objects: no allocator, no exception runtime. AC text amended: the heap check reads the core objects |
| AC-4 | `object-check --no-text` and `--no-ecc` on the M33F core objects: 5 objects clean each, data+bss 0 |
| AC-5 | scratch copies: (a) changed expected value: `FAIL: n = 0 packs the 13-byte fixture without the codec`, `failures on M33F`; (b) `malloc` in `values.cpp`: `core-values.o references an allocator or the exception runtime`; (c) core built without `-DPACKBIN_NO_TEXT`: `core-pack.o`, `core-unpack.o` hold a codec table or symbol; unchanged copy passes. (b) moved from the image to a core source |
| AC-6 | baseline 16 s and after: cpp-m0plus, cpp-m3-qemu, cpp-m33f (315 of 315, 25,760 B, 724 B, 8,416 B / 912 B), cpp-s390x, cpp-avr-uno PASS; `git diff` touches nothing under cpp/src, cpp/include, rust/src |
| AC-7 | arm stage 16 s before, 18 s after (+2 s) |
| AC-8 | `lib.test.sh`, `run-parts.test.sh`, `rust/embedded/checks.test.sh` pass; the row table did not change |
| AC-9 | README, AGENT_GOTCHAS, `blackbox-tests-06-embedded.md` (FT-E-16), `components/05_cpp_package/description.md` |
| AC-10 | see the test-run report of this loop |

## Discovered during implementation

| scenario or question | spec ref | proposed handling | clear / unclear |
|----------------------|----------|-------------------|-----------------|
| both host tests compile with both flags together | Risk 1 | they do; no fallback needed | clear |
| the image links newlib stdio and shows one heap symbol | Risk 2 | heap check on the core objects; `check-objects.sh` takes `NM` and `SIZE` | clear |
| a `malloc` seeded in `values.cpp` also fails the later AVR row (no `<cstdlib>`) | AC-5 (b) | expected side effect of the seed, not a defect | clear |
| `release_notes_0.4.0.md` is modified in the tree, not by this loop | - | left uncommitted | clear |
