# Autodev Loop Plan — Loop 72

loop: 72
kind: product
confirmed: true
branch: dev
ship: false

Feature: harden frame mode in C#, Java and Swift (loop 71 review items 5, 6, 7, 8, 10). Plan dir: `_docs/02_task_plans/frame-hardening-csharp-java-swift/`. Tasks: AZ-3254 (C#, 3), AZ-3255 (Java, 3), AZ-3256 (Swift, 2); epic AZ-3199.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` then `/new-task` ran before this plan (8 points, split by package) |
| decompose-feature | 9.5 | Decompose Feature | no | done inside new-task: three package specs written from `feature-description.md` |
| implement | 10 | Implement | yes | three workers on disjoint trees (`csharp/`, `java/`, `swift/`) |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | `scripts/loop-tests.sh` once on the final tree (load checked first) |
| test-spec-sync | 12 | Test-Spec Sync | no | no project-level test scenario changes; task tests live in the packages |
| update-docs | 13 | Update Docs | yes | review dispositions in `_docs/05_security/frame_mode_managed_loop71.md`; component descriptions name `Load` with no direction and the test-only Swift members |
| security | 14 | Security Audit | yes | the loop is security hardening: one independent read-only review of the diff |
| performance | 15 | Performance Test | no | the load-aware timing checks of the three suites cover the extra clears |
| deploy | 16 | Deploy | no | library; no ship |
| release | 16.5 | Release | no | no deploy |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | no | last retro loop 69; next due after loop 73 |
| local-deploy | — | Local deploy + open site | yes | library: no site; the smoke script runs the packages |
| smoke | — | Smoke acceptance | yes | `smoke72.sh` with per-step PASS/FAIL |

## Implementation

### Files that change
- C#: `csharp/FrameSession.cs`, `MacKey.cs`, `SessionPad.cs`, frame tests.
- Java: `java/src/main/java/packbin/FrameSession.java`, `MacKey.java`, `FrameCrypto.java`, `SessionPad.java`, frame tests, `java/test.sh` if a new test class has a `main`.
- Swift: `swift/Sources/Packbin/FrameSession.swift`, `MacKey.swift`, `ChaCha20.swift`, three test files.

### Order of work
Three workers in parallel (no shared file). Parent: docs, total review, step 11, smoke, close.

### Proof
Each package suite green; the 157 frame rows and 27 crypto rows unchanged; ring stage green; guard tests for the hooks; one broken-copy run for the Java counter test.

### Risks
L71-1 (a wipe is best effort in managed runtimes); a field rename breaks the reflection helpers loudly, not silently.
