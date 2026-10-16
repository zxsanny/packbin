# Loop 30 handoff — written 2026-10-16 while loop 29 was closing

Read `_docs/loops/loop29/record29.md`, `assessment29.md`, `notes29.md`, the "Loop 29" section of `_docs/04_deploy/reports/deploy_status_report.md` and `_docs/03_implementation/test_run_loop29_report.md` first. Owner preferences from `_docs/loops/loop26/handoff27.md` stand (one total review and one step 11 run, decision batches with "accept all recommended" first, `< /dev/null` and timeouts on shell, pushes of `dev` asked each time, no tag without the owner's go).

## State when loop 29 closes

- `publish-gate` job: 689, 825 and 1 011 s on the three runs of the final code (was 1 370 s median); the Mac gate test is 754 s in `loop-tests.sh`. `suites` (874 to 1 071 s) is now about as long; the workflow takes 15 to 18 minutes.
- The gate prints its 14 lines also as ONE `::notice` annotation, readable without a token: `curl -s "https://api.github.com/repos/zxsanny/packbin/check-runs/<job id>/annotations?per_page=100"` (job ids from `/actions/runs/<id>/jobs`). GitHub keeps only 10 notices per step, so never emit one per line.
- `gh` is not installed on this Mac; the public API is used (60 calls an hour).

## Do first

1. GC-1 is met: the three runs of the final code took 689, 825 and 1 011 s (median 825 s, limit 1 080 s). The commit that noted them is unpushed until the owner's go; check `git status -sb`.
2. Hopper: `todo/` holds AZ-2068 only (held as optional for 10 loops); no intake leftover.
3. Candidate work (owner picks): the `suites` matrix (one job per language, the longest job now); the phases group (158 s on the runner: six full builds one after another); split `publish-phases.test.sh` (501 lines); review28 #3, #4; AZ-2068.
4. Owner only: F44 (the tag ruleset). `v0.3.0` and `go/v0.3.0` were released on 2026-10-16 at the owner's request (tag on 2cade74; publish run 38894017715 green: 58 minutes in all, 13 for the repeated tests and 45 for the publish job; GitHub Release https://github.com/zxsanny/packbin/releases/tag/v0.3.0). The tag run repeats `test.yml` (13 minutes), Maven Central took 20 minutes to publish and the Go proxy 19 minutes to answer (details: `_docs/04_deploy/reports/ci_metrics_2026-10-16.md`); the session "Cut the tag publish run" (commit 84f0bbc) addresses the first.
