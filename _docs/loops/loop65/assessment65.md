# Feature assessment — loop 65

loop: 65
feature: ci-paths-ignore-size-limits-times-flag-chain
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-23
**Implement pass**: one batch, commits `c431200` and `f3738da`
**Verdict**: COMPLETE — 11 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear (AC-8 changed by an owner decision, recorded below)

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| AC-1 | test.yml `on.push` ignores exactly `_docs/**` | covered | `ring-wiring.test.sh` accepts the file; `smoke65.sh` step 1 parses it with Ruby YAML: `branches ["**"]`, `paths-ignore ["_docs/**"]`, `pull_request` and `workflow_call` as before | intake |
| AC-2 | the check rejects the old file | covered | `ring-wiring.test.sh` mutant "push without the _docs paths-ignore" and "paths-ignore beyond _docs" both rejected | intake |
| AC-3 | limits text 27964/2898, ecc 18879/798, session 19325/1924 | covered | `limits.txt`; HEAD figures from `rust/embedded/run.sh host` (26,632/2,760, 17,980/760, 18,404/1,832); stage and step 11 `rust-embedded` PASS | intake |
| AC-4 | every set numeric, a dash or a missing line is caught | covered | `checks.test.sh` (`unlimited_sets`): 3 new checks pass | intake |
| AC-5 | one byte under fails the stage naming set, figure, limit | covered | `text: flash 26632 B over 26631 B`, exit 1 (smoke step 4) | intake |
| AC-6 | documents state the limits and the owner decision | covered | `limits.txt` comment, `rust/embedded/README.md`, Rust component description | intake |
| AC-7 | scheme 0x5e, 4 rows equal to the Python package | covered | `when_chain_host_tests.cpp` (host and `gcc:16` pass), `vectors_main` (M3 and s390x 290 of 290), arm image `FLAG_ROUND_CHAIN_FAILURES 0` | intake |
| AC-8 | stack of the new rows measured and gated | covered (owner decision) | unpack 612 B, pack 464 B against the 512 B budget: over. Owner 2026-10-23: `stack_budget` 2,048 B and `stack_pin` 612 B; the stage passes at 612 B and fails at a pin of 611 B | intake |
| AC-9 | flash stays 7,724 B, no core edit | covered | arm stage `cpp-m4f` 7,724 B (pin 7,724 B); `git diff` has no path under `cpp/src/core` or `cpp/include` | intake |
| AC-10 | documents record the figure | covered | C++ description loop 65 line, `AGENT_GOTCHAS.md` stack line | intake |
| AC-11 | step 11 reports 0 failed | covered with a note | 6 stages pass; `publish-gate` failed in two parallel runs on timing-bound checks and passes in every group alone (see the record) | intake |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- The first docs-only push after the change: whether GitHub starts no run is only visible on the next record-only commit.
- Pack and unpack of the new scheme on the error paths in the arm image (the stage measures success paths only).
