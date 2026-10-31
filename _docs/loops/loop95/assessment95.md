# Feature assessment - loop 95

FEATURE ASSESSMENT loop 95 round 1: COMPLETE - 7 covered / 1 out-of-scope / 0 gap-clear / 0 gap-unclear

Intent: owner picked the ARM run of the string-free, ECC-free build for loop 95: core Cortex-M33F, run-only, place the arm test stage and docs. Baseline: `_docs/02_task_plans/arm-no-text-no-ecc-run/` (`problem.md`, `acceptance_criteria.md`, `scenarios.md`), spec `AZ-3483`.

| id | status | AC | test | code path |
|----|--------|----|------|-----------|
| S1 first run, no edit | covered | AC-1, AC-2, AC-6 | arm stage run (batch report) | `m33f_small_image` in `cpp/embedded/arm.sh` |
| S2 heap or exception in the packet-only path | covered | AC-3, AC-5 | scratch (b): `malloc` in `values.cpp` fails the row | `check-objects.sh` via `NM`/`SIZE` |
| S3 codec pulled into the NO_TEXT build | covered | AC-4, AC-5 | scratch (c) | `check-objects.sh --no-text` |
| S4 packing or Packed forwarding breaks | covered | AC-2, AC-5 | scratch (a) | `no_text_tests.cpp`, `no_ecc_tests.cpp` on the device |
| S5 parity accepted in the NO_ECC build | covered | AC-2 | `parity_above_zero_is_refused` runs on the device (asserted = run) | `no_ecc_tests.cpp` |
| S6 reduced image grows | out-of-scope | - | run-only, owner choice | - |
| S7 QEMU or toolchain missing, hang | covered | AC-1 | same `qemu_run` and `fail` path as the other M33F images; 300 s `timeout` | `qemu_run` |
| S8 host and Uno builds | covered | AC-6 | `make object-check` in `gcc:16` passes; Uno row PASS | `cpp/Makefile`, `target_avr_uno` |

No `Discovered during implementation` row is unclear (batch report). `scenarios.md` unchanged.
