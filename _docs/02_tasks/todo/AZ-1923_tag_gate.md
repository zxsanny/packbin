# Tag gate

**Task**: AZ-1923_tag_gate
**Name**: Tag gate
**Description**: A matching tag plans six publishes. A mismatch or a missing language plans zero for the registries that fail. The test job holds no token.
**Complexity**: 5 points
**Dependencies**: AZ-1913_test_infrastructure
**Component**: Blackbox Tests
**Tracker**: AZ-1923
**Epic**: AZ-1865

## Problem

The six packages can be correct alone and still ship from a bad tag, or the test job can leak a registry token.

## Outcome

- A matching tree plans six publishes, including a git push of vcpkg `packbin`, and 0 manual uploads
- A golden mismatch plans 0 publishes
- A missing language is absent from the plan
- `test.yml` does not receive registry tokens
- The published archive declaration is MIT

## Scope

### Included

- FT-P-08, FT-P-09, FT-P-10, FT-N-03, FT-N-04, NFT-SEC-01
- R-09, R-10, R-14, R-15, R-16, R-18, R-19

### Excluded

- A live upload to npm, NuGet, PyPI, crates.io, Maven Central, or GitHub
- A pull request to microsoft/vcpkg

## System Under Test Boundary

The test runs the real tag gate and the real `pack` of each present language. Registry uploads are outside the product boundary for this suite: the test asserts the plan and that no upload process starts. The vcpkg check pushes a local git remote, not GitHub. Results are compared to `results_report.md` publish rows.

## Acceptance Criteria

**AC-1: A match plans six**
Given mismatch count 0 and six languages
When the tag gate finishes
Then the plan has six publishes, manual uploads are 0, and the C++ step is a git push of port `packbin`

**AC-2: A mismatch plans zero**
Given a fixture that disagrees
When the tag gate finishes
Then publishes are 0

**AC-3: A missing language**
Given the tree has no project for one language
When the tag gate finishes
Then that language is not in the plan

**AC-4: The test job has no token**
Given `.github/workflows/test.yml`
When it is read
Then it names no registry token

**AC-5: Push and pull request**
Given a push or a pull request
When the test workflow runs
Then the suites run, and a failing test fails the check

## Non-Functional Requirements

**Reliability**
- A failed golden check does not start an upload

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4 | `test.yml` | no registry token name |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | six languages, golden match | tag gate | 6 publishes, vcpkg git push, 0 manual uploads | Reliability |
| AC-2 | fixture disagrees | tag gate | 0 publishes | Reliability |
| AC-3 | one language directory removed | tag gate | that language absent | — |
| AC-5 | the test workflow | a failing check | the check fails | — |

## Constraints

- Maven group id and artifact id are `packbin`
- The vcpkg branch is `vcpkg` on `https://github.com/zxsanny/packbin.git`
- License text is MIT

## Risks & Mitigation

**Risk 1: The gate echoes the fixture**
- *Risk*: a bad fixture still matches because the script prints the fixture
- *Mitigation*: the packed hex stays `4001000065cd1d00a3e1110100` when the fixture is `00`

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
