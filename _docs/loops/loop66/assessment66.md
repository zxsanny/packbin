# Feature assessment — loop 66

loop: 66
feature: publish-gate-load-aware
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-24
**Implement pass**: one batch, commits `3b8fed6` and `682a5c8`
**Verdict**: COMPLETE — 7 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear (one residual risk recorded, below)

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| AC-1 | Go test passes with a 5 s stub | covered | `publish-go.test.sh` `gt_window` + `GT_GO_DELAY`; 137 s run "go release checks passed"; `smoke66.sh` step 1 (140 s) | intake |
| AC-2 | a one-try `proxy_check` is caught | covered | scratch copy: `FAIL: AC-3 the proxy was asked once only: 1`; old fixed window of 3 s under the 5 s stub fails the same way; `smoke66.sh` step 2 | intake |
| AC-3 | quiet host, at most 60 s | covered | 32 s and 30 s (loads 6 to 8) | intake |
| AC-4 | pip's error stays in the quote | covered | `ph_quote` (25 lines), used at the two sites; static check fails on the old tree (no helper, `tail -n 3` present); `smoke66.sh` step 4 | intake |
| AC-5 | phases group, at most 400 s | covered | `--groups phases` 240 s EXIT 0; share `phases` 352 s and 363 s inside the full gate | intake |
| AC-6 | pip retry only on evidence | covered | the pip step did not fail in the three runs of the phases share (alone and in both full gates), so `publish-inside.sh` is unchanged; the owner is told the cause is still unknown | intake |
| AC-7 | full gate once, read from share logs | covered | run 1: all shares PASS except share 7 (phase-split self-test: `ph_quote` not in `ph_harness`; fixed in `682a5c8`); run 2 at `682a5c8`: 8 of 8 shares PASS, 378 s, load 6 to 29; the first run reached load 37 | intake |

### Residual risk (not a gap in a written criterion)

The Go window is sized from three probe asks of the same stub, in whole seconds. A single ask that becomes more than four times slower than the probe after it (a stall of 10 s or more) can still end the window after one ask. The spec Outcome said "however slow one ask is"; it now says what AC-1 proves. A larger floor (10 s) would cost about 7 s of test time.

### Discovered during implementation

| scenario | spec ref | handling | clear |
|----------|----------|----------|-------|
| a new `ph_*` helper must be named in `ph_harness` of the self-test | none | named `ph_quote` there (`682a5c8`) | clear |

### Gaps that need a decision (gap-unclear)

none

### Gaps that are clear (gap-clear)

none

### Not walked

- The host venv `pip install` of `platformio` (`publish-phases.test.sh` line 106): its error already reaches the share log.
- Whether the CI `publish-gate-*` jobs pass on GitHub: read after the push.
