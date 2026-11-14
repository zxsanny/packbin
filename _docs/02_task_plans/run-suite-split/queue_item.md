---
kind: queue-item
order: 900
source: agent-made items below high, gathered 2026-11-13 (loop 123 close) under work-queue.md §Agent-made work
origin: operator
severity: low
depends_on: []
status: ready
blocked_on:
created: 2026-11-13
scanned: 2026-11-14
loop: 124
branch: dev
---
# Hygiene: agent-found entries

One loop for all entries (`autodev/protocols/work-queue.md` §Agent-made work, rule 1). Ready when it holds five entries, or when nothing else in the queue is ready.

## CI: split run-suite.sh before its next change

slug `run-suite-split`; severity low; source: found in loop 123 (AZ-4280 brought `.github/workflows/run-suite.sh` to exactly 500 lines, the soft cap); created 2026-11-13
#### Problem
`.github/workflows/run-suite.sh` is 500 lines. Any further change pushes it over the cap of `quality-thresholds`. Dart's steps already live in a sourced `run-suite-dart.sh`.

#### Outcome
The Go, Swift, Rust or C++ helper functions move to sourced files of their own, by language, with no change in what any suite runs.

#### Code sections
`.github/workflows/run-suite.sh`, new `.github/workflows/run-suite-<lang>.sh`, `.github/workflows/run-suite.test.sh` and the per-language self-tests that copy the script (`git grep -n run-suite.sh -- .github scripts`).

#### Acceptance checks
- `run-suite.sh` under 400 lines; every suite's step list is the same before and after (`run-suite.test.sh`, `run-suite-swift.test.sh`, `run-suite-dart.test.sh` pass; a CI run is green).

#### Needs
none
