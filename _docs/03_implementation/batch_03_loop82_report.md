# Batch Report

**Batch**: 3
**Tasks**: AZ-3386_publish_pins_guard_and_docs (the rest of it: three AC tests found missing by the feature assessment; the CI result waits for the push)
**Date**: 2026-10-29

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3386_publish_pins_guard_and_docs | Done except AC-6 (CI of the push, read at loop close) | `scripts/ci/yaml_get.test.sh` (tree scan), `publish-precheck.test.sh` (no YAML reader named), `publish-pins.test.sh` (doc names `pyyaml`) | `yaml_get.test.sh` passed, refuses a stray `import yaml`; `publish-precheck.test.sh` passed, refuses a `yaml` mention; pins harness `failures: 0` | None |

## Code Review Verdict: not run

No per-batch code review (owner preference, as in loop 81).

## Test Suite

- `bash scripts/loop-tests.sh --only scaffold,ring,publish-gate --all` on this host without Ruby: scaffold PASS (163 s); publish-gate PASS (144 s; share 7 `readonly-full,static,crates-token,registry,vcpkg,go,manifest,npm,position,workflow,pins` 130 s, share `swift` 73 s; NOT RUN: vcpkg supports and consumer checks, swift consumer resolve); ring first FAIL (5 s) on `java: command not found` (the JDK is a user-directory tarball not on PATH; host, not code), then PASS (41 s) with the JDK on PATH and the gcc:16 wrapper, as loop 81's smoke does.
- CI-parity: PASS (the same stages).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | Three ACs had no test at the end of batch 02 (one reader across the tree, the precheck names no YAML reader, the pins doc names `pyyaml`) | AZ-3381 AC-1, AZ-3382 AC-5, AZ-3386 AC-5 | tests added and shown to fail on a deliberate break | clear |
| 2 | `loop-tests.sh --only ring` needs the JDK on PATH on this host | none | the loop's smoke script sets it, as loop 81's did; a documented host prerequisite, not a repo defect | clear |

## Commit

`[AZ-3386] Tests for the one reader, the precheck and the pins doc, loop 82 assessment`. Body: one line + `Loop: 82`.

## Next Batch: All tasks complete (AZ-3386 closes with the CI result)
