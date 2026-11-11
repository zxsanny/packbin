---
loop: 99
branch: dev
---

# Dart release: ADR-011, golden gate and the pub.dev target

**Task**: AZ-4147_dart_release
**Name**: Dart release: ADR-011, golden gate and the pub.dev target
**Description**: Dart in the golden gate and a pub.dev publish target, proven by a dry run.
**Complexity**: 5 points
**Dependencies**: AZ-4145_dart_ci_suite, AZ-4146_dart_ring
**Component**: dart
**Tracker**: AZ-4147
**Epic**: AZ-4133

## Problem

A release must publish all packages or none (the golden gate), and Dart users install from pub.dev. pub.dev takes a CI upload only through a GitHub OIDC token from a tag-triggered run, and only once the package exists, so the first version is published by the owner by hand. This task builds the path and proves it without uploading.

Feature criteria, scenarios and decisions: `_docs/02_task_plans/dart-package/` (`acceptance_criteria.md` DT-1 to DT-20, `scenarios.md`, `problem.md` D-1 to D-5 and A-1 to A-7, `task_map.md` for the write sets).

## Outcome

- A Dart golden mismatch publishes 0 packages of any language.
- The release run has a `pubdev` target that sets the version from the tag and uploads through the official mechanism.
- `dart pub publish --dry-run` reports 0 errors and 0 warnings.

## Scope

### Included

- ADR-011 "Dart publishes to pub.dev from the version tag" and the ADR index: the official mechanism (read from the pub.dev documentation on automated publishing, cited in the ADR), the tag pattern, the one-time owner steps (first publish by hand, turning on automated publishing for the repository), and what happens for a version pub.dev already has.
- `publish-lib.sh` (`dart` in the language list, the `pubdev` target and its tier, `language_present`), `publish-gate.sh` path for Dart, `publish-build.sh` and `publish-inside.sh` (prepare the package with the tag's version in `pubspec.yaml` and the `CHANGELOG.md` check), `publish-check.py` (name `packbin`, version equals the tag, SDK constraint, 0 runtime dependencies, license), `publish-upload.sh`, `publish-query.sh` (is the version on pub.dev), `publish-registries.sh`, `publish.yml` permissions for the OIDC token, `docker-compose.publish.yml` (a read-only `dart` service), `publish-jobs-layout.py` and the publish-gate jobs of `test.yml` (Dart in an existing group), and the tests of each.
- `_docs/04_deploy/packages.md` Dart section.
- Owns: `.github/workflows/publish*` except `publish-position.sh` and its test, `docker-compose.publish.yml`, `.github/workflows/publish.yml`, the publish-gate jobs of `test.yml`, `_docs/02_document/adr/011_*` and the ADR index, `_docs/04_deploy/packages.md`.

### Excluded

- A real upload to pub.dev and any tag (owner's go, after this loop)
- Reserving the name on pub.dev (owner)

## Acceptance Criteria

**AC-1: All or nothing (DT-10, S12)**
Given a tree whose Dart position output differs from the golden hex
When the publish gate runs
Then 0 packages planned for upload, for all nine languages; the run fails naming Dart

**AC-2: Prepared package (DT-10, S11)**
Given a tag `v9.8.7` in a test repository
When the Dart package is prepared and checked
Then `pubspec.yaml` says `version: 9.8.7`; `publish-check.py` passes; `dart pub publish --dry-run` reports 0 errors and 0 warnings; a consumer with a path dependency on the prepared package resolves with 0 runtime dependencies and prints the golden hex

**AC-3: Already published (DT-10, S12)**
Given a version the query reports as already on pub.dev (stubbed registry answer in the test)
When the release run reaches the Dart target
Then reported as already published; no upload attempted; the run does not fail on it

**AC-4: No Dart tree (DT-10)**
Given a tree without `dart/pubspec.yaml`
When the release run plans its targets
Then the `pubdev` target is skipped; the other targets are unchanged

**AC-5: Missing credential or permission**
Given a run without the OIDC permission
When the plan is made
Then the run fails before any write of any registry (a required target), as the other required targets do

**AC-6: No upload in this loop (DT-10)**
Given the tests of this task
When run
Then real uploads 0: every upload is a dry run or a stub

## Non-Functional Requirements

**Reliability**
- Uncaught exceptions from unpack on any input: 0.

**Compatibility**
- Dart 3.13 and newer, native targets (VM and ahead-of-time); no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | All or nothing: a tree whose Dart position output differs from the golden hex | 0 packages planned for upload, for all nine languages; the run fails naming Dart |
| AC-2 | Prepared package: a tag `v9.8.7` in a test repository | `pubspec.yaml` says `version: 9.8.7`; `publish-check.py` passes; `dart pub publish --dry-run` reports 0 errors and 0 warnings; a consumer with a path dependency on the prepared package resolves with 0 runtime dependencies and prints the golden hex |
| AC-3 | Already published: a version the query reports as already on pub.dev (stubbed registry answer in the test) | reported as already published; no upload attempted; the run does not fail on it |
| AC-4 | No Dart tree: a tree without `dart/pubspec.yaml` | the `pubdev` target is skipped; the other targets are unchanged |
| AC-5 | Missing credential or permission: a run without the OIDC permission | the run fails before any write of any registry (a required target), as the other required targets do |
| AC-6 | No upload in this loop: the tests of this task | real uploads 0: every upload is a dry run or a stub |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the `dart` service of `docker-compose.test.yml` (from AZ-4145 on) or `dart test` in `dart/` | the task's tests run on the real package and the shared fixtures read as files | all pass; no fixture is copied into the test code | Reliability |

## Constraints

- The official pub.dev mechanism only: no stored long-lived token copied from a developer machine unless the documentation names that as supported for CI; if the documented mechanism cannot be met by this repository's release run, STOP and report (no workaround).
- The test job count stays ≤ 20.
- Published versions are never deleted; a bad one is fixed by the next patch (pub.dev can retract, which the ADR mentions).
- No file over 500 lines.

## Risks & Mitigation

**Risk 1: The first publish is manual**
- *Risk*: Automated publishing cannot create a package.
- *Mitigation*: ADR-011 and `packages.md` give the owner the exact one-time steps; the loop record lists them as owner items.

**Risk 2: Tag-triggered requirement**
- *Risk*: pub.dev may require the workflow to be triggered by the tag push itself with a matching pattern.
- *Mitigation*: The task reads the documentation first and shapes `publish.yml` to it; the finding is quoted in the ADR.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| pub.dev first publish and automated-publishing setting are the owner's steps | owner | open | High |
