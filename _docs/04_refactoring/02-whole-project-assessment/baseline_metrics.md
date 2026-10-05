# Baseline Metrics — whole-project assessment

**Run**: `02-whole-project-assessment` (Quick Assessment: phases 0–2, no code changes)
**Date**: 2026-10-05
**Tree**: `loop/10-cpp-microcontroller` at `d108141` (dev `1a15ce3` + loop 10)
**Scope**: all six packages (C#, TypeScript, Python, Rust, C++, Java), CI drivers, CI/publish scripts, embedded harness.
**Goal** (user, 2026-10-05): find refactoring needs across the whole project before the `v0.2.0` tag. Problem, ACs and restrictions: `_docs/00_problem/` (unchanged by this run).

## Tests and build (CI containers, `docker compose -f docker-compose.test.yml run --rm <lang>`)

| Package | Result | Tests | Wall time |
|---------|--------|-------|-----------|
| C# (.NET 10, xunit) | PASS | 52 | 13 s |
| TypeScript (node 24, node:test) | PASS | 44 test blocks | 2 s |
| Python (pytest) | PASS | 44 | 6 s |
| Rust (cargo test) | PASS | 52 | 6 s |
| C++ (gcc 16, make) | PASS | 196 expect sites + 7 compile-fail | 5 s |
| Java (javac + custom runner) | PASS | custom runner (no per-test count) | 3 s |
| Language pairs (6 × 4 cases) | PASS | — | — |
| C++ embedded (QEMU, ESP-IDF, examples) | PASS | 10 targets | ~40 min cold (toolchain downloads), minutes warm |

Host throughput (project AC-10, 100 000 round trips): C++ 13 ms; earlier loops recorded the other packages under 1 s.

## Coverage

Not measured for any package. No CI job collects coverage; only `csharp/tests/Packbin.Tests.csproj` references `coverlet.collector`, and nothing runs it. The quality thresholds (75% business logic, 90% critical path) cannot be checked today — recorded as a finding.

## Size and complexity (lizard 1.24, cyclomatic complexity)

| Package | Source NLOC | Functions | Avg CCN | CCN > 10 | Functions > 50 NLOC | Largest file |
|---------|-------------|-----------|---------|----------|---------------------|--------------|
| C# | 1755 | 186 | 2.4 | 4 | 3 | `Walker.cs` 455 lines |
| TypeScript | 1428 | 44 | 4.4 | 2 | 1 | `walker.ts` 458 lines |
| Python | 1214 | 89 | 3.7 | 4 | 2 | `_nodes.py` 424 lines |
| Rust | 2655 | 139 | 3.2 | 3 | 6 | `scheme/bound.rs` **514 lines** (over the 500 soft cap) |
| C++ | 2229 | 178 | 3.4 | 11 | 0 | `table.hpp` 367 lines |
| Java | 1883 | 166 | 3.0 | 7 | 0 | `Walker.java` 497 lines |
| CI drivers | 1383 | 93 | 3.5 | 8 | 1 | `handoff-rust/src/main.rs` 268 lines |

Test code: C# 1515, TypeScript 1408, Python 889, Rust 1744, C++ 1604 (+532 embedded harness), Java 1390 NLOC.

Most complex functions (the walkers):

| Function | CCN | NLOC |
|----------|-----|------|
| Rust `walk/pack.rs` `pack_one` | 72 | 212 |
| Rust `walk/unpack.rs` `unpack_one` | 66 | 325 |
| Python `_unpack.py` `unpack_nodes` | 57 | 171 |
| Python `_pack.py` `pack_nodes` | 48 | 117 |
| TypeScript `walker.ts` `packFields` | 43 | 115 |
| C++ `pack_one` / `unpack_one` | 23 / 22 | 42 / 49 |
| C# `Walker.WriteScalar` / `PackField` | 19 / 17 | 70 / 57 |
| Java `Walker.packField` / `unpackField` | 19 / 17 | 29 / 27 |

## Dependencies

| Package | Runtime | Dev / test |
|---------|---------|------------|
| C# | none | xunit 2.9.3, xunit.runner.visualstudio 3.1.4, Microsoft.NET.Test.Sdk 17.14.1, coverlet.collector 6.0.4 |
| TypeScript | `@noble/hashes` 2.4.0 (pinned) | typescript ^5.9.2 |
| Python | none | pytest (CI image) |
| Rust | none | none |
| C++ | none (core: 5 freestanding headers) | none |
| Java | none (no build tool: `java/test.sh` + javac) | none |

Last security dependency scan: `_docs/05_security/dependency_scan.md` (2026-09-29).

## Scripts and CI

`.github/workflows/`: 2 workflows, 13 shell scripts (largest: `publish-gate.test.sh` 403 lines, `publish-registries.sh` 313 lines). Embedded harness `cpp/embedded/`: 5 scripts (largest `arm.sh` 260 lines).

## Functionality inventory

| Capability | C# | TS | Py | Rust | C++ | Java |
|------------|----|----|----|------|-----|------|
| Scalars, be, bytes | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| flags, flag byte, group, when, bool | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| repeat, times, sized, u2, bits, packed | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| utf8, list, dict | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Typed scheme + type-number dispatch | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Field-order check | runtime | runtime | runtime | runtime | compile time + runtime | runtime |
| PackSession (HKDF + ChaCha20 pad) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| No heap / no exceptions | — | — | — | — | ✓ | — |

## Observations already visible (input to phase 1)

1. Walkers in Rust, Python and TypeScript are single functions with CCN 43–72 (C++ split the same walker to CCN ≤ 23 this loop).
2. `rust/src/scheme/bound.rs` is over the 500-line soft cap; `Walker.java` (497) and `walker.ts` (458) are close.
3. No coverage measurement anywhere.
4. `cpp/build/` is shared between the macOS host and the Linux containers, so a host binary can be run by the container's `make` (seen twice this loop).
5. The embedded CI job downloads ~2 GB of toolchains per run with no cache.
