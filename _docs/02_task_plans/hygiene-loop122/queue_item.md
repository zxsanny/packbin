---
kind: queue-item
order: 900
source: agent-made items below high, gathered 2026-11-13 (loop 121 close) under work-queue.md §Agent-made work
origin: agent
severity: medium
depends_on: []
status: ready
blocked_on:
created: 2026-11-13
scanned: 2026-11-13
loop: 122
branch: dev
---
# Hygiene: two small agent-found items

One loop for all entries (`autodev/protocols/work-queue.md` §Agent-made work, rule 1). Ready when it holds five entries, or when nothing else in the queue is ready.

## Dart: the repeat-last cost test failed once beside five other suites

slug `dart-repeat-last-cost-test-flake`; severity low; source: found in loop 121 (step 11, `scripts/loop-tests.sh`, the `dart` stage in the pool); created 2026-11-13
#### Problem
`dart/test/rounds/repeat_last_cost_test.dart` ("16000 sibling whens that write nothing, then a repeat build in a time that follows their number") failed in the pool: `took 869 ms, nominal bound 300 ms, load factor 1.72, scaled bound 514 ms`. It passed alone on the serial retry (75 s stage). The load factor is a CPU loop; the timed build is allocation-bound, so the Docker VM running five other suites slows it by more than the factor shows.

#### Outcome
The test passes in the pool as it does alone, with the same sensitivity to a quadratic walk (the old walk takes seconds at this size).

#### Code sections
`dart/test/rounds/repeat_last_cost_test.dart`, `dart/test/support/timing.dart`.

#### Acceptance checks
- The timed section takes the best of three builds, or the bound is a ratio of two sizes (as the C# and Go tests of loop 121 do), instead of one build against a scaled bound; a deliberately quadratic copy of the walk still fails it.
- The `dart` stage passes three times in a row beside the other suites (`bash scripts/loop-tests.sh --all --jobs 4`).

#### Needs
none

## C++: run the host suite under clang ASan and UBSan in CI

slug `cpp-sanitizer-ci-job`; severity medium; source: found in loop 121 (AZ-4261 follow-up; the loop 113 security audit recommended it long term); created 2026-11-13
#### Problem
`make -C cpp CXX=clang++ sanitizer-test` passes 5 runs in a row on this Mac since AZ-4261, but no CI job runs it. GCC 16 cannot build the suite with `-fsanitize=undefined` (a constant-expression error at `order.hpp:107`), so the job needs clang. The hostile hang guard has no limit in a sanitizer build.

#### Outcome
A CI job runs the sanitizer target with its own job timeout, and passes.

#### Code sections
`.github/workflows/test.yml` (a new job), `cpp/Makefile` (`sanitizer-test`), `docker-compose.test.yml` if a clang image is used.

#### Acceptance checks
- The job passes on `dev` three runs in a row; a memory error added in a temp copy fails it.
- The job timeout is set (10 minutes).

#### Needs
none
