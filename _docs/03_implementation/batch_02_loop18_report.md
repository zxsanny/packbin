# Batch Report

**Batch**: 2 (loop 18, wave 2: one worker owning `fixtures/hostile/` and the six packages' hostile-vector loaders)
**Tasks**: AZ-2126 (AC-3, the `eq_bool_false` vector), AZ-2194 (`pack` stage)
**Date**: 2026-10-10

Owner direction unchanged: the worker ran only the hostile-vector tests of each package; the full suites and the Docker/embedded runs are the one total run.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2126_eq_bool_true_only | Done (AC-3); the package construction checks shipped in batch 1 | `fixtures/hostile/{cases.txt,README.md,cases.test.sh}`, the six loaders | `eq_bool_false` construct case in every package; C++ builds `eq(0, 0)` at run time because the literal `eq(0, false)` is a compile error (`compile-fail/when_eq_bool_false.cpp`) | none |
| AZ-2194_hostile_pack_stage | Done | `check-cases.sh`, `cases.test.sh` (+14 corruptions), README (format + five sections), `cases.txt` (25 cases), six loaders, new `hostile_pack_cases.hpp` | `hostile cases ok: 25`; the loaders assert where a case lists the package in `Run by` | Run/Not-run lists re-probed: only `pack_out_of_range_integer` is skipped in C++ |

## Run by / Not run by (probed, not the spec's stale lists)

| Case | Run by | Not run by |
|------|--------|------------|
| `pack_out_of_range_integer` | TypeScript, Python, Java, C# (dictionary rows), Rust (map form, `U16(300)`) | C++: typed row binds `std::uint8_t` |
| `pack_missing_required_value` | all six (C++: an unset `Opt` member gives `BadValue`) | none |
| `pack_times_list_too_long` | all six (TypeScript, Python, Java since AZ-2185 to AZ-2187) | none |
| `pack_times_list_too_short` | all six | none |
| `pack_aligned_round_row` (`01030102020303`) | all six (Python since AZ-2134) | none |

## Code Review Verdict: not run for this batch (owner direction); covered by the one total review

## Test Suite (hostile vector tests only, before to after)

- `bash fixtures/hostile/cases.test.sh`: 19 cases to 25, passes
- TypeScript `npm test`: 502 to 509; Python: 549 to 556; Rust `hostile`: 7 to 7 (one looping test, 19 to 25 cases); Java `test.sh`: passes; C# `Hostile` filter: 71 to 78 on both targets; C++ `make -C cpp test`: passes (re-run by the parent after adding `hostile_pack_cases.hpp` to the Makefile dependencies)

CI-parity: PASS for the commands above; the full suites, rings and embedded job are the one total run.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 19 | Python's too-short `times` list raises a bare `IndexError` ("list index out of range"); the loader accepts `IndexError` or `ValueError` | AZ-2194 AC-6 | package ticket: give it a described error | unclear |
| 20 | `cpp/Makefile` did not list `hostile_pack_cases.hpp` as a dependency of `build/packbin_tests` | harness | fixed by the parent in this batch | clear |
| 21 | C++ notes `invalid_utf8` and `invalid_utf8_dict_key` as "C++ borrows UTF-8 unchecked (open concern)" (standing C++ concern from loop 10) | hostile vectors | unchanged; keep in the handoff | unclear |

## Commit

`[AZ-2126] [AZ-2194] Loop 18 wave 2: eq_bool_false vector and pack stage` ... `Loop: 18`.

## Next Batch: wave 3 (AZ-2120 and the AZ-2128 `when`/`times`/`repeat` angle, six packages)
