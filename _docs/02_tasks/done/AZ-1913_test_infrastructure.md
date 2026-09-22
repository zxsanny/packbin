# Test Infrastructure

**Task**: AZ-1913_test_infrastructure
**Name**: Test Infrastructure
**Description**: Run the blackbox checks in the six toolchain containers that already exist, and run the tag gate without uploading.
**Complexity**: 3 points
**Dependencies**: None
**Component**: Blackbox Tests
**Tracker**: AZ-1913
**Epic**: AZ-1865

## Test Project Folder Layout

```
docker-compose.test.yml
.github/workflows/run-suite.sh
.github/workflows/publish-gate.test.sh
fixtures/golden.hex
test-results/report.csv
```

There is no `e2e/` tree and no mock server. `environment.md` says the tests do not open a socket.

### Layout Rationale

Each language already has a suite. The blackbox run reuses those containers. The publish scenarios call the tag gate on the host, with a local git remote, and do not contact a registry.

## Mock Services

| Mock Service | Replaces | Endpoints | Behavior |
|-------------|----------|-----------|----------|
| none | — | — | Registries are not called. A mismatch or a missing language is asserted from the gate plan. |

### Mock Control API

None. There is no HTTP mock.

## Docker Test Environment

### docker-compose.test.yml Structure

| Service | Image / Build | Purpose | Depends On |
|---------|--------------|---------|------------|
| csharp | `mcr.microsoft.com/dotnet/sdk:10.0` | C# suite | — |
| typescript | `node:24` | TypeScript suite | — |
| python | `python:3.14` | Python suite | — |
| rust | `rust:1.98` | Rust suite | — |
| cpp | `gcc:16` | C++ suite | — |
| java | `eclipse-temurin:26-jdk` | Java suite | — |

### Networks and Volumes

No published ports. Each service mounts the repo and `fixtures/golden.hex` read-only, and writes `test-results/`.

| Mount | Host path | Container path | Mode |
|-------|-----------|----------------|------|
| Application source | `.` | `/src` | rw |
| Fixture | `./fixtures/golden.hex` | `/fixture/golden.hex` | ro |
| Results | `./test-results` | `/test-results` | rw |

## Test Runner Configuration

**Framework**: the runner already in each package, plus `publish-gate.test.sh` for the tag
**Plugins**: none
**Entry point**: `docker compose -f docker-compose.test.yml run --rm <language>`, then `bash .github/workflows/publish-gate.test.sh`

### Fixture Strategy

| Fixture | Scope | Purpose |
|---------|-------|---------|
| golden.hex | run | the position row every pack is compared to |

## Test Data Fixtures

| Data Set | Source | Format | Used By |
|----------|--------|--------|---------|
| position | inline values, compared to `fixtures/golden.hex` | hex | FT-P-01, FT-P-02, FT-P-03 |
| flags | inline | bytes | FT-P-04, FT-P-05, FT-N-01 |
| groups | inline | bytes | FT-P-06, FT-P-07, FT-N-02 |

### Data Isolation

Each call uses its own buffer. Containers are removed after `run --rm`. The publish gate uses a temporary git remote and does not push GitHub.

## Test Reporting

**Format**: CSV
**Columns**: Test ID, Test Name, Execution Time (ms), Result, Error Message
**Output path**: `./test-results/report.csv`

## Acceptance Criteria

**AC-1: The six containers run**
Given `docker-compose.test.yml`
When each language service is run
Then that language's suite finishes and no port is published

**AC-2: Registries are not called**
Given the byte suites and the tag gate
When they run
Then no process contacts npm, NuGet, PyPI, crates.io, Maven Central, or GitHub

**AC-3: The tag gate runs**
Given the six projects and `fixtures/golden.hex`
When `publish-gate.test.sh` runs
Then a match plans six publishes, a bad fixture plans zero, and a missing language is absent from the plan

**AC-4: A CSV report exists**
Given the suites have run
When the run completes
Then `./test-results/report.csv` has the columns above
