# Build and verify every artifact before the first upload

**Task**: 27_publish_build_before_upload
**Name**: Two-phase publish (build, then upload)
**Description**: A tag run builds, signs and checks every package for every planned registry first; uploads start only when all of them succeeded.
**Complexity**: 3 points
**Dependencies**: 25_java_release_17 (the Java build moves into the build phase with `--release 17`); 26_publish_after_tests (same workflow file)
**Component**: ci-publish
**Tracker**: pending
**Epic**: AZ-2069

## Problem

`.github/workflows/publish-registries.sh` builds and uploads one registry at a time, in plan order. The plan is `csharp typescript python rust cpp java` (`publish-lib.sh:4`; loop at `publish-registries.sh:284-313`):

| Step | Builds | Uploads in the same step | Where |
|------|--------|--------------------------|-------|
| csharp | `dotnet pack` | `dotnet nuget push` | `publish-inside.sh:15-22` (container) |
| typescript | staged copy + `npm version` | `npm publish` (OIDC) | `publish-registries.sh:202-213` (host) or `publish-inside.sh:23-30` (token) |
| python | `python -m build` | `twine upload` (OIDC mint) | `publish-registries.sh:153-200` (host) or `publish-inside.sh:31-45` |
| rust | staged copy + version rewrite | `cargo publish` (compiles while publishing) | `publish-inside.sh:46-58` |
| cpp | vcpkg port commit; then PlatformIO, ESP-IDF and Arduino staging | `git push` vcpkg; `pio pkg publish`; `compote component upload`; `git push` Arduino | `publish-registries.sh:126-151`, `publish-embedded.sh:96-99` |
| java | `javac`/`jar`/POM in container, then GPG sign + md5/sha1 + zip on host | Central upload + poll | `publish-registries.sh:300-302`, `:215-277` |

Consequences:
- A failure in a later build — the Java bundle, GPG import (`:227-229`), the python `build` venv, `cargo` compile, `pio`/`compote` staging — happens **after** earlier registries already hold the version. The release is partial, and registries are immutable.
- The Java bundle, the most failure-prone step (signing, Central polling 90 × 15 s), runs last.
- `git log`/`git tag` show `v0.1.1`–`v0.1.8` cut on 2026-09-23/24, mostly to fix publishing (`components/07_ci_publish.md` §2).
- ADR-002:39 says "A bad golden check cannot ship five languages and skip one". The gate holds for byte mismatches but not for build failures.
- Nothing checks the built artifacts themselves: version string, license, contents. The gate runs the drivers against the source tree (`publish-gate.sh`, LF17).

Source: `scan_ci_docs.md` LF5, LF17, change D5; `list-of-changes.md` C11.

## Outcome

