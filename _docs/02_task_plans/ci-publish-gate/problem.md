---
loop: 27
branch: dev
---

# Loop 27 — CI publish gate (AZ-2223 follow-up)

Loop 27 (on `dev`; no worktree). Intake: leftover `_docs/_process_leftovers/2026-10-14_ci-fail-loop26-close.md` (`kind: intake`), `_docs/loops/loop26/handoff27.md`, and the triage lines in `_docs/04_deploy/reports/deploy_status_report.md`. Owner (2026-10-15, "accept all recommended"): S1 A (speed up the Swift stage and the publish gate, first), S2 A (keep `@_optimize(none)`), S3 B (a Swift 6.0 consumer stays unproven, documented), F44 stays with the owner (no tags this loop).

## What

`test.yml` is red on `dev` since the loop 26 close push. Two failures: `ring` (fixed in `aefaf37`, green in 4 min 44 s on the runner) and the `scaffold` job step `publish gate` (`bash .github/workflows/publish-gate.test.sh`): run 38588698291 (`f30c87e`, one of two runs) failed after 19 min, run 38682003152 (`aefaf37`) failed after 30 min 20 s; the last green gate was `b81102f` (loop 25). The Swift stage and Swift gate scenarios (loop 26) are the only change since. This loop finds the failing check, fixes it, and cuts the Swift stage (741 s on the owner's Mac) and the gate (1 338 s) as recorded in S1: the thread sanitizer only on the concurrency and session suites, a named build-cache volume for the Swift container, one shared consumer build cache across the gate's Swift scenarios. Then it pushes `dev` and reads the new run.

## Code sections / UI locations for this loop

Named by the intake leftover (affected systems) and by the owner's S1 decision; no UI. `.github/workflows/publish-gate.test.sh` and the scripts it runs (`publish-swift.test.sh`, `publish-swift-gate.test.sh`, `publish-swift.sh`, `publish-gate.sh`, `publish-lib.sh`), the `scaffold` job and `ring` job in `.github/workflows/test.yml`, `run-suite.sh` / `run-suite-swift.test.sh` and the `swift` service in `docker-compose.test.yml` (the stage speed-up). The Swift sources `swift/**` are not touched except a sanitizer-skip marker if the speed-up needs one.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The failing line of the gate log is unread (GitHub log needs a signed-in session; 403 unauthenticated); the cause is found by reproducing the gate, not by guessing | meta-rule "debugging over contemplation": reproduce, instrument | open | High |
| A runner job time limit is 60 min; the gate took 30 min on the runner against 22 min on the Mac | S1 speed-ups, AC-2 | open | Medium |
| The thread sanitizer on part of the suites is a coverage cut; races in the other suites go unseen | S1 A keeps the sanitizer on the concurrency and session suites; the other suites have no shared mutable state (loop 26 review) | accepted-risk | Low |
| No tag, no registry upload, no force-push | owner (F44, tags need the explicit go) | resolved | — |
