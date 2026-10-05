# Batch Report

**Batch**: 4 (loop 14)
**Tasks**: AZ-2097_publish_rerun_and_registry_policy
**Date**: 2026-10-06

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2097_publish_rerun_and_registry_policy | Done (AC-1 to AC-7 pass locally) | 6 scripts modified (`publish-lib.sh`, `publish-registries.sh`, `publish-upload.sh`, `publish.yml`, `publish-gate.test.sh`, `publish-phases.test.sh`), 3 new (`publish-query.sh`, `publish-published.py`, `publish-rerun.test.sh`), 3 docs | `publish-gate.test.sh` (3 minutes, includes the 7-run credential matrix and the AC-2 to AC-7 scenarios), `report-row.test.sh`, `hostile/cases.test.sh` pass; no FAIL lines | none open in code |

## Design

- One declared target table `PACKBIN_TARGETS` (name, language, tier) in `publish-lib.sh`. Required: NuGet, npm, PyPI, crates.io, Maven Central, vcpkg. Optional: PlatformIO, ESP-IDF, Arduino. `need`, `credentialed`, the python special case and the `skip ...` echoes are gone.
- Preflight: a required target without its credential refuses the run before anything is built or written, with every missing variable named. An optional target without its credential gets a `::warning::` line and a `$GITHUB_STEP_SUMMARY` line and is skipped. Build-only still needs no credential.
- Upload phase: required targets first, then optional; the first failure stops the run (owner decision: a failed optional upload with its credential present fails the run). Each target is queried before its upload and logs `already published <target> <version>`.
- Existence queries (`publish-query.sh`, answers read by `publish-published.py`): NuGet flat container index, npm `GET /packbin/<v>`, PyPI JSON API (wheel and sdist both listed), crates.io API with a User-Agent, Maven Central `publisher/published` (token, Risk 1), PlatformIO `v3/packages/<owner>/library/packbin`, ESP-IDF component API, vcpkg and Arduino by `git ls-remote` (branch, and for Arduino the tag, equal the prepared commit). Timeout 20 s, 3 attempts on transport error, 5xx or 429. An unexpected status or body fails the run; an unknown answer is never read as "not published". Public queries send no token. `twine --skip-existing`, `compote --allow-existing`, `dotnet --skip-duplicate`, `git push --atomic` are kept as race guards.
- `publish.yml`: `concurrency` group `publish-${{ github.ref }}`, `cancel-in-progress: false`. The Ruby structure check requires it (three new negative copies rejected).
- Mutation proof by the worker: changing the `rust` row to optional made the gate test fail with 10 FAIL lines.

## Code Review Verdict: PASS_WITH_WARNINGS

Parent read all production code of the batch (`publish-lib.sh`, `publish-registries.sh`, `publish-upload.sh`, `publish-query.sh`, `publish-published.py`, `publish.yml`); no separate `/code-review` run. No defects found. Warnings, all facts only a real tag run can confirm:

- Maven Central `publisher/published`: the response shape (`{"published": true}`) comes from Central's OpenAPI document, not from a call with a token. An unexpected shape makes the Java existence check fail the run (fail-closed), which would block the first real tag.
- Whether Central reports published before `repo1.maven.org` does, and the exact text of a duplicate rejection (the code matches "already exists" in a FAILED deployment).
- `pio account show --json-output` resolves the owner from the token (read from source, run only with an invalid token), and `pio pkg publish` re-upload behavior.
- The PlatformIO owner lookup and the Central query send a token, which the spec's constraint ("existence checks must not send tokens") allows only for Central (Risk 1). The owner decides whether to add a `PLATFORMIO_OWNER` setting.
- A query outage in the upload phase can fail the run after earlier required targets were uploaded; a re-run finishes it.
- A re-run rebuilds everything first (vcpkg and Arduino rebuilds are byte-deterministic, AC-6).

CI-parity: PASS. Commands: `bash .github/workflows/publish-gate.test.sh`, `bash .github/workflows/report-row.test.sh`, `bash fixtures/hostile/cases.test.sh`, re-run by the parent after the worker. No file is over 500 lines (`publish-phases.test.sh` 486).

## Test Suite

Gate test passes; scenarios: credential matrix (7 runs, each non-zero, names the variable, empty log, bare repos unchanged, nothing built), optional warnings (3 warnings, 3 summary lines), python and rust never dropped, failed required and failed optional upload exit non-zero, partial re-run (NuGet, npm, PyPI skipped, rest uploaded), full re-run (9 `already published`, 0 upload commands, `git rev-list --count --all` unchanged), Arduino tag at other content fails, partial PyPI is not published, query 503 retried then fails, concurrency parsed from `publish.yml`.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | PlatformIO and ESP-IDF existence: `pio pkg publish` has no allow-existing flag and its client check misses older versions; `compote` has `--allow-existing` but sends the token | AZ-2097 Flagged concerns | Public API queries, `--allow-existing` as race guard | clear |
| 2 | The PlatformIO owner lookup (`pio account show`) sends the token to PlatformIO; the spec says existence checks must not send tokens | AZ-2097 Constraints | Keep, or add a `PLATFORMIO_OWNER` setting | unclear (owner) |
| 3 | NuGet needs a real query: `--skip-duplicate` alone would still call `dotnet nuget push` on a no-op re-run | AZ-2097 AC-5, AC-6 | Done | clear |
| 4 | A half-uploaded PyPI release must not be read as published | AZ-2097 AC-6 | File names compared, `twine --skip-existing` | clear |
| 5 | Arduino credential: a GitHub URL without `GITHUB_TOKEN` used to pass preflight and fail at push | AZ-2097 | Now fails preflight (credential by URL host) | clear |
| 6 | Live registries already hold packbin 0.1.x to 0.2.1; a real re-run of an old tag would skip them | AZ-2097 | None needed | clear |
| 7 | ADR-002, AC-12 and AC-13 wording still says six registries | AZ-2097 Excluded (C29/D19) | Doc task | clear |

## Commit

`[AZ-2097] Re-run finishes a partial publish; required and optional registries`. Body: one line + `Loop: 14`.

## Next: all four tasks done; feature assessment (step 10.5)
