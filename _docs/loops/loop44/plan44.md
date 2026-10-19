# Autodev Loop Plan — Loop 44

loop: 44
kind: product
confirmed: true
branch: dev
ship: false

Intake: owner (2026-10-19) took "accept all recommended" after loop 43: AZ-2068 (C++ AVR build, epic AZ-2059, the last open spec of that epic) and AZ-2728 (TypeScript hostile hang guard, epic AZ-2645, new ticket); `/feature-assess`, F44 and the first tags stay owner-run; the retrospective is not due (3 loops since loop 41) and the security report is from 2026-10-19; `main` fast-forward at close per `ci_cd_pipeline.md`.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | AZ-2068 in todo/; AZ-2728 written at intake |
| decompose-feature | 9.5 | Decompose Feature | no | 3 + 1 points |
| implement | 10 | Implement | yes | AZ-2068 (parent), AZ-2728 (one worker) |
| feature-assess | 10.5 | Feature Assessment | no | owner-run, carried |
| run-tests | 11 | Run Tests | yes | one run for the loop |
| test-spec-sync | 12 | Test-Spec Sync | no | no AC or scenario of the suite specs changes |
| update-docs | 13 | Update Docs | no | the C++ README target list and the gotcha line are inside AZ-2068 |
| security | 14 | Security Audit | no | no untrusted-input, release or secret path changes; report dated 2026-10-19 |
| performance | 15 | Performance Test | no | none |
| deploy | 16 | Deploy | no | ship: false |
| release | 16.5 | Release | no | no tag |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | not due; owner-run |
| local-deploy | — | Local deploy + open site | yes | none (library) |
| smoke | — | Smoke acceptance | yes | script in `smoke44.md` |

## Implementation
### Files that change
- AZ-2068 (parent): a new `cpp/include/packbin/platform.hpp`, the one place the core takes standard names from: hosted targets include `<cstddef>`, `<cstdint>`, `<cstring>`; avr-gcc (no C++ library) includes the C headers and names them in `std`. Hand-written traits and a fixed array in `packbin::detail` replace `<type_traits>` and `<array>` on every target (one path). Every core header and `src/core` file includes it instead of the standard headers; `scripts/text/emit_tables.py` emits the same include for `text_tables.hpp`. `offsetof(Field, eq)` asserted per target (loop 19 note). A new AVR target in the arm stage (`target_avr_uno` in `cpp/embedded/arm.sh`, a separate file would break the fake trees of `lib.test.sh`; `run.sh` table, the `run-parts.test.sh` oracle and the `lib.test.sh` fakes; the image gets `gcc-avr`, `avr-libc`, `binutils-avr` from Ubuntu 24.04 in a layer of its own, avr-gcc 7.3.0): the full core compiled for ATmega328P with 0 warnings, an Uno example linked with `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC` that fits 32 KB flash and 2 KB RAM, and an `f64` compile-fail probe whose message names `f64`.
- AZ-2728 (worker): `typescript/tests/hostile.test.ts`, `typescript/tests/support/hostile-worker.ts`, a runner module and probe worker under `typescript/tests/support/`, one new test file.
- AZ-2068 as built, beyond the list above: avr-gcc 7.3 has no `__builtin_is_constant_evaluated` (GCC 9), so `detail::constant_evaluated()` is `false` on GCC before 9 (a broken constant scheme is `SchemeInvalid` at run time there; the example `static_assert`s its status); `order.hpp` compares a flag byte number as `int32_t` (16-bit `int` turned it into a sign compare); `txt::kMaxCount` is `uint32_t` and `txt::over_max_count` skips the comparison where `size_t` is 16 bits (`-Wtype-limits`); `container_tests.cpp` includes `<initializer_list>`, which it had through `<array>`; README paragraph and example link. The `offsetof(Field, eq) == 16` assert holds on AVR too: `EqValue` is aligned to 4 there as well, so review C10's extra byte does not occur.
- Measured: M4F flash 7920 B and stack 504 B (unchanged); Uno example flash 15386 B of 32256, static RAM 220 B of 2048.
### Order of work
Worker in parallel with the parent; the parent runs the host C++ tests, GCC 16 in `gcc:16`, the arm stage (M4F flash and stack) and the AVR target; one total review; step 11; smoke; close; push `dev` and `main`.
### Risks
avr-gcc has a 16-bit `int`: shifts and constants that assume 32 bits warn or overflow and need fixes in `src/core`, which then needs the M4F stack check (8 B margin). Constant tables sit in RAM on AVR (Harvard), hence the example without the text codec and ECC.
