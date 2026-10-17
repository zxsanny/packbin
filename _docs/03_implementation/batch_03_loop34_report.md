# Batch Report

**Batch**: 3
**Tasks**: AZ-2627_ci_speed_5 (owner decision 2026-10-17 after run B: fix the cache keys)
**Date**: 2026-10-17

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2627_ci_speed_5 | Done (priming run, then two measured runs) | 3 files | `publish-jobs.test.sh`, `ring-wiring-swift.test.sh`, `ring-wiring.test.sh`, scaffold stage (237 s), gate `workflow,static`: PASS | None |

Why: run B (39043302176) hit every cache but rebuilt BoringSSL in all four builds (75, 79, 126, 108 s): the `v1` entries were built with batch 1's ccache compiler, plain clang made SwiftPM recompile every C file, and an exact-key hit never saves, so the stale entries would have stayed until a dependency change.

What changed: keys `swift-v2-<part>-<pin>-<hash of Package.swift, Package.resolved, run-suite.sh>` and `swift-v2-ring-<RING_SWIFT>-<hash of the root and driver manifests, ring-swift.sh>`; the guards require the script in the hash (mutants "cache key without run-suite.sh", w21 "ring-swift.sh in the ring cache key"); comments and docs say why.

## Code Review Verdict: not re-reviewed (key strings and their guards only)

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | AC-7's key names the build, tag and manifests; the build-setting script was missing | AZ-2627 AC-7 | added to the key; AC-7's intent ("a push that changes neither saves no cache") holds for a push that changes no build input | clear |

## Commit

`[AZ-2627] Cache keys v2: hash the script that sets the build` — body: one line + `Loop: 34`.

## Next Batch: All tasks complete
