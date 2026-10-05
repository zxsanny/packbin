# Batch Report

**Batch**: 3 (loop 14)
**Tasks**: AZ-2096_publish_build_before_upload
**Date**: 2026-10-06

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2096_publish_build_before_upload | Done (AC-1 to AC-6 pass locally) | 5 scripts modified, 5 new (`publish-build.sh`, `publish-upload.sh`, `publish-sign.sh`, `publish-check.py`, `publish-phases.test.sh`), 3 docs | `publish-gate.test.sh` (sources `publish-phases.test.sh`), `report-row.test.sh`, `hostile/cases.test.sh` pass | 2 Medium open (below) |

## Design

- `publish-registries.sh` is the orchestrator: plan, credential and tool preflight, build phase, upload phase. `PACKBIN_BUILD_ONLY=1` runs the build phase alone with every credential unset, a throwaway GPG key and an `artifacts/dry-run` marker that `publish-upload.sh` refuses.
- Build (`publish-build.sh`, `publish-inside.sh`, `publish-embedded.sh`, `publish-sign.sh`) writes `$PACKBIN_OUT/artifacts/<target>/` and one `build ok <target>` line per target after `publish-check.py` passed. The build subshell holds no registry token (only the Maven signing key); containers get none.
- Upload (`publish-upload.sh`) refuses unless `build.log` has every planned target, builds nothing, and sends the files under `artifacts/`. Registry tools now run on the runner host (they ran in language containers before), so the host needs dotnet, cargo, npm, curl, git, gpg; the orchestrator checks this before building.
- `publish-check.py`: per target version, MIT and payload; Java also signatures, md5/sha1, class major 61 from the class bytes; vcpkg and Arduino git state.
- `pio pkg publish` takes a prebuilt `.tar.gz` and `compote component upload --archive` takes a prebuilt `.tgz` (checked in the tools' help and source: platformio 6.2.0, idf-component-manager 3.1.2). `--version` is mutually exclusive with `--archive`, so it was dropped from the compote call. No spec fallback was needed.

## Code Review Verdict: PASS_WITH_WARNINGS

`/code-review` high over the full working tree. Reported findings:

| # | Severity | Finding | Handling |
|---|----------|---------|----------|
| 1 | Medium (correctness) | The crates.io token (and the NuGet key) is exchanged in `publish.yml` before the whole, now longer, build phase. If it expires before upload, NuGet, npm and PyPI are already published when `cargo publish` fails: a partial release | Open. Not fixable without splitting `publish.yml` into build / exchange / upload, which the preflight (credentials are required before any write) and the `crates_token_checks` ordering test prevent today. The token lifetime was not confirmed and the cold-runner build time is unmeasured. Watch both on the first real tag; if the build phase nears 10 minutes, split the workflow. Carried to the leftovers |
| 2 | Medium (correctness) | `git ls-remote | grep -q .` under pipefail (SIGPIPE) or a transient network error looked like an empty registry; the build would init a fresh orphan branch and the later push would be rejected after earlier uploads | Fixed in this batch: `publish-embedded.sh` `open_registry` captures the output, a failing `ls-remote` now fails the build, and a missing branch is the empty-output case. Gate tests re-run green |
| 3 | Low (conventions) | Unpinned `pip install` of build, platformio, idf-component-manager, twine in the publish and test paths | Open, recorded; pre-existing pattern (open F-series items) |
| 4 | Low (correctness) | `chmod -R a+rwX` leaves built artifacts world-writable between check and upload | Open, recorded; the runner is single-tenant per job |
| 5 | Low (test-coverage) | The AZ-2094 `javap -v` check moved into `publish-check.py` (reads the class bytes); the fabricated-artifact test pins major 52 rejected, the full-publish scenario builds the real jar | Accepted: same rule, covered on a real build |

CI-parity: PASS. Commands: `bash .github/workflows/publish-gate.test.sh` (about 2 minutes, runs the real container builds on a tree copy), `bash .github/workflows/report-row.test.sh`, `bash fixtures/hostile/cases.test.sh`. Parent re-ran all three after the fix of finding 2. No file is over 500 lines.

## Test Suite

- `publish-gate.test.sh`: passes; the AZ-2096 scenarios cover ordering (every upload logs `build ok` count 9), failure injection (a failing `gpg` and a failing `pio pkg pack` leave the upload log and the bare repos empty), build-only (9 artifacts, empty log), 20 fabricated bad artifacts plus two real-pipeline violations, the empty plan, and static checks.
- Real-checkout check by the parent: `publish-build.sh rust` inside the repo (out dir gitignored) builds and checks; host `cargo package --list` from the staged dir lists the source files.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The ESP-IDF archive holds the whole `cpp/` tree (`tests/`, `embedded/`, `Makefile`), not only the manifest's include list; the old upload packed the same | AZ-2096 Scope | Separate task to trim it | clear |
| 2 | `python/pyproject.toml` `project.license` as a TOML table is deprecated (setuptools breaks it after 2027-02-18) | AZ-2096 | Change to an SPDX string in a later task | clear |
| 3 | PyPI and npm OIDC upload branches moved but no test exercises them | AZ-2096 AC-5 | Prove on the first real tag | unclear |
| 4 | `cargo publish --no-verify` re-archives the staged dir from the runner host, so the uploaded `.crate` may differ slightly from the checked one (for example `.cargo_vcs_info.json`) | AZ-2096 Risk 1 | Accepted by the spec's fallback wording | clear |
| 5 | Upload now needs dotnet, cargo, npm, curl, git, gpg on the host; believed preinstalled on ubuntu-latest, unverified | AZ-2096 | Preflight names a missing tool before any write | clear |

## Commit

`[AZ-2096] Build and check every artifact before the first upload`. Body: one line + `Loop: 14`.

## Next Batch: AZ-2097_publish_rerun_and_registry_policy
