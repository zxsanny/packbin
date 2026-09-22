# Publish pipeline

**Task**: AZ-1875_pipeline_publish
**Name**: Publish pipeline
**Description**: The version tag runs the six packages against the golden fixture and pushes a registry only when every present language matches.
**Complexity**: 5 points
**Dependencies**: AZ-1876_csharp_pack, AZ-1877_typescript_pack, AZ-1878_python_pack, AZ-1879_rust_pack, AZ-1880_cpp_pack, AZ-1881_java_pack
**Component**: workflows
**Tracker**: AZ-1875
**Epic**: AZ-1858

## Problem

Six packages can each be correct alone and still ship from different commits, or ship when one language disagrees. The tag job is the only place that sees all six results.

## Outcome

- A version tag runs pack on every language present in that commit, against `fixtures/golden.hex`
- Mismatch count 0 publishes one package per present language: npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and vcpkg `packbin`
- Mismatch count above 0 publishes 0 packages
- A language whose project is absent publishes 0 packages to its registry
- Manual uploads: 0

## Scope

### Included

- The tag job calls each present package's pack, in this order: C#, TypeScript, Python, Rust, C++, Java
- The seam value is the position hex `4001000065cd1d00a3e1110100`
- The C++ push is a git push of the public vcpkg registry
- The other five pushes are the registry uploads named above

### Excluded

- Pack and unpack inside a package
- A pull request to the curated microsoft/vcpkg registry
- A laptop upload
- F1 and F2. Those stay inside one package

## Acceptance Criteria

**AC-1: The tag calls every present package**
Given all six projects are in the tagged commit
When the tag job runs
Then it calls pack on C#, TypeScript, Python, Rust, C++, and Java, and each call uses the real package, not a stand-in

**AC-2: A match publishes six packages**
Given the mismatch count is 0
When the tag job finishes
Then exactly six packages exist from that commit, and manual uploads are 0

**AC-3: A mismatch publishes nothing**
Given any present language disagrees with the fixture
When the tag job finishes
Then packages published are 0

**AC-4: A missing language publishes nothing**
Given the tagged tree has no project for one language
When the tag job finishes
Then that registry receives 0 packages

**AC-5: The six results agree or nothing ships**
Given the six projects are in the tree
When their position bytes are compared
Then the mismatch count is 0, or the tag publishes 0 packages

## Non-Functional Requirements

**Performance**
- The publish job is one tag. It has no latency target.

**Compatibility**
- Install names stay npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, vcpkg `packbin`.

**Reliability**
- A failed golden check does not leave a partial publish.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the tag job's call list | six real pack calls when all six projects are present |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | mismatch count 0, six languages in the tree | push a version tag | 6 packages, 0 manual uploads | — |
| AC-3 | one language disagrees | push a version tag | 0 packages | — |
| AC-4 | one language project is absent | push a version tag | that registry receives 0 packages | — |
| AC-5 | six position buffers | compare them | mismatch count is 0, or the publish is 0 packages | — |

## Constraints

- Registry tokens stay in GitHub Actions secrets
- The test workflow does not receive those tokens
- ADR 002 and ADR 003

## Risks & Mitigation

**Risk 1: R01 drift**
- *Risk*: one hand-written list differs
- *Mitigation*: mismatch count above 0 publishes 0 packages

**Risk 2: R02 vcpkg**
- *Risk*: a pushed port version stays
- *Mitigation*: the golden check runs before the git push

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