- The publish run has two phases. **Build**: every artifact for every planned target is produced and checked. **Upload**: transmit only. The upload phase starts only when the build phase succeeded for all planned targets.
- Planned targets = the present languages from the gate plan, plus the three embedded targets of `cpp`. Built artifacts sit in one directory (e.g. `.github/workflows/out/artifacts/<target>/`), so the upload phase does not rebuild.
- A build-only mode runs the build phase and stops with no network writes. CI tests use it, and it can serve as a dry run.
- Each artifact is checked before upload: it carries the tag version; it declares MIT (AC-16); it holds the expected files (e.g. nupkg contains `Packbin.dll`, the wheel contains `packbin/__init__.py`, the jar's class files are major 61 per task 25, the npm tarball contains `package.json` with the version).

## Scope

### Included
- Split `publish-registries.sh` / `publish-inside.sh` / `publish-embedded.sh` into a build phase and an upload phase:
  - NuGet: nupkg built; push reads the file.
  - npm: tarball from `npm pack` of the staged dir; publish takes the tarball.
  - PyPI: wheel + sdist; twine uploads the files.
  - crates.io: `cargo package` (compiles and verifies); publish from the same staged dir without re-verifying.
  - Maven: bundle zipped and signed in the build phase.
  - vcpkg and Arduino: commits prepared in local clones; upload = `git push`.
  - PlatformIO: package archive packed; publish takes it.
  - ESP-IDF: component archive packed; upload takes it.
- A build-only switch (environment variable or argument). In that mode the scripts must not call any registry upload or `git push`.
- Artifact checks listed under Outcome, with a non-zero exit and the target named on failure.
- `publish-gate.test.sh`: a build-only run, and a failure-injection run (see Blackbox Tests), both with stubbed upload commands and fake bare git registries, as `registry_checks` already does (`:51-116`).

### Excluded
- Skipping already-published versions on re-run, and required/optional registry policy — task 28.
- Running the tests before publish — task 26.
- Building C++ for vcpkg consumers (task 29). This task only moves the existing port staging into the build phase.
- Checking the golden bytes from inside the built artifacts. It is recommended, but listed as a concern.

## Acceptance Criteria

**AC-1: No upload before every build succeeded**
Given a plan with all six languages and the embedded targets
When the publish script runs
Then every upload command (`dotnet nuget push`, `npm publish`, `twine upload`, `cargo publish`, Central `upload`, `git push` to vcpkg/Arduino, `pio pkg publish`, `compote component upload`) is invoked only after the build phase logged success for all planned targets.

**AC-2: A late build failure writes nothing**
Given the Java bundle signing fails (e.g. `gpg` exits 1), or any other target's build fails
When the publish script runs
Then it exits non-zero, no upload command is invoked, and the fake vcpkg/Arduino bare repositories have no new commits or refs.

**AC-3: Build-only mode makes no network writes**
Given the build-only switch
When the script runs with all credentials unset
Then all artifacts are produced and checked, the script exits 0, and no upload or push command runs.

**AC-4: Artifacts are verified**
Given a built artifact whose version is not the tag version, or which lacks its license or main payload
When the build phase checks it
Then the run fails before upload and names the target and the failed check.

**AC-5: Uploads send the checked files**
Given a successful build phase
When the upload phase runs
Then each registry receives the file built in the build phase. No second `dotnet pack`, `npm pack`, `python -m build`, `cargo package` or bundle zip runs.

**AC-6: Gate order unchanged**
Given the golden gate fails (`publish-gate.sh` mismatch > 0)
When `publish.yml` runs
Then neither the build phase nor uploads run. The existing `publish-gate.test.sh:33-38,129-177` checks still pass.

## Non-Functional Requirements

**Reliability**
- A partial release can only come from an upload failure (network or registry), not from a build failure. Task 28 makes such a run re-runnable.

**Performance**
- No extra full builds. Build and upload together take no longer than today plus the artifact checks.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | artifact check on a fabricated nupkg/wheel/tarball with a wrong version | non-zero, names target |
| AC-3 | build-only mode with credentials unset | exit 0; artifacts present; upload stub log empty |

## Blackbox Tests

All in `publish-gate.test.sh`, on the canonical CI test path (`test.yml` `scaffold` job), with PATH stubs for upload tools logging to `$PACKBIN_PUBLISH_LOG` (pattern at `:58-68`) and bare repos from `git init --bare` (pattern at `:92-97,102-106`).

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | full plan; stubs for `dotnet nuget push`, `npm publish`, `twine`, `cargo publish`, `curl` (Central), `pio`, `compote`; bare vcpkg + Arduino repos | ordering | every "build ok" log line precedes the first stub upload line | Reliability |
| AC-2 | as above, plus a `gpg` stub that exits 1 | failure injection | exit ≠ 0; upload log empty; `git --git-dir=<bare> rev-parse --verify vcpkg` fails (no ref created) | Reliability |
| AC-3 | build-only switch, no credentials | dry run | exit 0; artifact directory holds one artifact per planned target | — |
| AC-6 | existing bad-fixture scenario | gate | unchanged: plan empty, nothing built | — |

## Constraints

- Canonical path only: `publish.yml` on a `v*` tag. Build-only mode is for CI tests and dry runs. It must never become a laptop publish path (R-15, `_docs/04_deploy/deploy_scripts.md`).
- Tokens only as CI secrets. Build-only mode needs none and must not read any.
- `bash.md`: strict mode, `mktemp` + `trap` for temp dirs (npmrc and GPG keyring are removed on exit), no `2>/dev/null`.
- Stay within the 500-line soft cap. `publish-registries.sh` is 313 lines today; split by responsibility (build vs upload), not by chopping.

## Risks & Mitigation

**Risk 1: A registry tool cannot upload a prebuilt file**
- *Risk*: `cargo publish` always re-packages; whether `compote` accepts a prebuilt archive is unverified.
- *Mitigation*: For cargo, `cargo package` in the build phase is the verification, and `cargo publish --no-verify` uploads from the same staged dir. For `compote`, check its flags at task start. If prebuilt upload is impossible, document that its upload re-packs the verified staged dir.

**Risk 2: OIDC tokens expire during a long build phase**
- *Mitigation*: Mint the PyPI token in the upload phase, as today. Crates.io and NuGet exchanges happen in earlier workflow steps (`publish.yml:24-30`); check their lifetime against the build-phase duration. Move them after the build phase if needed.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `compote component upload` from a prebuilt archive, and `pio pkg publish` of a tarball, are unconfirmed flags | implementer (check tool docs at start) | open | Medium |
| Running the golden position check against the built artifacts (installed nupkg/wheel/jar) would close LF17 but adds per-language consumer setups. Recommended follow-up, not in this task | plan owner | open | Low |
| Arduino and vcpkg "uploads" are git pushes. A failed push after other uploads still leaves a partial release; task 28 makes the re-run finish it | task 28 | accepted-risk | Low |
