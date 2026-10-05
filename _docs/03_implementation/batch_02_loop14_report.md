# Batch Report

**Batch**: 2 (loop 14)
**Tasks**: AZ-2095_publish_after_tests
**Date**: 2026-10-06

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2095_publish_after_tests | Done (AC-1, AC-2, AC-4 structural; AC-3, AC-5, AC-6 pass) | 7 files (`test.yml`, `publish.yml`, `publish-gate.test.sh`, 4 docs) | `publish-gate.test.sh`, `report-row.test.sh`, `hostile/cases.test.sh` pass; 4 negative proofs reject | None |

## Decisions

- Parser: Ruby stdlib `yaml` (owner decision 2026-10-06). It handles YAML 1.1 reading `on` as `true`, and runs on the local Ruby 2.6 and the runner's Ruby 3. The negative copies are built with `grep -v` / `awk`, no second parser.
- `test.yml`: `push` limited to `branches: ["**"]`, `pull_request` kept, `workflow_call` added, workflow permissions `contents: read`, `timeout-minutes` 60 (`scaffold`) and 90 (`embedded`).
- `publish.yml`: workflow permissions `contents: read`; job `test` calls `./.github/workflows/test.yml` (permissions `contents: read`, no `secrets:` key); `publish` needs it, has `contents: write` + `id-token: write` and `timeout-minutes: 60`.
- The two old `grep 'push:'` / `grep 'pull_request:'` checks are replaced by the parsed check (stricter).

## Code Review Verdict: PASS_WITH_WARNINGS

Parent read the full diff (no separate `/code-review` run for this small workflow-only batch). No defects found. The warning is GitHub behavior that cannot run locally: that a branch-only `push` filter does not fire on a tag, that the `test` call starts and `publish` is skipped on a red test job, and that the called jobs hold only the narrower token. These are checked structurally and re-checked on the first real tag run (the spec accepts this; there is no dry-run path until AZ-2096).

CI-parity: PASS. Commands: `bash .github/workflows/publish-gate.test.sh`, `bash .github/workflows/report-row.test.sh`, `bash fixtures/hostile/cases.test.sh`. The language suites read no changed path (workflow YAML, a shell test, docs) and run in Run Tests (step 11).

## Test Suite

- `publish-gate.test.sh`: passes, including four rejections: publish without `needs`, `id-token` at workflow level, `secrets` on the test call, `test.yml` push on tags.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `tests/environment.md` "When to run" and "Timeout: 5 minutes" were stale | AZ-2095 Scope (docs) | Reworded in this batch | clear |
| 2 | AZ-2096 and AZ-2097 will edit `publish.yml` again; the structure check expects one call to `test.yml`, workflow permissions `contents: read`, and write permissions only on `publish` | AZ-2096, AZ-2097 | Any new job with a write permission fails the check by design; a `workflow_dispatch` trigger or a `concurrency` key is tolerated | clear |
| 3 | A tag now runs the full test time (about 40 min cold) before any upload | AZ-2095 Flagged concerns | Accepted by the spec; caching is follow-up D12 | clear |

## Commit

`[AZ-2095] Publish waits for the tests on the tagged commit`. Body: one line + `Loop: 14`.

## Next Batch: AZ-2096_publish_build_before_upload
