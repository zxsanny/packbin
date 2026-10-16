---
loop: 30
branch: dev
---

# CI speed: test.yml about 7 minutes, shorter tag publish run

**Task**: AZ-2600_ci_speed
**Name**: CI speed
**Description**: `test.yml` wall time falls from 15 to 18 minutes to about 7 minutes; the tag publish run loses the Go proxy and Maven waits that are not needed.
**Complexity**: 8 points
**Dependencies**: AZ-2582
**Component**: ci
**Tracker**: AZ-2600
**Epic**: AZ-2223

## Outcome

- `suites` is a matrix (7 languages + Swift in 2 parts); `publish-gate` is 3 jobs; every group and every language still runs exactly once.
- Guards and mutants follow; check counts before and after are recorded.
- T2 as the owner decides; T3 cause found and the wait shortened or non-blocking.
- Metrics report updated with before and after per job.

See `_docs/02_task_plans/ci-speed/problem.md` and the plan `_docs/loops/loop30/plan30.md`.
