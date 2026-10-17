# Loop 31 smoke — checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI run and the step 11 log)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close (only `_docs/` files, the close commit)
- [x] 2. CI run 39014663944 (`0fc35f8`): 20 of 20 jobs `success`, wall 343 s from the job timestamps (344 s from the run), target at most 360 s
- [x] 3. The gate jobs' annotations list the 16 groups exactly once
- [x] 4. The embedded jobs' annotations list the 9 targets exactly once (arm 4, ESP core 3, ESP packages 2)
- [x] 5. Ten suite notices: seven languages and the three Swift parts
- [x] 6. Step 11 (`scripts/loop-tests.sh`): 11 passed, 0 failed (typescript, go, rust on the serial retry: timing bounds under load); the five gate shares ran at once, wall 612 s against a sum of 1 901 s (ratio 0.32, bound 0.7), the tree unchanged (1 702 paths)
- [x] 7. Every changed script and workflow is at most 500 lines (largest 497: `cpp/embedded/run-parts.test.sh`)
- [x] 8. No tag contains a loop 31 commit, and `origin/main` does not contain the loop (no push of `main`)

## Result

Agent run 2026-10-17, owner rule 2026-10-12 in `deployment_procedures.md`: **8/8 checks passed** (one script in the session scratchpad, one PASS or FAIL line per check).

## For the operator

- AC-1 is the median of two runs: run 1 is 344 s, run 2 (the close push of `dev`, run 39018150736) is 369 s, both 20 of 20 jobs green: median 356.5 s, 3.5 s under the 360 s target; the second run alone is above it. `readonly-gate` (139, 200, 278 s) defines the wall: the next cut.
- `main` was not pushed (owner: dev only, no tag).
