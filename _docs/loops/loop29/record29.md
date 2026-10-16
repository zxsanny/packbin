# Autodev loop record — loop 29

loop: 29
branch: dev
plan_artifact: _docs/loops/loop29/plan29.md
tasks_shipped: [AZ-2582]
leftovers:
  - GC-1 met after the close: 689, 825 and 1 011 s (median 825 s, limit 1 080 s); the same code varies by about 320 s between runs
  - `suites` (888 s) is now the longest job: a matrix of one job per language is the next speed step
  - the phases group still builds the nine targets six times one after another (158 s on the runner); `publish-phases.test.sh` is 501 lines (over the 500-line cap, not touched this loop): split it by responsibility
  - an aborted gate run leaves its `mktemp` directories, and 745 old ones sit in the Mac temp directory (the gate's older calls leave them); cleanup on abort was out of scope (GC-9 amended)
  - review28 #3 (global EXIT trap of `publish-timing.test.sh` now also emits the notice on abort) and #4 (delete-then-start pattern not audited in other scripts) stay open
  - open owner rows: F44 (tag ruleset), the first tags (`vX.Y.Z` with the Swift check, `go/vX.Y.Z`); S3 stays B
  - from loop 26 still open: the unverified parts (Swift 6.0, Xcode 16.0, tvOS, watchOS, Android, Windows, WASI); review26 #6 (`ChaCha20.fill` allocates two arrays per block), #7 (public `PackSession.start(_ nonce:)`, owner API decision O3)
  - AZ-2068 (C++ AVR stretch) stays in `todo/`; the epic AZ-2223 stays open until the first tag resolves
smoke: PASS (agent run 7/7, owner rule 2026-10-12)
smoke_artifact: _docs/loops/loop29/smoke29.md
assessment_artifact: _docs/loops/loop29/assessment29.md
loop_end_merge: main
