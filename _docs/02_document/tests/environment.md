# Test Environment

## Overview

**System under test**: the six language packages. The public entry points are `pack` and `unpack` of a field list the caller supplies.
**Consumer app purpose**: a test program that calls those two functions and compares the bytes and the errors. It does not import private helpers.

## Docker Environment

### Services

| Service | Image / Build | Purpose | Ports |
|---------|--------------|---------|-------|
| csharp-tests | SDK image for the current .NET LTS | Runs the C# pack and unpack checks | none |
| typescript-tests | Node image for the current Node LTS | Runs the TypeScript pack and unpack checks | none |
| python-tests | current stable Python image | Runs the Python pack and unpack checks | none |
| rust-tests | current stable Rust image | Runs the Rust pack and unpack checks | none |
| cpp-tests | current stable C++ image | Runs the C++ pack and unpack checks | none |
| java-tests | current stable Java image | Runs the Java pack and unpack checks | none |

### Networks

| Network | Services | Purpose |
|---------|----------|---------|
| none | — | The tests do not open a socket |

### Volumes

| Volume | Mounted to | Purpose |
|--------|-----------|---------|
| fixtures | each language service, read-only | The hex rows in `results_report.md` |

### docker-compose structure

```yaml
# Outline only — not runnable code
services:
  csharp-tests:
    # current .NET LTS SDK
  typescript-tests:
    # current Node LTS
  python-tests:
    # current stable Python
  rust-tests:
    # current stable Rust
  cpp-tests:
    # current stable C++
  java-tests:
    # current stable Java
```

## Consumer Application

**Tech stack**: the test runner for each language
**Entry point**: the suite command in that package

### Communication with system under test

| Interface | Protocol | Endpoint / Topic | Authentication |
|-----------|----------|-----------------|----------------|
| pack | in-process function | field list in, bytes out | none |
| unpack | in-process function | bytes in, value or error out | none |

### What the consumer does NOT have access to

- No private fields of the walker
- No second copy of the field list hidden inside the package
- No network service

## CI/CD Integration

**When to run**: every push and every pull request
**Pipeline stage**: test, before a tag is allowed to publish
**Gate behavior**: a failing test fails the check
**Timeout**: 5 minutes for the whole suite

## Reporting

**Format**: CSV
**Columns**: Test ID, Test Name, Execution Time (ms), Result (PASS/FAIL/SKIP), Error Message (if FAIL)
**Output path**: `./test-results/report.csv`

## Test Execution

1. **Decision**: docker
2. **Hardware dependencies found**: none. Restrictions forbid a GPU. The research MVE is a CPU loop. No product source imports a GPU, camera, or device API.
3. **Execution instructions**:
   - **Docker mode**: one container per language: current .NET LTS SDK, current Node LTS, and the current stable images for Python, Rust, C++, and Java. Each runs its package suite against the fixture file. Results are the CSV written to `./test-results/report.csv`. No port is published.
