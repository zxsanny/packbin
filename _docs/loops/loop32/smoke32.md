# Loop 32 smoke — checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI runs and the step 11 log)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close (only `_docs/` files, the close commit)
- [x] 2. CI run 39024316436 (`c0e8019`): 23 of 23 jobs `success`, wall 275 s, target at most 330 s
- [x] 3. The gate jobs' annotations list the 19 groups exactly once
- [x] 4. The embedded jobs' annotations list the 9 targets exactly once (arm 4, ESP core 3, ESP packages 2)
- [x] 5. Ten suite notices: seven languages and the three Swift parts
- [x] 6. Step 11 (`scripts/loop-tests.sh`): 10 passed, 0 failed, no serial retry; the eight gate shares ran at once, wall 391 s against a sum of 2 395 s (ratio 0.16, bound 0.7), the tree unchanged (1 712 paths)
- [x] 7. Every changed script and workflow is at most 500 lines (largest 448: `publish-readonly.test.sh`)
- [x] 8. No tag contains a loop 32 commit, and `origin/main` does not contain the loop (no push of `main`)

## Result

Agent run 2026-10-17, owner rule 2026-10-12 in `deployment_procedures.md`: **8/8 checks passed** (one script in the session scratchpad, one PASS or FAIL line per check).

## For the operator

- AC-1 is the median of two runs: run 1 is 275 s; run 2 is the close push of `dev` and is recorded in `notes32.md` and the loop record after it ran.
- `ring` (273 s) and `suites (swift, tests)` (246 s) set the wall now; no job the loop cut is above 250 s.
- The two vcpkg checks are NOT RUN on this Mac (no vcpkg tool); the CI job `publish-gate-rest` runs them (green in run 1).
- `main` was not pushed, no tag.
