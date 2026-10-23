---
loop: 65
branch: dev
---

# CI paths-ignore, Rust size limits, flag-byte chain in a `times` round

**Task**: AZ-PENDING_ci_paths_ignore_rust_limits_flag_round_chain
**Name**: CI paths-ignore, Rust size limits, flag-byte chain in a `times` round
**Description**: Stop `test.yml` running on `_docs/**`-only pushes; set the text, ecc and session limits of the Rust embedded stage at today's figure plus 5%; add and measure the 3-deep flag-byte `when` chain inside a `times` round (scheme 0x5e) in the C++ all-kinds image.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `.github/workflows/test.yml`, `rust/embedded/`, `cpp/embedded/`, `cpp/tests/core/`
**Tracker**: pending (Jira connector absent; payload in `_docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md`, to be extended)
**Epic**: AZ-2645

## Problem and outcome

`_docs/02_task_plans/ci-paths-ignore-size-limits-times-flag-chain/` (problem, acceptance_criteria AC-1..AC-11, expected results E1..E9). Owner decisions of 2026-10-23: limits at measured + 5%; stack case measured and gated at 512 B (over: report and stop); CS-D5 deferred; `paths-ignore` on `push` only.

## Scope

### Included
- `.github/workflows/test.yml` (`on.push`), a check script for it.
- `rust/embedded/limits.txt`, `checks.test.sh`, `README.md`; the Rust component description.
- `cpp/embedded/common/all_kinds.{hpp,cpp}`, `cpp/embedded/arm/ac2_main.cpp`, `cpp/embedded/common/vectors_main.cpp`, `cpp/tests/core/when_chain_host_tests.cpp`; C++ description and `AGENT_GOTCHAS.md` (figures).

### Excluded
- `cpp/src/core`, `cpp/include` (no source change; flash pin 7,724 B), wire format, CS-D5, tags, F44, epic AZ-2750, U24.
