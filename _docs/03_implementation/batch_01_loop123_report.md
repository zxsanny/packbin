# Batch 01 report — loop 123 (hygiene)

Tasks: AZ-4279 (C++ member folds, 2 pt), AZ-4280 (clang install failure message, 1 pt). Parent, serial.

## Task results

| task | status | proof |
|------|--------|-------|
| AZ-4279 | done | `total()` and `nest()` in `table.hpp`, `scheme()` in `codec.hpp` (the `binds_row` check, now `binds_all`, and the node copy) use pack expansions in arrays instead of folds; `-fbracket-depth=512` removed from `SAN_FLAGS`. AC-1: the cpp suite in `gcc:16` passes, plain (GCC) 52 s and sanitizer (clang 19, default limits) 54 s. AC-2: a 300-field scheme compiles with clang 19 on the new headers and fails on the old ones (`fold expression with 300 arguments exceeded expression nesting limit of 256`); host test `az4279_scheme_of_300_top_level_fields_builds`. AC-3: step 11 (embedded rows and m33f pins) |
| AZ-4280 | done | `cpp_clang_install` prints `clang-<major> is not installable on Debian <version>; move clang==<major> in .github/workflows/tool-pins.txt …` and fails. Self-test: a fake `apt-get` that fails (line present, no sanitizer build), a good install (line absent); a mutant without the line is caught. `run-suite.sh` is 500 lines (the cap) |

## Review

Inline (high), small diff: 1 Low fixed (the timing gotcha still said the sanitizer build needs `-fbracket-depth`). 1 risk checked in step 11: the `copied[]` arrays of `nest()` / `scheme()` hold one `int` per member if a scheme is built at run time; the `cpp-m33f` stack pin and the embedded rows decide it. PASS_WITH_WARNINGS.

## Discovered during implementation

| spec ref | discovery | proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AZ-4280 | `run-suite.sh` reached the 500-line cap | the next change there splits the cpp/Go helpers into a sourced file, as Dart's | clear |

## Tests

Cpp suite in `gcc:16` (GCC plain + clang 19 sanitizer) green; clang 19 old/new header compile of a 300-field scheme; `run-suite.test.sh` all checks passed; mutant caught. Step 11: next, on the batch commit.
