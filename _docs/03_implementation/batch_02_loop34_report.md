# Batch Report

**Batch**: 2
**Tasks**: AZ-2627_ci_speed_5 (owner decision 2026-10-17: remove ccache)
**Date**: 2026-10-17

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2627_ci_speed_5 | Done (runs B and C measure AC-1) | 8 files (`swift-ccache.sh` deleted) | scaffold and ring stages PASS; `publish-jobs.test.sh`, gate groups `workflow,static` PASS; 2 new mutants rejected | None |

Why: measured run A (39040035812, `c870aa7`) restored every Swift cache and ccache was asked 0 times in all four builds: the restore keeps file times to the nanosecond, so SwiftPM compiled no BoringSSL file. The intake spike had concluded the opposite because its plain `tar` round trip (GNU format, whole seconds) changed every time's fraction; `tar --posix` rebuilt 0 of 3 C files on a test package. ccache only cost an install (about 1 s on a hit, 6 to 9 s on a miss) and the root-then-caller container of the ring.

What changed: `swift-ccache.sh` and the S12 ccache rows deleted; `run-suite.sh` writes only `run-suite: swift cache <state>` when `PACKBIN_SWIFT_CACHE` is set; `ring-swift.sh` builds as before (`--user`, no root step) and says `ring-swift: cache <state>`; `ring-prepare.sh wait` carries that line (escaped); `test.yml` mounts only the build directory and keeps the `chown` after a miss; the cache keys and paths are unchanged, so the entries saved by the priming run stay valid (their `ccache/` directories are ignored).

## Code Review Verdict: not re-reviewed (a removal back to the batch-1 review's plain path; every changed rule has a guard and a rejected mutant)

## Test Suite

- `scripts/loop-tests.sh --only scaffold,ring`: PASS (239 s, 60 s); `publish-jobs.test.sh`, `publish-gate.test.sh --groups workflow,static`: PASS
- Mutants in scratch copies: "no cache line" and "cache line also on the Mac" rejected; `ring-wiring-swift.test.sh` b3 (no cache line in `ring-swift.sh`) and `ring-prepare.test.sh` "wait drops the cache line" rejected in-suite

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | AC-3's ccache clause and AC-6 lose their object | AZ-2627 AC-3, AC-6 | withdrawn by the owner's decision, marked in `problem.md` and the spec | clear |

## Commit

`[AZ-2627] Remove ccache: the restore keeps nanosecond times` — body: one line + `Loop: 34`.

## Next Batch: All tasks complete
