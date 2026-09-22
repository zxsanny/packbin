# Initial Project Structure

**Task**: AZ-1866_initial_structure
**Name**: Initial Structure
**Description**: Scaffold six language folders, the golden fixture, GitHub Actions, and test-only containers. No server and no database.
**Complexity**: 5 points
**Dependencies**: None
**Component**: Bootstrap
**Tracker**: AZ-1866
**Epic**: AZ-1858

## Project Folder Layout

```
packbin/
├── csharp/
├── typescript/
├── python/
├── rust/
├── cpp/
├── java/
├── fixtures/
│   └── golden.hex
├── .github/workflows/
│   ├── test.yml
│   └── publish.yml
├── docker-compose.test.yml
├── .dockerignore
├── .env.example
└── LICENSE
```

### Layout Rationale

Each language keeps the layout that language already uses. The fixture file is the only shared input. There is no `src/shared` library, because the six packages do not call each other.

## DTOs and Interfaces

### Shared DTOs

| DTO Name | Used By Components | Fields Summary |
|----------|-------------------|----------------|
| Field list | all six packages | ordered fields: name, width, endian |
| Bytes | all six packages | the packed buffer |
| Short packet | all six packages | field, needed, left |

The names are the contract. Each language declares them in that language. There is no shared generated source.

### Component Interfaces

| Component | Interface | Methods | Exposed To |
|-----------|-----------|---------|-----------|
| C# | Packbin | pack, unpack | the caller's server |
| TypeScript | packbin | pack, unpack | Vue, React, Node |
| Python | packbin | pack, unpack | tools and scripts |
| Rust | packbin | pack, unpack | a native node |
| C++ | packbin | pack, unpack | a C++ program |
| Java | packbin | pack, unpack | Android and Java |

## CI/CD Pipeline

| Stage | Purpose | Trigger |
|-------|---------|---------|
| Test | Build each language that is present and run its suite | Every push and pull request |
| Publish | Push the six registries after the golden mismatch count is 0 | A version tag |

There is no staging deploy and no third-party security scanner. The publish job refuses to run when the mismatch count is above 0. The published archive contains 0 registry tokens.

### Pipeline Configuration Notes

Host is GitHub Actions on https://github.com/zxsanny/packbin. The test job does not receive registry tokens. The publish job reads them from Actions secrets.

## Environment Strategy

| Environment | Purpose | Configuration Notes |
|-------------|---------|-------------------|
| Development | A workstation | The language toolchain. No registry token required to run tests |
| CI | GitHub Actions | Test on push. Publish on a tag |
| Registries | The published packages | npm, NuGet, PyPI, crates.io, Maven Central, vcpkg |

There is no staging host. A registry publish is the release.

### Environment Variables

| Variable | Dev | CI test | CI publish | Description |
|----------|-----|---------|------------|-------------|
| NPM_TOKEN | empty | absent | Actions secret | npm publish |
| NUGET_TOKEN | empty | absent | Actions secret | NuGet push |
| PYPI_TOKEN | empty | absent | Actions secret | PyPI upload |
| CARGO_REGISTRY_TOKEN | empty | absent | Actions secret | crates.io publish |
| MAVEN_CENTRAL_TOKEN | empty | absent | Actions secret | Maven Central upload |

`.env.example` lists those names and leaves the values empty. The C++ publish is a git push of the vcpkg registry, using the repository credential, not a sixth upload token.

## Database Migration Approach

**Migration tool**: none
**Strategy**: there is no database. A caller's field list is not stored here.

### Initial Schema

No tables. The seed is `fixtures/golden.hex`, whose position row is `4001000065cd1d00a3e1110100`.

## Containers

No product Dockerfile. No `/health/live`, `/health/ready`, or `/metrics`. The library does not log.

`docker-compose.test.yml` starts six toolchain images and publishes no ports: current .NET LTS SDK, current Node LTS, and the current stable images for Python, Rust, C++, and Java. Each mounts the fixture read-only. `.dockerignore` keeps `.env` and `test-results/` out of those builds.

## Test Structure

```
csharp/tests/
typescript/tests/
python/tests/
rust/tests/
cpp/tests/
java/tests/
```

### Test Configuration Notes

Each package tests itself against `fixtures/golden.hex`. Blackbox scenarios in `_docs/02_document/tests/` become tasks later. This task does not add a test that only asserts true.

## Implementation Order

| Order | Component | Reason |
|-------|-----------|--------|
| 1 | This scaffold | The fixture and the workflows exist before any package |
| 2 | The six packages | They can proceed in parallel |
| 3 | Blackbox tests | They need the packages |

## Acceptance Criteria

**AC-1: Project scaffolded**
Given this plan
When the implementer executes this task
Then the six language folders, `fixtures/golden.hex`, both workflow files, `docker-compose.test.yml`, `.dockerignore`, `.env.example`, and `LICENSE` exist

**AC-2: Fixture is the position row**
Given `fixtures/golden.hex`
When the position row is read
Then it is `4001000065cd1d00a3e1110100`

**AC-3: CI runs on push**
Given the scaffolded repository
When a commit is pushed
Then the test workflow runs and a failing test fails the check
