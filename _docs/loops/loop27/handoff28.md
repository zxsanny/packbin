# Loop 28 handoff — written 2026-10-15 while loop 27 was closing

Read `_docs/loops/loop27/record27.md`, `review27.md`, `assessment27.md`, the "Loop 27" sections of `_docs/04_deploy/reports/deploy_status_report.md` and `_docs/03_implementation/test_run_loop27_report.md` first. Owner preferences from `_docs/loops/loop26/handoff27.md` stand (one total review and one step 11 run, decision batches with "accept all recommended" first, `< /dev/null` and timeouts on shell, pushes of `dev` asked each time, no tag without the owner's go).

## State when loop 27 closes

- CI is green on `dev` (2 of 3 gate runs; the close push is the third). `test.yml` takes about 33 minutes (was 44). The Swift stage is 349 s locally (was 651 s).
- Cause of the red CI after loop 26: the Swift position test stand-in printed nothing for `--version`; on Linux `ring-swift.sh` then built in the `swift:6.3.3` image. Linux-only paths cannot be seen on the Mac: use a `swift:6.4.1` container (needs `apt-get install python3 curl` inside it; the owner approved both for loop 27 only).
- `run-suite.sh` now prints `run-suite: <lang> step took N s: <step>` for every step: use it before guessing where a stage spends its time.

## Do first

1. Read the Actions run of the loop 27 close push (`test.yml` on `dev` and on `main`): the gate step green is CG-3 run 3; a red run is triaged before anything else (`ci-fail-triage.md`).
2. Hopper: `todo/` holds AZ-2068 only. No intake leftover. Open owner rows are in `record27.md`.
3. Owner decisions still open: F44 and the first tags (owner only); whether S3 B should be written into ADR-005 / the README as a stated limit (a small docs item).
