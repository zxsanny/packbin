# Autodev loop record — loop 30

loop: 30
branch: dev
plan_artifact: _docs/loops/loop30/plan30.md
tasks_shipped: [AZ-2600]
leftovers:
  - T3 and T1 are unproven until the next `v*` / `go/v*` tag (owner's go): the Go proxy wait (19 minutes on go/v0.3.0) should become about 1 minute; the tag run should skip the 13 minute repeated test
  - T2 option B (Swift consumer check early) not built: ADR-005 and `publish-swift-gate.test.sh` (line "the Go tag is there when Swift resolves") fix the order Go tag, then Swift; gain about 70 s; owner decides whether to amend ADR-005
  - second CI run of the same layout (run 38997835591, the close push of `dev`): 382 s, jobs all green; the long poles move between runs (phases 379, swift tests 342, embedded 337, readonly 333 s)
  - new long poles of test.yml (418 s): `publish-gate-readonly` 415 s (350 s group), `suites (swift, gates)` 379 s (tests part 284 s: move the 70 s fuzz or one build to balance), `publish-gate-phases` 324 s, `embedded` 317 s; candidates C3 (caches), C4 (embedded split), T4
  - a dev + main push runs 30 jobs against 20 concurrent: measure the queueing on the close pushes
  - Mac timing-bound failures under load (rust `nfr_round_trips_under_one_second`, go `TestAC3RaisedSlotLimit...` at load 11 to 21): re-run alone at low load; not a loop defect
  - the Mac gate test took 1 141 s at load 10 to 21 (754 s in loop 29); a parallel Mac gate (three `--groups` jobs) would be the Mac twin of C2
  - open owner rows: F44 (tag ruleset), first tags; from earlier loops: review28 #3 and #4, `publish-phases.test.sh` 501 lines, AZ-2068
smoke: PASS (agent run 7/7, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop30/smoke30.md
loop_end_merge: main
