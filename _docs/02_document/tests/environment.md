# Test Environment

## Overview

**System under test**: the seven language packages (the six first packages and Go, added in loop 24). The public entry points are `pack` and `unpack` of a field list the caller supplies.
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
| go | `golang:1.27` (compose service `go`; `go.mod` names `go 1.26.0`, G-2) | Runs `run-suite.sh go`: `gofmt -l`, `go vet`, `go test -race`, the AC-10 speed bound without `-race`, `FuzzUnpack` for 60 s, the one-dependency check (loop 24, AZ-2448) | none |
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
  go:
    # golang:1.27, runs .github/workflows/run-suite.sh go
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
**Timeout**: `timeout-minutes` on every job: 60 for `scaffold`, 90 for `embedded` (about 40 minutes cold), 30 for `ring`, 60 for `publish`. The `go` suite adds about 2 minutes to `scaffold` (race tests about 30 s, the speed run, 60 s of fuzzing)

## Reporting

**Format**: CSV
**Columns**: Test ID, Test Name, Execution Time (ms), Result (PASS/FAIL/SKIP), Error Message (if FAIL)
**Output path**: `./test-results/report.csv`

## Test Execution

1. **Decision**: docker
2. **Hardware dependencies found**: none. The embedded targets run on emulators: QEMU Cortex-M (`mps2-an385`, `mps2-an386`) and `qemu-s390x`; ESP32 targets are build-only. Restrictions forbid a GPU. The research MVE is a CPU loop. No product source imports a GPU, camera, or device API.
2a. **Memory and timing checks (loop 20)**: the pack budget AC-1 tests measure peak memory in a child process, so they need a spawnable interpreter on the runner: TypeScript `support/lone-utf8-budget.ts` under `node`, Python a child `python` that finds the package through the parent's import path, Java a child JVM with a small heap (`LoneUtf8Budget`). C# asserts managed allocation on the pack thread and Rust asserts time only. Slow cases kept at spec size: Rust debug AC-4 rows 8 to 18 s, Python suite about 25 s, Python hostile element case 7.1 s. The arm embedded stage reports flash 8160 of 8192 B and stack 448 of 512 B after loop 20.
2b. **Go (loop 24)**: Go is not installed on the owner's Mac (G-2), so Go runs only in `golang:1.27`: `mkdir -p test-results && docker compose -f docker-compose.test.yml run --rm go` is the suite as CI runs it, and it is the only local way to run Go tests (a `go test` on the host does not exist). The ring needs a host binary of the Go driver: `.github/workflows/ring-go.sh` builds `.github/workflows/drivers/handoff-go/` with the host `go` on CI (`actions/setup-go`, SHA-pinned, `RING_GO` 1.27) and, on a Mac, cross-compiles a host binary in `golang:${RING_GO}` and rebuilds it only when a source is newer; `ring-toolchains.sh` checks the Go version. `RING_GO` is kept equal to the `go` service image by `ring-wiring.test.sh`. The Go suite shares the fixture volume (`/fixture/golden.hex`) with the other services. The AC-7 speed bound (project AC-10) is asserted only without `-race`, on a quiet host: check `uptime` first, it failed twice at load 79 to 87 with the race detector on. Memory is not measured for Go (assessment D8). The first run on the Ubuntu runner is unproven.
3. **Execution instructions**:
   - **Docker mode**: one container per language, plus the two embedded containers for C++: current .NET LTS SDK, current Node LTS, the current stable images for Python, Rust, C++, and Java, and `golang:1.27` for Go. Each runs its package suite against the fixture file. Results are the CSV written to `./test-results/report.csv`. No port is published.
