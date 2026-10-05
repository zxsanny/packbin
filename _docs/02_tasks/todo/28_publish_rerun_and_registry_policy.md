# Re-run completes a partial publish; required-registry policy

**Task**: 28_publish_rerun_and_registry_policy
**Name**: Re-runnable publish with declared required registries
**Description**: Re-running the publish of a tag finishes whatever is missing without failing on versions already published, and the six core registries are required while the three embedded ones are optional with a warning.
**Complexity**: 3 points
**Dependencies**: 27_publish_build_before_upload (the upload phase this task makes idempotent)
**Component**: ci-publish
**Tracker**: pending
**Epic**: AZ-2069

## Problem

**Re-run fails.** When an upload fails mid-run (network, registry outage, Central validation), re-running the same tag fails at the first registry that already holds the version:
- npm: `npm publish` errors on an existing version (`publish-registries.sh:211`, `publish-inside.sh:29`).
- PyPI: `twine upload` without `--skip-existing` (`publish-registries.sh:199`, `publish-inside.sh:44`).
- crates.io: `cargo publish` errors on an existing version (`publish-inside.sh:57`).
- Maven Central: a second upload of a published version is rejected (`publish-registries.sh:256-277`).
- Unconfirmed: whether `pio pkg publish` and `compote component upload` accept a re-upload (`publish-embedded.sh:52,63`).
- Already idempotent: NuGet (`--skip-duplicate`, `publish-inside.sh:21`), vcpkg (no diff → no commit, push no-op, `publish-registries.sh:141-150`), Arduino (`publish-embedded.sh:90-93`) when the content is unchanged.

So a partial release can only be fixed with a new patch tag. Tags `v0.1.1`–`v0.1.8` were cut in two days (`components/07_ci_publish.md` §2).

**Policy is implicit and partly silent** (`scan_ci_docs.md` LF7, S32):
- `need()` (`publish-registries.sh:25-41`) fails before any write for NuGet, npm (token or OIDC) and Maven (token + GPG).
- `skip_unset` / the python branch (`:43-59`) **drop Python and Rust** from the plan with exit 0 when their credential is missing.
- `publish-embedded.sh:47-58,73-76` skips PlatformIO, ESP-IDF and Arduino with a plain `echo`.
- vcpkg has no check: it falls back to an unauthenticated `git push` (`publish-lib.sh:36-50`).
- This contradicts AC-12 ("publishes 1 package per language present") and ADR-002:39.

User decision (verbatim, 2026-10-05): "NuGet, npm, PyPI, crates.io, Maven Central, vcpkg are required: a missing credential or a failed upload fails the run. PlatformIO, ESP-IDF, Arduino are optional: skipped with a warning when their credential is missing."

## Outcome

- One declared list of publish targets, each marked required or optional, used by the credential check and the upload loop.
- Required targets: NuGet, npm, PyPI, crates.io, Maven Central, vcpkg — for the languages present in the gate plan (AC-15 unchanged).
  - A missing credential fails the run **before any write**.
  - A failed upload fails the run.
- Optional targets: PlatformIO, ESP-IDF, Arduino.
  - A missing credential means skip, with a GitHub `::warning::` annotation and a line in `$GITHUB_STEP_SUMMARY` naming the target and the missing variable.
  - A failed upload with a credential present: see Flagged concerns (default: fails the run).
- Re-running the same tag (Actions "Re-run jobs" on the same run, or a new run for the same tag ref) skips every target whose exact version is already published, logs `already published <target> <version>`, and uploads the rest. A complete earlier run re-runs to exit 0 with no writes.
- Two publish runs for the same tag never execute concurrently.

## What counts as a credential (current code)

| Target | Credential present when |
|--------|-------------------------|
| NuGet | `NUGET_TOKEN` non-empty (from `NuGet/login@v1`, `publish.yml:24-27,36`) |
| npm | `NPM_TOKEN` non-empty or OIDC available (`ACTIONS_ID_TOKEN_REQUEST_URL`) |
| PyPI | `PYPI_TOKEN` non-empty or OIDC available |
| crates.io | `CARGO_REGISTRY_TOKEN` non-empty (`crates-token.sh exchange`, `publish.yml:28-30,38`) |
| Maven Central | `MAVEN_CENTRAL_TOKEN` and `MAVEN_GPG_PRIVATE_KEY` non-empty |
| vcpkg | `GITHUB_TOKEN` non-empty for a `https://github.com/` registry URL. A non-GitHub `VCPKG_REGISTRY_URL` (the bare repos in tests) needs none |
| PlatformIO | `PLATFORMIO_AUTH_TOKEN` |
| ESP-IDF | `IDF_COMPONENT_API_TOKEN` |
| Arduino | `GITHUB_TOKEN` for a GitHub URL, or a non-GitHub `ARDUINO_REGISTRY_URL` |

## Scope

### Included
- A target table (required/optional + credential variables) in `publish-lib.sh` or beside it, used by `publish-registries.sh` and `publish-embedded.sh`. Replaces `need`, `skip_unset`, the python special case and the embedded `skip …` echoes.
- A pre-upload credential check over all planned targets: required missing → exit non-zero with all missing names listed, before any write; optional missing → warning + summary line, target skipped.
- An "already published" check per target, run in the upload phase before each upload:
  - npm: `npm view packbin@<v> version`.
  - PyPI: JSON API `pypi.org/pypi/packbin/<v>/json`, or `twine --skip-existing`.
  - crates.io: API `crates.io/api/v1/crates/packbin/<v>`, with a User-Agent.
  - Maven Central: Central Portal published-status endpoint, or `repo1.maven.org/.../packbin-<v>.pom`. **Unconfirmed** which reflects a freshly published version (Central propagation lag).
  - NuGet: keep `--skip-duplicate`.
  - vcpkg/Arduino: existing no-diff behavior. A remote tag `arduino-<v>` that points at different content fails, because the tag is immutable.
  - PlatformIO, ESP-IDF: tool query or `--allow-existing`-style flag. **Unconfirmed**.
