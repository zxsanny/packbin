# Loop 29 acceptance criteria (cut the publish gate)

Measured on pushed `dev` commits' `test.yml` runs on `ubuntu-latest` unless a row says Mac.

## Speed

- **GC-1** The `publish-gate` job of `test.yml` takes at most 18 minutes as the median of 3 CI runs on `dev`, and no run above 20 minutes (baseline: 22 min 50 s, run 38731123341; 19 min 5 s and 23 min 12 s on the close pushes).
- **GC-2** The `publish gate` step prints the 14 lines `publish-gate: <check> took N s` and the total in CI, and the sum of the timed groups on the Mac is at most 800 s (baseline 1 059 s).
- **GC-3** `test.yml` end to end is at most the loop 28 figure: at most 22 minutes 51 s in the median of the same 3 runs (the gate must not move the cost to another job).

## Nothing guarded is lost

- **GC-4** The count of assertions and of mutants per group is equal before and after: the failure-count line and the mutant-count lines of each of the 14 groups match the pre-change log (0 groups with fewer assertions; a group with more is allowed).
- **GC-5** For every cut, one mutation proof: a copy of the repository with the guarded behaviour broken still makes the gate fail with the group's own message (one mutant per changed scenario, 100 % rejected); the log of each mutant run is kept in the status report.
- **GC-6** `publish-gate.test.sh` and every file it sources stay at most 500 lines (`quality-thresholds.md`), and `shellcheck` reports 0 new warnings.

## Evidence and docs

- **GC-7** The per-scenario or per-command timing for the four large groups (swift, readonly, phases, gate) is recorded in the status report before the first cut, as seconds per item with the command, and every cut names the item it removes and the seconds it saves (cut list total within 20 % of the measured gain on the Mac).
- **GC-8** `_docs/04_deploy/ci_cd_pipeline.md` carries the new gate timings (median of the 3 runs and the per-group figures); 0 stale figures from loop 28 left as current.

## Inherited

- The golden hex `4001000065cd1d00a3e1110100` gate and the 75 % / 90 % coverage floors (`quality-thresholds.md`); no production code changes are planned, so no coverage delta.
- No tag, no registry upload (0 tags, 0 uploads); a push of `dev` only with the owner's go.
