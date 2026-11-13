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

## Design (D17, applied)
A compose service `cpp-sanitizer` in `docker-compose.test.yml` on the `gcc:16` image of the `cpp` service: it installs Debian's `clang-<major>` package (the major read from `tool-pins.txt`, line `clang==19`) and runs `make -C cpp clean` then `make -C cpp CXX=clang++-<major> sanitizer-test` inside the container (`_docs/gotchas/cpp-build-clean-host-vs-container.md`). A new job `cpp-sanitizer` in `.github/workflows/test.yml` runs that service, `timeout-minutes: 10`. The same service is a stage of `scripts/loop-tests.sh` only if the stage list is the one place step 11 reads its stages from and the C++ paths already select it (decided when reading the script; otherwise the job alone).

## Code sections
`.github/workflows/test.yml` (new job), `docker-compose.test.yml` (new service), `.github/workflows/tool-pins.txt` (`clang==19`), `cpp/Makefile` comment if the recipe changes, the workflow checkers that read `test.yml` (`publish-workflow-structure.py`, `publish-jobs*.py/.sh`, `publish-pins*`, `publish-precheck*`: `git grep` every reader, `_docs/gotchas/grep-every-reader-of-a-shape.md`).

## Acceptance checks
- AC-1: the job `cpp-sanitizer` runs on every push of `test.yml`'s triggers, with `timeout-minutes: 10`, and passes on `dev` three runs in a row (the close push and the next two pushes that start CI; the runs seen at this loop's close are recorded, later ones in the next loop record).
- AC-2: a memory error added in a temp copy (an out-of-bounds read in a host test, not committed) fails the same compose service locally with an ASan report and a non-zero exit.
- AC-3: every workflow checker that reads `test.yml` passes (its own test script), and the publish workflow that calls `test.yml` still validates.
- AC-4: the clang major comes from `tool-pins.txt`, not from the runner.

## Needs
Outbound network from the container for `apt-get` (CI runners have it; locally the same as the `go` stage).

## Constraints
The plain `cpp` service and job stay unchanged; no new third-party action; actions pinned by SHA as the others.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| D17 applied (Debian clang in the gcc:16 image), reversible | agent | accepted-risk | Low |
