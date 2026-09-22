# Batch Report

**Batch**: 1
**Tasks**: AZ-1866_initial_structure
**Date**: 2026-09-22

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-1866_initial_structure | Done | scaffold, workflows, compose | 6/6 container checks passed | None |

## Code Review Verdict: PASS

`_docs/03_implementation/reviews/batch_01_loop1_review.md`

## Test Suite

- Total: 6
- Passed: 6
- Failed: 0
- Skipped: 0

Host file check and `run-suite.sh` for all six languages passed before the containers. CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, and java. Each wrote a `0` row to `test-results/report.csv`.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Java 27 is current stable, and `eclipse-temurin:27-jdk` does not exist | AZ-1866 containers | The compose file uses `eclipse-temurin:26-jdk`, the newest published Temurin JDK | clear |
| 2 | The task tree says `java/tests/`; module layout says `java/src/test/` | AZ-1866 Test Structure | The scaffold directory is `java/src/test/` | clear |
| 3 | Registry upload cannot run until the six packages exist | AZ-1866 CI table / AZ-1875 | `publish.yml` fails the tag when the golden row mismatches and does not upload | clear |
| 4 | `gcc:16` and `eclipse-temurin:26-jdk` may not contain cmake or Maven | AZ-1880 / AZ-1881 | Those tasks add a build the image can run, or the image pin changes with them | clear |

## Commit

`[AZ-1866] Scaffold languages, fixture, and Actions`

Loop: 1

## Next Batch: AZ-1876, AZ-1877, AZ-1878, AZ-1879