- `concurrency` group per tag ref on `publish.yml`, without cancel-in-progress.
- `publish-gate.test.sh`: re-run and credential-matrix scenarios (Blackbox Tests).
- Docs: `_docs/02_document/deployment/deployment_procedures.md` "Rollback/Re-run" and `_docs/04_deploy/packages.md` list required/optional targets. The ADR wording itself is task D19/C29, not here.

### Excluded
- Two-phase build (task 27, prerequisite). Test gating (task 26).
- Removing the npm/PyPI token paths (D16).
- Comparing checksums of already-published artifacts with the rebuild. Builds are not byte-reproducible (timestamps in nupkg/wheel/jar), so a mismatch would be noise.

## Acceptance Criteria

**AC-1: Missing required credential fails before any write**
Given a plan containing language L and its required credential unset (each of the six, one at a time)
When the publish script runs
Then it exits non-zero naming the variable, no upload stub is called, and the bare vcpkg repo is unchanged.

**AC-2: Missing optional credential warns and continues**
Given `PLATFORMIO_AUTH_TOKEN`, `IDF_COMPONENT_API_TOKEN` and the Arduino credential unset
When the publish script runs with all required credentials set
Then it exits 0 and prints one `::warning::` line per skipped optional target. `$GITHUB_STEP_SUMMARY` names them. The required targets are uploaded.

**AC-3: Python and Rust are never silently dropped**
Given the plan contains `python` or `rust` and the credential is missing
When the script runs
Then the outcome is AC-1, not a skip with exit 0.

**AC-4: Failed required upload fails the run**
Given a required upload stub that exits non-zero
When the upload phase runs
Then the script exits non-zero.

**AC-5: Re-run completes a partial publish**
Given a first run where NuGet, npm and PyPI uploads succeeded and the crates.io upload failed
When the publish runs again for the same version with the stubs now reporting those three as published
Then it skips NuGet, npm and PyPI with `already published` lines, uploads crates.io, vcpkg, Maven and the optional targets, and exits 0.

**AC-6: Re-run of a complete publish is a no-op**
Given every target already holds the version
When the publish runs again
Then no upload command runs, the bare repos have no new commits, and the exit code is 0.

**AC-7: No concurrent runs for one tag**
Given two publish runs started for the same tag
When the second starts while the first is running
Then it waits (concurrency group) rather than running in parallel.

## Non-Functional Requirements

**Reliability**
- Each registry query has a bounded timeout and a retry for 5xx/transport errors. "Unknown" (the query failed) is not treated as "not published" for a target that would then fail on upload; the run fails with a clear message.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1/2/3 | target table + credential check with a matrix of env vars | required missing → non-zero before writes; optional missing → warning |

## Blackbox Tests

In `publish-gate.test.sh`, on the CI test path, with PATH stubs (`npm`, `twine`, `cargo`, `curl`, `pio`, `compote`, `dotnet`) logging to `$PACKBIN_PUBLISH_LOG` and answering "published"/"not published" from a scenario file, plus fake bare vcpkg/Arduino repos (pattern `publish-gate.test.sh:51-116`).

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | unset each required credential in turn | credential matrix | 6 runs, each non-zero, log empty, bare repo unchanged | Reliability |
| AC-2 | optional credentials unset | warning path | exit 0, three `::warning::` lines, summary file lists them | — |
| AC-5 | scenario "nuget, npm, pypi published" after a failed first run | re-run | exactly the remaining targets uploaded; exit 0 | Reliability |
| AC-6 | all published; bare repos pre-populated by a first run | no-op re-run | no upload lines; `git rev-list --count` unchanged | — |
| AC-7 | `publish.yml` parsed | `concurrency` key on the publish workflow/job keyed by ref, no cancel-in-progress | present | — |

## Constraints

- Canonical path only: a re-run means re-running the tag's `publish.yml` run in GitHub Actions (or a new run for the same tag ref). Never a laptop upload, never a manual registry upload, never a force-pushed tag (`deployment_procedures.md:15`; meta-rule).
- Tokens only as CI secrets or OIDC. The existence checks use read-only public APIs and must not send tokens.
- Registries stay immutable: nothing is deleted, overwritten or force-pushed.

## Risks & Mitigation

**Risk 1: Maven Central shows a version late**
- *Risk*: A deployment marked `PUBLISHED` may not appear on `repo1` for minutes, so a re-run could re-upload and be rejected.
- *Mitigation*: Use the Central Portal status API (same token) as the first source. Treat a Central "version exists" rejection as `already published`.

**Risk 2: Treating a query error as "not published"**
- *Mitigation*: NFR above: a failed query fails the run rather than guessing.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The decision covers optional targets only for a *missing credential*. An optional upload that fails with its credential present is undecided. Default in this spec: fail the run (the credential shows intent, and the run is re-runnable). Confirm | user | open | Medium |
| Re-upload behavior of `pio pkg publish` / `compote component upload` and the right existence queries are unconfirmed | implementer | open | Medium |
| ADR-002 / AC-12 / AC-13 wording still says six registries and "credentials in secret store" — doc task C29/D19, not here | doc owner | open | Low |
