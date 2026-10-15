# Autodev loop record — loop 28

loop: 28
branch: dev
plan_artifact: _docs/loops/loop28/plan28.md
tasks_shipped: [AZ-2563, AZ-2564, AZ-2565, AZ-2566, AZ-2567]
leftovers:
  - SP-2 met after the close: 3 runs at most 25 minutes (22 min 51 s, and the close push on `dev` 19 min 5 s and on `main` 23 min 12 s, runs 38736351180 and 38736693696); the gate job varies by about 4 minutes between runs, so 25 is tight
  - the gate's four large groups (Mac figures: swift 284 s, readonly 263 s, phases 251 s, gate 191 s of 1 059 s) are where the gate is cut next; on the runner the gate step is 1 269 s
  - the `suites` job (17 min) is now the second-longest; a matrix of one job per language is Option B of Card 1 if the gate is cut below it
  - review28 #4: the pattern "delete a bind-mounted path on the host, then start a container" is not audited in other scripts; #3 the global EXIT trap of `publish-timing.test.sh`
  - open owner rows: F44 (tag ruleset, the owner applies it); the first tags (the first `vX.Y.Z` with the Swift check, the first `go/vX.Y.Z`); S3 stays B (documented in README and ADR-005, not proven)
  - from loop 26 still open: the unverified parts (Swift 6.0, Xcode 16.0, tvOS, watchOS, Android, Windows, WASI); review26 #6 (`ChaCha20.fill` allocates two arrays per block), #7 (public `PackSession.start(_ nonce:)`, owner API decision O3)
  - the Mac gate in parallel with the pool (step 11 about 27 to 18 minutes) was not chosen; AZ-2068 (C++ AVR stretch) stays in `todo/`; the epic AZ-2223 stays open until the first tag resolves
smoke: PASS (agent walk 6 PASS / 0 NOT RUN; owner PASS 2026-10-15)
smoke_artifact: _docs/loops/loop28/smoke28.md
assessment_artifact: _docs/loops/loop28/assessment28.md
loop_end_merge: main
