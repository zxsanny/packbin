# Batch Report

**Batch**: 3 (feature-assess round 2, EXTEND: one gap-clear row W1; parent inline)
**Tasks**: AZ-2147_cpp_empty_group_without_member
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2147_cpp_empty_group_without_member | Done | 4 files (1 header, 1 test, 1 compile-fail case, Makefile) | C++ all tests passed; 11 compile-fail cases rejected | None |

`check_shape` (`cpp/include/packbin/order.hpp`) now refuses a span-1 group with no member access (`never_set`): `flags(0, group(0))` and `flag_byte(0), flag_bit(0, group(0))` are `SchemeInvalid` at field 0, and a constexpr scheme of that shape is a compile error (`breaks_order<0>`). An empty group bound to `Opt<bool>` keeps packing `0101` / `0100`.

Red before the fix: `FAIL: AZ-2147 AC-1 empty group in flags`, `FAIL: AZ-2147 AC-1 empty group as a flag bit`, and `compile-fail: tests/compile-fail/empty_group_without_member.cpp compiled`. AC-2 passed before (pin).

Also in this batch (doc gaps from assessment round 2): `fixtures/hostile/README.md` decision line names the U3 exception; the Rust public `pack` doc says fields under `flags` / `when` inside a `times` round are not aligned yet (AZ-2086); AZ-2090 / AZ-2091 note that construction checks belong in the TypeScript `Scheme` constructor; AZ-2100 notes Python joins the `bitwhen` ring; implementation and completeness reports cover all three batches.

## Code Review Verdict: PASS (self-review)

One condition in a constexpr shape check plus tests; list/dict element groups get their access from the element binding (`table.hpp:331-346`), so only member-less groups under `flags` / a flag bit are newly refused, and those were already refused everywhere else.

## Test Suite

- C++ host suite: all tests passed, 11 compile-fail cases rejected
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm cpp` (GCC 16, all tests passed, 11 compile-fail cases rejected), `cpp-embedded` (Cortex-M0+/M3/M4F and s390x: 0 failures; M4F flash and stack budgets still met), `cpp-embedded-esp` (ESP32-S3 and ESP32-C3 ESP-IDF builds, ESP-IDF example, Arduino-ESP32 example: PASS), `rust` (pass), `cases.test.sh`, `language-pair.sh` (all rings)
- Not run locally: `cpp-example-pico` (PlatformIO `raspberrypi` has no Linux arm64 toolchain; known since loop 10, `batch_04_loop10_report.md` #3). CI runs it on x86_64; the same CPU (Cortex-M0+) core build passed in the ARM stage

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | GCC 16 (`-Werror=array-bounds`) raises a false positive in `copy_fields` when `check_shape` gains a runtime `f.access == nullptr` test (bisected: header change alone → 2 errors, test change alone → 0). The rule moved into the `group(id, children...)` factory (`if constexpr` on zero children → `mark_invalid`), so `check_shape` is unchanged and GCC 16 compiles clean | AZ-2147 | Keep the factory form | clear |
| 2 | The embedded toolchain cache (arduino-cli, Arduino ESP32 core, PlatformIO, ~7.7 GB) lived in `cpp/build/embedded` and was wiped by `rm -rf cpp/build` / `make clean`, forcing a ~30 min re-download. Owner decision: move it to the gitignored `cpp/embedded/.cache/` (override `PACKBIN_EMBEDDED_CACHE`), excluded from the embedded image build context | none | Done in this batch (`cpp/embedded/lib.sh`, `examples.sh`, `.gitignore`, `cpp/embedded/.dockerignore`) | clear |

## Commit

`[AZ-2147] C++ refuses an empty group with no member in flags` — body: one line + `Loop: 12`

## Next Batch: All tasks complete
