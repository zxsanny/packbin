# Batch Report

**Batch**: 3
**Tasks**: AZ-2024, AZ-2026
**Date**: 2026-09-29

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2024_java_session | Done | java/src, java/test.sh | All session tests passed | None |
| AZ-2026_readme_session | Done | README.md | text check: 2 clear examples, 1 session example, 0 missing operations | None |

## Code Review Verdict: PASS

`_docs/03_implementation/reviews/batch_03_loop9_review.md`

## Test Suite

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm` for csharp, typescript, python, rust, cpp, and java, then `bash .github/workflows/publish-gate.test.sh` and `bash .github/workflows/report-row.test.sh`. `cpp/build` was removed before the run.

- csharp: 52 passed
- typescript: passed
- python: passed
- rust: passed
- cpp: all tests passed
- java: All session tests passed
- Failed: 0

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| none | | | | |

## Commit

`[AZ-2024] [AZ-2026] Add the Java session and the README example`

Loop: 9

## Next batch

AZ-2025. The six openers must emit one hex.
