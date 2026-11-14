# Batch 01 report — loop 124 (run-suite split)

Task: AZ-4288 (2 pt), owner-picked hygiene entry `run-suite-split`. Parent, short loop on the launcher.

## Task results

| task | status | proof |
|------|--------|-------|
| AZ-4288 | done | `cpp_clang_install` → `run-suite-cpp.sh` (13 lines); `go_fmt`, `go_fuzz`, `go_deps` → `run-suite-go.sh` (44); `rust_speed`, `rust_clippy_component`, `rust_test_build` → `run-suite-rust.sh` (64); each sourced at the top of its own `case` arm, as Dart's. `run-suite.sh` 500 → 397 lines. AC-1: the removed lines and the moved lines are identical (diff without blank lines). AC-2: `run-suite.test.sh` all checks passed; step 11 next. AC-3: `report-row.test.sh` greps `run-suite-{cpp,dart,go,rust}.sh` too, passes. AC-4: `shellcheck -S warning` clean on every changed file. Mutants: a copy without `run-suite-cpp.sh` / `-go.sh` / `-rust.sh` fails the self-test 4 / 19 / 21 times. Also: the cpp sanitizer checks (C1, loops 122 and 123) moved from `run-suite.test.sh` (521 lines, over the cap) to a sourced `run-suite-cpp.test.sh`; `run-suite.test.sh` now 484 |

## Review

Inline (high), mechanical move: no finding. Note: the Swift cache key of `test.yml` hashes `run-suite.sh`, so the first CI run after this change misses the Swift cache once (a cold Swift build in the three Swift parts); it was not moved for that reason, and the key stays correct.

## Discovered during implementation

| spec ref | discovery | proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AZ-4288 | `run-suite.test.sh` was 521 lines (loops 122 and 123 added the C1 checks) | moved in this task | clear |

## Tests

`run-suite.test.sh` and `report-row.test.sh` pass; three mutants caught. Step 11: next, on the batch commit.
