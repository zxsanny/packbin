# Code Review Report
**Batch**: AZ-2064, AZ-2066, AZ-2067 | **Date**: 2026-10-05 | **Verdict**: PASS_WITH_WARNINGS

## Findings
| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| 1 | High | Bug | cpp/embedded/lib.sh, arm.sh, esp.sh, examples.sh | A failing build behind `| tee` or a failed check could still report PASS (fixed in batch) |
| 2 | High | Bug | cpp/include/packbin/fields_grouped.hpp | `packbin::bit` collides with the Arduino.h `bit(b)` macro (fixed: renamed `flag_bit`) |
| 3 | High | Spec-Gap | cpp/src/core/pack.cpp, unpack.cpp | Feature AC-5 missed: flash 9264 B / stack 616 B on Cortex-M4F (fixed: 7600 B / 464 B) |
| 4 | Medium | Bug | cpp/idf_component.yml | Example listed twice (manifest + auto-discovery); component pack failed (fixed) |
| 5 | Medium | Bug | cpp/examples/pico/platformio.ini | `-std=gnu++17` forced on the mbed framework broke its build (fixed: `build_src_flags`) |
| 6 | Low | Maintainability | .github/workflows/test.yml | Embedded job downloads ~2 GB of toolchains on every run; no CI cache |
| 7 | Low | Maintainability | cpp/embedded/*.sh | Several shell lines over 100 columns (URLs, awk programs) |

### Finding Details
**F1: False PASS** (High / Bug) — `run_target` relied on errexit inside target functions, which bash does not apply reliably there; the M4F row read PASS with two FAIL notes, and the first Pico/Arduino example rows read PASS while the builds had failed. Fix: any FAIL note fails the target, and every `cmd | tee` checks `PIPESTATUS[0]` immediately.
**F2: `bit` macro** (High / Bug) — every Arduino sketch including packbin failed to compile (`macro "bit" passed 3 arguments`). Renamed the builder to `flag_bit` in headers, tests, all-kinds firmware and README; no other Arduino function-like macro name is used as a callable in the headers.
**F3: AC-5 budget** (High / Spec-Gap) — soft-float double routines (~2.5 KB) came in through `read_int` visiting f32/f64; the walkers carried leaf-helper locals through every recursion level. Fix: integer-only visitor for counts/`when`, `noinline` leaf helpers, one walk context, no range frame between nesting levels. Stack is reported as raw minus the meter's own 64 B (the empty-call baseline), raw value shown alongside.
**F6** — recommend an `actions/cache` step keyed on toolchain versions; left for the refactor check.

## Notes
- AZ-2064: all 26 hex vectors the old suite asserted are asserted by the core tests; the six-language pair script passes with the C++ core (user, nested, session, position); 0 references to the old dynamic API in `cpp/` and the C++ drivers; host throughput 13–24 ms per 100 000 round trips (was 145 ms).
- AZ-2066: subagent-built driver (`cpp/embedded/`), finished by the parent after the subagent stalled three times on host sleep.
- AZ-2067: examples build from the packaged layouts (pio archive, Arduino layout, packed IDF component), not source paths. AC-2 (fresh projects from the registries) needs a published tag — not run.
