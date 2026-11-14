---
loop: 124
branch: dev
---

# CI: split run-suite.sh, Go, Rust and C++ helpers in sourced files

**Task**: AZ-4288_run_suite_split
**Complexity**: 2 points
**Component**: .github/workflows/
**Tracker**: AZ-4288
**Epic**: AZ-4133

## Problem
`.github/workflows/run-suite.sh` is 500 lines, the soft cap of `quality-thresholds`. Dart's steps already live in `run-suite-dart.sh`, sourced from its `dart` case.

## Design
`cpp_clang_install` → `run-suite-cpp.sh`; `go_fmt`, `go_fuzz`, `go_deps` → `run-suite-go.sh`; `rust_speed`, `rust_clippy_component`, `rust_test_build` → `run-suite-rust.sh`. Each file is sourced inside its own `case` arm, as Dart's is, so a self-test that copies `run-suite.sh` for one language needs only that language's file. Swift's helpers stay in `run-suite.sh`: the CI Swift cache key hashes `run-suite.sh` (`test.yml`, pinned by `publish-jobs-layout.py` and its mutant), and moving them would change that key and its checks.

## Acceptance checks
- AC-1: `run-suite.sh` under 400 lines; the three new files hold only the moved functions and their comments, word for word.
- AC-2: `run-suite.test.sh` (with its sourced Swift, Dart and Rust-clippy tests) passes; step 11 runs every suite through the compose services and they pass.
- AC-3: the registry-name guard of `report-row.test.sh` covers the new files.
- AC-4: `shellcheck -S warning` clean on every changed file.

## Constraints
No step, flag, message or order changes in any suite.
