# Intake: CI fails on the first Ubuntu run of the Swift package (loop 26 close)

kind: intake
created: 2026-10-14T20:30:00
source: poll-fail
status: pending

## Problem
`test.yml` on `f30c87e` (the loop 26 close push to `dev` and `main`) failed: the `ring` job failed in both runs at the step "toolchain versions" (the first Swift ring run on a runner), and the `scaffold` job's `publish gate` step failed in one of the two runs and passed in the other. The `swift` suite itself (`swift:6.3.3` container, all steps) passed on the runner in both.

## Proposed outcome
`test.yml` green on `dev` and `main`: the ring builds the Swift drivers with the pinned toolchain whatever Swift the runner carries; the publish gate step is stable.

## Affected users and systems
CI only (no tag, no registry upload was started). `.github/workflows/ring-toolchains.sh`, `ring-swift.sh`, `test.yml` ring job; the publish gate test (`publish-gate.test.sh`, `publish-swift.test.sh`).

## Evidence
Runs 38588698291 and 38588700455; failing jobs 115937491350 (ring, step "toolchain versions", exit 1) and 115937490795 (scaffold, step "publish gate", exit 1 at log line 1966). Logs need a signed-in GitHub session. `_docs/04_deploy/reports/deploy_status_report.md` has the triage lines.

## Constraints
No tag, no force-push; the fix lands on `dev` and is pushed again by the owner's go (CI triage rule). Do not weaken the exact-version check of the other toolchains.

## Open questions
Which Swift does `ubuntu-latest` carry (the log line "toolchain swift: found ..., the suites use 6.3.3")? What does the gate log say at line 1966, and does the same commit fail again?

## Replay payload
Seed `problem.md`: "Fix the failing CI of the loop 26 close push: ring job toolchain check for Swift; stabilise the publish gate step"; ACs: ring job green with the pinned toolchain; the gate step green in 3 consecutive runs; no change to the other toolchain checks.
