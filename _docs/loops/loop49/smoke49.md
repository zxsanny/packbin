# Loop 49 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty
- [x] 2. AZ-2748 scope: since the intake commit only `cpp/tests/core/text_repeat_host_tests.cpp` changed outside `_docs/`
- [x] 3. AZ-2748 AC-1: the cpp stage (host `make test`) passes
- [x] 4. AZ-2748 AC-2: with `forget_raw` dropped after the compact field, the two new checks fail and nothing else does
- [x] 5. AZ-2748 AC-3: the gcc:16 container run of `make test` passes

## Result

Agent run 2026-10-20 at `d288d75` (owner rule 2026-10-12 in `deployment_procedures.md`): **5/5 steps passed** (the first run had 4/5: the scope step used a git pathspec `':!_docs'` that git rejects; fixed to `':(exclude)_docs'` and the whole script re-run). Script: `smoke49.sh` in this folder. Only the cpp stage of step 11 was run (37 s): no file outside the C++ test changed, so the other stages cover nothing this loop touched and were not re-run.

## For the operator

- Jira: AZ-2748 is In Testing; epic AZ-2645 stays open.
- A new spec `_docs/02_tasks/todo/AZ-2749_rust_nostd_core.md` (Rust `no_std` core, 5 points, epic pending) appeared in the working tree during this loop. It was not created here; it is unclaimed hopper work for loop 50 and was committed with the loop close so it is not lost.
- The first `v*` tag, F44 and the `go/v*` tag are yours; CS-D5 waits for the 100 to 200 real messages.
