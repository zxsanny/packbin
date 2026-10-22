# Batch 01 report — loop 58

Tasks: AZ-3160 (Rust nostd corpus count), AZ-3161 (Go refusal check ids), AZ-3162 (C++ dict key order). All test-only, disjoint files, done by the parent. Review: one total review at the end of the loop (owner rule). CI-parity: PASS (host `make -C cpp clean && make -C cpp test`, `gcc:16 make test`; Go `golang:1.27` gofmt, vet, `-race -count=1`; Rust `rustfmt --check` and the CI line `cargo test --features text,ecc --test nostd_dict_tests --test nostd_text_differential_tests --test nostd_hostile_tests --test nostd_hostile_pack_tests`); the full CI mirror is the one step 11 run.

## Results

| Task | Status | Evidence |
|------|--------|----------|
| AZ-3160 | Done | `listed_inputs()` counts three-field lines with a hex last field; loader copy that drops letter-led lines fails `lists 33 inputs, the loader read 0`; corpus copy with one extra line passes (34 = 34) |
| AZ-3161 | Done | broken `hostileRefusals` copy (one id removed, one invented) fails with the idDifference message naming both ids; Go suite passes in `golang:1.27` (71 s) |
| AZ-3162 | Done | `pack_orders_keys_as_unsigned_bytes`: 7 checks pass on the real source; scratch `pack.cpp` with signed compare fails 2 checks, with length-first compare fails `ab then b`; host and `gcc:16` suites pass |

Library source untouched (`git diff` lists only `cpp/tests`, `go/*_test.go`, `rust/tests`), so the arm stage figures (flash 8,032 B, stack 504 B deepest, margin 8 B) stay as in loop 57; the arm embedded stage is not re-run in this batch.

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear / unclear |
|----------|-----------|-------------------|-----------------|
| AZ-3160 | The nostd `corpus()` loader and the new count still live in one file; the count rule (three fields, hex last) would also accept a comment line shaped like that | accepted: the header comment has more fields | clear |
| AZ-3162 | `make -C cpp test` on the Mac fails `object-check` when `cpp/build` holds ELF objects from a container run (known gotcha); `make -C cpp clean` first | gotcha already recorded | clear |

## Commands

Scratch variants under the session scratchpad: `signed/pack.cpp`, `lenfirst/pack.cpp` built with the host-test file list and `-Isrc/core`. Rust broken loader and extra corpus line applied in place and restored (`git status` shows only the three test files).
