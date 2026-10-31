---
loop: 95
branch: dev
---

# Run the string-free, ECC-free C++ build on a Cortex-M33F

## Problem

A board that only carries packets builds the C++ core with `-DPACKBIN_NO_TEXT -DPACKBIN_NO_ECC` (no string codec, no message error correction; `README.md` "Strings without the codec: `Packed` and `PACKBIN_NO_TEXT`", the Uno example `cpp/examples/avr_uno`). Until loop 94 the Cortex-M4F row `cpp-m4f` built and ran that configuration on an ARM core under QEMU (the size probe with `PACKBIN_NO_TEXT`, the all-kinds image with `PACKBIN_NO_ECC`). Loop 94 (AZ-3479) dropped that row, so the configuration now has only:

- host builds and tests, each flag on its own: `make -C cpp no-text-test no-ecc-test object-check` (`cpp/Makefile`, `tests/core/no_text_tests.cpp`, `tests/core/no_ecc_tests.cpp`), and
- an AVR build of both flags together that is linked but not run (`target_avr_uno` in `cpp/embedded/arm.sh`); the one AVR image that runs under `simavr` is `chacha20_check`.

No test builds **both flags together** and runs it on a 32-bit ARM core. A change that adds a heap call, an exception, a data section or a wrong-width type to the reduced build is caught by CI only if it also breaks the host or Uno build.

## Outcome

The arm test stage links the core with both flags on for the Cortex-M33F (the nRF54L15 core) and runs a small image on QEMU `mps2-an505`: a scheme without a string field and without parity packs, unpacks and repacks to the same bytes, and the reduced-build host tests' checks run on the device. The image passes the stage's existing link checks (no exception, no heap, no OS random reference). Run-only: no new flash or stack pin and no new budget (owner, 2026-10-31).

## Origin

Leftover of loop 94 (`record94.md`: "the string-free, ECC-free build has no ARM run any more; accepted-risk, Medium"). Owner picked it for loop 95 (2026-10-31, hopper empty) from the handoff candidates, with: core Cortex-M33F, run-only check.

## Change location

The embedded arm test stage and its docs (owner, 2026-10-31, verbal): `cpp/embedded/arm.sh` (a new step or row beside `cpp-m33f`), with `lib.sh`, `run.sh`, `lib.test.sh`, `run-parts.test.sh` only if the row table changes; the `embedded-arm` CI step names in `.github/workflows/test.yml` and `scripts/loop-tests.sh` only if they name rows; the README and `_docs/AGENT_GOTCHAS.md` sentences that say the reduced build has no ARM run. No change under `cpp/src`, `cpp/include` or `rust/src`.

## Findings that shape the work (read on HEAD 83e1878)

- `all_kinds.cpp`, `ac2_main.cpp` and `vectors_main.cpp` use text and parity fields, so they do not compile with either flag. The reduced image needs its own scheme and entry point; the existing host tests `tests/core/no_text_tests.cpp` and `tests/core/no_ecc_tests.cpp` each carry `#error` unless exactly their own flag is set, so they cannot be linked into one both-flags image unchanged. Whether to reuse them as two images (one flag each) or add one both-flags test is a decision for `new-task`.
- `target_m33f` already has the M33F compile and link helpers (`arm_cxx`, `arm_link`, `image_checks`, `qemu_run`, `check_ram_end`) and the AN505 linker script; `arm_firmware_objects` builds the core with a flag list passed in, so the reduced core objects are the same call with `-DPACKBIN_NO_TEXT -DPACKBIN_NO_ECC`.
- The row table is pinned by `cpp/embedded/lib.test.sh` and `run-parts.test.sh` (`_docs/AGENT_GOTCHAS.md`: a new row needs both). A step inside `target_m33f` needs neither, at the cost of failure attribution to the `cpp-m33f` row.
- `check_objects` (`tests/core/check-objects.sh --no-text --no-ecc`) already holds the host objects of this build to "no codec symbol, no ECC table, no allocator, no writable data"; the ARM run adds the device-side proof that the same build links and executes.

## Not covered (stated limit)

- Flash and stack of the reduced build stay unbarred (run-only; owner choice). A growth in the reduced image's size is not caught.
- The run is QEMU `mps2-an505` (the stage's M33F machine), not a TrustZone non-secure image and not hardware.
- The string codec and message error correction are exercised on the M33F by the existing `cpp-m33f` row (whole core); this loop adds only the reduced configuration.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| Run-only: the reduced image's flash and stack are not pinned, so a size regression of the packet-only build is invisible to the stage | owner chose run-only on 2026-10-31; loop 94 removed the bars deliberately | accepted-risk | Low |
| Stage time grows by one core rebuild with the reduced flags plus one QEMU run (the arm stage was about 30 s with no M4F work) | measure on HEAD before and after in the batch report | open | Low |
