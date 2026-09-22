# Batch Report

**Batch**: 4
**Tasks**: AZ-1875_pipeline_publish
**Date**: 2026-09-22

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-1875_pipeline_publish | Done | .github/workflows/, .env.example | publish gate passed; CI suites 9+9+9+10+cpp+java passed | None |

## Code Review Verdict: PASS

`_docs/03_implementation/reviews/batch_04_loop1_review.md`

## Test Suite

- Total: 1 gate script plus 6 language suites
- Passed: 1 gate script, csharp 9, typescript 9, python 9, rust 10, cpp, java
- Failed: 0
- Skipped: 0

CI-parity: PASS — `bash .github/workflows/publish-gate.test.sh` and `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, and java.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Maven Central groupId is still not named | AZ-1875 / AZ-1881 | The tag reads `MAVEN_GROUP_ID`. If Java is present and the value is empty, no registry is written | unclear |
| 2 | The vcpkg git remote is not named | AZ-1875 / ADR 003 | Default push is branch `vcpkg` on `https://github.com/zxsanny/packbin.git`, using the repository credential | unclear |
| 3 | Maven Central may require a signature key besides `MAVEN_CENTRAL_TOKEN` | AZ-1875 | The upload posts a bundle to the Central publisher API. A rejected bundle publishes nothing further only if it is last; Java is last | unclear |

## Commit

`[AZ-1875] Publish six packages from a version tag`

Loop: 1

## Next Batch: All tasks complete
