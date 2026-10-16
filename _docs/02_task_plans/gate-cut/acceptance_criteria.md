# Loop 29 acceptance criteria (cut the publish gate)

Measured on pushed `dev` commits' `test.yml` runs on `ubuntu-latest` unless a row says Mac.

## Speed

- **GC-1** The `publish-gate` job of `test.yml` takes at most 18 minutes (1 080 s) as the median of 3 CI runs of commits that carry the final gate code, and no run above 20 minutes. Pushes of `dev` and of `main` count, one push gives one run each (baseline: 1 370 s, 1 144 s and 1 392 s, a median of 1 370 s = 22 min 50 s; runs 38731123341, 38736351180, 38736693696). The runs are read from the public jobs API (`/actions/runs/<id>/jobs`, started and completed times); the `suites` job (876 to 1 044 s) is the next longest, so the workflow wall time cannot fall below it.
- **GC-2** The `publish gate` step prints the 14 lines `publish-gate: <check> took N s` and the total in CI (also as `::notice` annotations, readable through the public check-runs API), and the sum of the timed groups on the Mac is at most 800 s (baseline 1 059 s).
- **GC-3** `test.yml` end to end is at most the loop 28 figure: at most 22 minutes 51 s in the median of the same 3 runs (the gate must not move the cost to another job).

## Nothing guarded is lost

- **GC-4** No unique assertion and no mutant is lost: the mutant counts of every group are equal (swift 30 of 30, the rest as in the loop 28 log), and each assertion that a cut removes is either moved to another scenario or identical in purpose to one that stays; the moved and removed assertions are listed in `_docs/loops/loop29/notes29.md` (0 unique assertions removed without a listed twin). Amended 2026-10-16: assertion counts per group are not printed by the gate, and a duplicate run removed from one group cannot keep its count.
- **GC-5** For every cut, one mutation proof: a copy of the repository with the guarded behaviour broken still makes the gate fail with the group's own message (one mutant per changed scenario, 100 % rejected); the log of each mutant run is kept in the status report.
- **GC-6** `publish-gate.test.sh` and every file it sources stay at most 500 lines (`quality-thresholds.md`), and `shellcheck` reports 0 new warnings.

## Hygiene

- **GC-9** Any state a cut shares between scenarios (a prebuilt tree, a bare repository, a pulled image) lives under the run's own `mktemp` directory: 0 fixed paths outside it, 2 gate runs started at the same time on one host both pass, and after a normal run the directories this loop added (the readonly logs and tree copies, the real-swift status directory, the mutant copies) are removed (0 left). Amended 2026-10-16: a run aborted in the middle leaves its `mktemp` directories, as the gate did before this loop (`gate_checks` never removed its output directory); cleanup on abort is not part of this task.
- **GC-10** The timing line format `publish-gate: <check> took N s` and the 14 group names are unchanged, and `publish-timing.selftest.sh` passes.

## Evidence and docs

- **GC-7** The per-scenario or per-command timing for the four large groups (swift, readonly, phases, gate) is recorded in the status report before the first cut, as seconds per item with the command, and every cut names the item it removes and the seconds it saves (cut list total within 20 % of the measured gain on the Mac).
- **GC-8** `_docs/04_deploy/ci_cd_pipeline.md` carries the new gate timings (median of the 3 runs and the per-group figures); 0 stale figures from loop 28 left as current.

## Inherited

- The golden hex `4001000065cd1d00a3e1110100` gate and the 75 % / 90 % coverage floors (`quality-thresholds.md`); no production code changes are planned, so no coverage delta.
- No tag, no registry upload (0 tags, 0 uploads); a push of `dev` only with the owner's go.
