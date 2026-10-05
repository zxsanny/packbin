---
loop: 10
branch: loop/10-cpp-microcontroller
---

# C++ embedded packaging and README

**Task**: AZ-2067_cpp_embedded_packaging
**Name**: C++ embedded packaging
**Description**: packbin C++ installs from PlatformIO, Arduino and ESP-IDF from the same tag, with examples and a README embedded section.
**Complexity**: 3 points
**Dependencies**: AZ-2066_cpp_target_ci
**Component**: cpp
**Tracker**: AZ-2067
**Epic**: AZ-2059

## Problem

C++ ships only as a vcpkg port and a host Makefile; embedded developers cannot install it with their tools (`problem.md` blocker 9).

## Outcome

- PlatformIO library, Arduino library and ESP-IDF component manifests in the tree, built from the same sources.
- Examples for Pico (PlatformIO), ESP32 (Arduino) and ESP-IDF, built in CI.
- Publish steps behind the existing publish gate; registry tokens are secrets in the publish job.
- README C++ embedded section and a `_docs/01_solution/languages.md` row.

## Scope

### Included
- `library.json`, `library.properties` + Arduino `src/` layout, `idf_component.yml` + component `CMakeLists.txt`.
- Three examples, built by the AZ-2066 CI job.
- Publish steps in `publish-registries.sh` behind `publish-gate.sh`.

### Excluded
- Creating registry accounts or tokens (maintainer); cutting a release tag.

## Acceptance Criteria

**AC-1: Examples build from the packaged layout**
Given the three manifests and examples
When CI builds each example against the packaged layout (not the source tree paths)
Then all three builds succeed.

**AC-2: Installable from the embedded tools**
Given a published tag
When a fresh PlatformIO `pico` project, a fresh Arduino-ESP32 sketch and a fresh ESP-IDF project add packbin by registry name and build the README example
Then all three succeed with 0 local path or git overrides, and the installed version equals the tag (feature AC-12). Verified after the first publish, not inside this loop.

**AC-3: Publish gated and secret-free**
Given the publish workflow
When it runs without registry tokens
Then the embedded publish steps are skipped by the existing gate and 0 tokens appear in the tree.

## Non-Functional Requirements

**Compatibility**
- License MIT in every manifest.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | `publish-gate.test.sh` with and without tokens | skip without, run with |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | CI embedded image | build three examples | pass | — |
| AC-2 | published tag | fresh projects | pass, version == tag | — |

## Constraints

- C++ stays published through vcpkg too; same tag, same gate.

## Risks & Mitigation

**Risk 1: Registry accounts missing**
- *Risk*: AC-2 cannot run until the maintainer creates accounts and tokens.
- *Mitigation*: AC-2 is checked after the first publish; the loop reports it as not-run.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| PlatformIO / Arduino / ESP-IDF registry accounts and tokens | Maintainer | open | Medium |
