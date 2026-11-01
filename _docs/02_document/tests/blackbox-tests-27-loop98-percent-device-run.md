# Blackbox Tests 27: the percentage on the device images (loop 98, FT-E-17, FT-E-18)

Embedded stage scenarios for AZ-3525 and AZ-3526. Spec ids in the tasks; scenario map in `_docs/02_task_plans/percent-docs-and-embedded-run/scenarios.md`.

## FT-E-17: the C++ vector runner runs the percentage test (AZ-3525)

| Item | Value |
|------|-------|
| Input | `cpp/tests/core/ecc_percent_tests.cpp` in `VECTOR_TESTS`, run by `vectors_main.cpp` on QEMU `mps2-an385` (Cortex-M3), `mps2-an505` (Cortex-M33F) and the s390x image; rows verbatim from `fixtures/ecc/percent-vectors.txt` |
| Expected | 13 cases, 25 checks, FAILURES 0, `vectors run 340 asserted 340` (was 315); 12 `PERCENT_HEX` packets identical on M3 and M33F (`arm.sh` compares `m3-percent.hex` with `m33f-percent.hex`); p 1, 10, 25, 50, 100 on 40 and 13 clear bytes; p 0 equals no parity; p 101 refused with `SchemeInvalid` naming 100; limit 16 lowered to n / 2 (repaired 5 of n 10; 1 of n 2), one wrong byte more is `Uncorrectable`; limit 17 and -1 are `BadValue` |
| Mutation | the rounding `+ 99u` changed to `+ 0u` in `codec_ecc.hpp` fails M3 (exit 6), M33F (exit 6) and s390x; reverted |
| Pins | the new test is only in `vectors.elf` (no pin); C++ all-kinds image 25,948 B / 740 B and frame image 8,416 B / 912 B unchanged |
| Run by | the AZ-3525 worker and the parent (`docker compose -f docker-compose.test.yml run --rm cpp-embedded`; `make -C cpp test` all passed) |

## FT-E-18: the Rust ecc probe runs the percentage (AZ-3526)

| Item | Value |
|------|-------|
| Input | `rust/embedded/probe/src/ecc_extra.rs`: a 13-byte position message under 25 % and 50 % (`with_parity_percent`), pack, damage n / 2 bytes, `unpack_repair` with limit 16, clear values compared; the `rust-m33f` row on QEMU `mps2-an505` (the M4F row was dropped in loop 94) |
| Expected | pack length 17 and 20 (4 and 7 parity bytes, rounded up); repaired 2 and 3; `EXTRA_RESULT 0`, FAILURES 0; the count round trip still 0; ecc set 19,996 B flash and 664 B stack (was 19,140 B and 752 B; owner agreed to the re-pin, 2026-11-01); base 15,132 / 456, text 27,268 / 2,736, frame 20,404 / 1,728 unchanged |
| Mutation | `saturating_add(99)` changed to `saturating_add(0)` in `rust/src/ecc_core.rs` gives `EXTRA_RESULT 350` (wrong parity count at 25 %); reverted |
| Run by | the parent (`rust/embedded/run.sh libs`, then `docker compose -f docker-compose.test.yml run --rm rust-embedded`; `rust/embedded/checks.test.sh`) |
