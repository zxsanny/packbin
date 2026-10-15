# Loop 29 handoff — written 2026-10-15 while loop 28 was closing

Read `_docs/loops/loop28/record28.md`, `review28.md`, `assessment28.md`, the "Loop 28" sections of `_docs/04_deploy/reports/deploy_status_report.md` and `_docs/03_implementation/test_run_loop28_report.md` first. Owner preferences from `_docs/loops/loop26/handoff27.md` stand (one total review and one step 11 run, decision batches with "accept all recommended" first, `< /dev/null` and timeouts on shell, pushes of `dev` asked each time, no tag without the owner's go).

## State when loop 28 closes

- CI `test.yml` is five jobs: `scaffold` (53 s), `suites` (17 min), `publish-gate` (22 min 50 s, gate step 1 269 s), `embedded` (6 min), `ring` (4 min 45 s); 22 min 51 s end to end on run 38731123341 (was 33 to 38 minutes).
- The gate prints `publish-gate: <check> took N s` for 14 groups. Mac figures: swift 284, readonly 263, phases 251, gate 191, pins 33 of 1 059 s.
- The `cpp` pool failure was Docker Desktop showing the old directory to a container started right after a host `rm -rf`; the stage now cleans inside the container (`AGENT_GOTCHAS.md`).

## Do first

1. Read the CI runs of the close push (`dev` and `main`): SP-2 needs two runs at most 25 minutes (run 1 was 22 min 51 s).
2. Hopper: `todo/` holds AZ-2068 only (held as optional for 9 loops); no intake leftover.
3. Candidate work (owner picks): cut the gate (readonly, phases, swift, gate groups: read what each does and where a fresh state per scenario is needed for a mutation proof, as in loop 27 CG-6); the `suites` matrix; review28 #3, #4; AZ-2068.
4. Owner only: F44 and the first tags.
