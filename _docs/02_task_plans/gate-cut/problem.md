---
loop: 29
branch: dev
---

# Loop 29 — cut the publish gate (AZ-2223 follow-up)

Loop 29 (on `dev`; no worktree). Owner (2026-10-15): from the loop 28 handoff candidates picked "Cut the gate"; target "gate job ≤ 18 min"; the loop 28 close commit stays unpushed ("Not now"). Hopper otherwise empty; AZ-2068 stays held.

## What

The CI job `publish-gate` in `.github/workflows/test.yml` is now the longest job of `test.yml` (22 min 50 s on run 38731123341; the gate step is 1 269 s on the runner and varies by about 4 minutes between runs, so the 25-minute limit of loop 28 SP-2 is tight). Loop 28 added `publish-gate: <check> took N s` lines. Mac figures: swift 284 s, readonly 263 s, phases 251 s, gate 191 s, pins 33 s of 1 059 s; the other nine groups are the remaining ~37 s.

Work: read what each large group proves and where its time goes (image pulls, repeated `docker run` start-ups, repeated builds of the same fixture tree, scenarios that rebuild state that could be copied); remove duplicated or needless work and reuse state across scenarios where no guard needs a fresh one. Every guard stays: each mutation proof keeps its mutant, and a scenario that a mutant needs fresh state for keeps fresh state (as in loop 27 CG-6). Evidence first: a per-scenario or per-command timing inside the four large groups before any cut (meta rule "debugging over contemplation").

Not in scope: the `suites` matrix, the Mac gate-in-parallel option, review28 #3/#4, AZ-2068, any product code, any tag or registry upload, F44.

## Code sections / UI locations for this loop

Backend / CI, no UI. Named by the owner's pick and the loop 28 handoff: `.github/workflows/publish-gate.test.sh` plus the files it sources (`publish-swift.test.sh`, `publish-readonly.test.sh`, `publish-phases.test.sh`, `publish-pins.test.sh`, `publish-go.test.sh`, `publish-rerun.test.sh`), the `publish-gate` job in `.github/workflows/test.yml`, and `_docs/04_deploy/ci_cd_pipeline.md` for the recorded timings. Owner confirmed this location on 2026-10-15.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A cut that shares state between scenarios can make a mutation proof pass for the wrong reason (the guard is no longer exercised) | meta rule "no stand-in": every moved or merged scenario keeps its mutant, and a mutant count before and after is compared | open | High |
| The CI gain is proven only by pushed `dev` runs; a push of `dev` is asked from the owner each time (the loop 28 close commit is also unpushed) | owner (pushes asked) | open | Medium |
| CI run time varies by about 4 minutes between runs, so one run proves nothing; 3 runs needed | owner accepted a median of 3 | open | Medium |
| Mac and runner differ (cache, cores); a Mac-only cut may not move the runner | measure on the runner (timing lines in CI log), not only on the Mac | open | Medium |
| No tag, no registry upload, no force-push (F44 and the first tags are the owner's) | owner | resolved | — |
