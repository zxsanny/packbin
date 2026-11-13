---
loop: 122
branch: dev
---

# C++: CI job runs the host suite under clang ASan and UBSan

**Task**: AZ-4278_cpp_sanitizer_ci_job
**Name**: C++: CI job runs the host suite under clang ASan and UBSan
**Description**: entry `cpp-sanitizer-ci-job` of the hygiene queue item `_docs/02_task_plans/hygiene-loop122/queue_item.md` (loop 122); its text is the spec.
**Complexity**: 3 points
**Dependencies**: none
**Component**: .github/workflows/, docker-compose.test.yml, cpp/Makefile
**Tracker**: AZ-4278
**Epic**: AZ-4133

## Problem
`make -C cpp CXX=clang++ sanitizer-test` passes 5 runs in a row on the Mac since AZ-4261, but no CI job runs it. GCC 16 cannot build the suite with `-fsanitize=undefined` (a constant-expression error at `order.hpp:107`), so the job needs clang. The hostile hang guard has no limit in a sanitizer build, so the job needs its own timeout.

## Outcome
A CI job runs the sanitizer target with its own job timeout, and passes.

## Design (D17, applied; revised at implement)
`test.yml` already makes 20 jobs, the most `publish-jobs-layout.py` allows (the free plan runs 20 at once, AZ-2627), and its suites matrix accepts only the nine language names. So the sanitizer build is a step of the existing `cpp` suite, not a job of its own: `run-suite.sh cpp`, when `PACKBIN_CPP_SANITIZER=1` (set in the compose `cpp` service), installs Debian's `clang-<major>` and `libclang-rt-<major>-dev` in the `gcc:16` image (major from `tool-pins.txt`, line `clang==19`), removes any sanitized binary, and runs `timeout 600 make -C cpp CXX=clang++-<major> sanitizer-test` after the plain suite. CI runs it in the suites entry `cpp typescript java` (166 s before, under the 388 s wall of `embedded-arm`); step 11 runs it in the `cpp` stage. The self-test (`run-suite.test.sh` C1, with fake `apt-get`, `timeout` and `make`) covers the flag on, off and a failing sanitizer build.

## Code sections
`.github/workflows/run-suite.sh` (the cpp case), `.github/workflows/run-suite.test.sh` (C1), `docker-compose.test.yml` (the cpp service's flag), `.github/workflows/tool-pins.txt` (`clang==19`), `.github/workflows/publish-pins.test.sh` (`PINS_NAMES`), `cpp/Makefile` (`SAN_FLAGS`), the workflow checkers that read `test.yml` (`publish-workflow-structure.py`, `publish-jobs*.py/.sh`, `publish-pins*`, `publish-precheck*`: `git grep` every reader, `_docs/gotchas/grep-every-reader-of-a-shape.md`).

## Acceptance checks
- AC-1: the sanitizer step runs in the CI job `suites (cpp typescript java)` on every push of `test.yml`'s triggers, under a 10-minute limit of its own, and passes on `dev` three runs in a row (the close push and the next two pushes that start CI; the runs seen at this loop's close are recorded, later ones in the next loop record).
- AC-2: a memory error added in a temp copy (an out-of-bounds read in a host test, not committed) fails the same compose service locally with an ASan report and a non-zero exit.
- AC-3: every workflow checker that reads `test.yml` passes (its own test script), and the publish workflow that calls `test.yml` still validates.
- AC-4: the clang major comes from `tool-pins.txt`, not from the runner.

## Needs
Outbound network from the container for `apt-get` (CI runners have it; locally the same as the `go` stage).

## Constraints
The plain `make -C cpp test` step stays first and unchanged; no new job, no new third-party action.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D17 applied (Debian clang in the gcc:16 image), reversible | agent | accepted-risk | Low |
