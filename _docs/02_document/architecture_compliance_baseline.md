# Architecture compliance baseline

**Date**: 2026-09-23
**Mode**: baseline (context + architecture)
**Verdict**: PASS

## Scope

Six language packages, `module-layout.md`, and Accepted ADR-001, ADR-002, and ADR-003.

## Checks

| Check | Result |
|-------|--------|
| Layer direction | Pass. The six packages are peers and import nothing else in the repo |
| Public API | Pass. No component imports another component's internal file |
| Cycles | Pass. 0 |
| Duplicate symbols | Pass. Each language has its own `pack` / `unpack`. ADR-001 requires that |
| Cross-cutting | Pass. `fixtures/golden.hex` is a file read. There is no `shared/` code package |
| ADR-001 | Pass. No generator. Each package walks a caller-owned field list |
| ADR-002 | Pass. `publish.yml` runs on a `v*` tag. `test.yml` does not hold registry secrets |
| ADR-003 | Pass. C++ publish is a git push of a vcpkg port, not a curated microsoft/vcpkg pull request |

## Findings

| # | Severity | Category | File:Line | Title |
|---|----------|----------|-----------|-------|
| — | — | — | — | — |

No High or Critical items for the first product loop.
