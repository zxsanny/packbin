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
| cpp-embedded | Ubuntu 24.04 image with arm-none-eabi GCC and QEMU | Builds the C++ core for Cortex-M0+, M3, M4F and s390x; runs the vectors on QEMU `mps2-an385` and `qemu-s390x`; reports size and stack | none |
| cpp-embedded-esp | `espressif/idf:v5.3.2` | Builds the C++ core for ESP32-S3 and ESP32-C3 and the packaged examples | none |

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

**When to run**: every branch push and every pull request; a version tag runs the tests once, through `publish.yml`
**Pipeline stage**: test, before a tag is allowed to publish: `publish.yml` calls `test.yml` and the `publish` job needs it
**Gate behavior**: a failing test fails the check
**Timeout**: `timeout-minutes` on every job: 60 for `scaffold`, 90 for `embedded` (about 40 minutes cold), 60 for `publish`

## Reporting

**Format**: CSV
**Columns**: Test ID, Test Name, Execution Time (ms), Result (PASS/FAIL/SKIP), Error Message (if FAIL)
**Output path**: `./test-results/report.csv`

## Test Execution

1. **Decision**: docker
2. **Hardware dependencies found**: none. The embedded targets run on emulators: QEMU Cortex-M (`mps2-an385`, `mps2-an386`) and `qemu-s390x`; ESP32 targets are build-only. Restrictions forbid a GPU. The research MVE is a CPU loop. No product source imports a GPU, camera, or device API.
2a. **Memory and timing checks (loop 20)**: the pack budget AC-1 tests measure peak memory in a child process, so they need a spawnable interpreter on the runner: TypeScript `support/lone-utf8-budget.ts` under `node`, Python a child `python` that finds the package through the parent's import path, Java a child JVM with a small heap (`LoneUtf8Budget`). C# asserts managed allocation on the pack thread and Rust asserts time only. Slow cases kept at spec size: Rust debug AC-4 rows 8 to 18 s, Python suite about 25 s, Python hostile element case 7.1 s. The arm embedded stage reports flash 8160 of 8192 B and stack 448 of 512 B after loop 20.
3. **Execution instructions**:
   - **Docker mode**: one container per language, plus the two embedded containers for C++: current .NET LTS SDK, current Node LTS, and the current stable images for Python, Rust, C++, and Java. Each runs its package suite against the fixture file. Results are the CSV written to `./test-results/report.csv`. No port is published.
