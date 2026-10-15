# Loop 27 acceptance criteria (CI publish gate)

All measured by the pushed commit's `test.yml` run on `ubuntu-latest` unless a row says Mac.

- **CG-1** `test.yml` on the pushed `dev` commit: jobs `scaffold`, `embedded`, `ring` conclude `success`, 3 of 3.
- **CG-2** The `publish gate` step finishes in at most 25 minutes (1 500 s) on the runner and `scaffold` in at most 50 minutes in total (the job limit is 60).
- **CG-3** The `publish gate` step is green in 3 consecutive runs of `test.yml` on `dev` (3 of 3; the check is the run list, read at the next loop's start if the third run is not yet done at close).
- **CG-4** The cause of the failure is named in the status report with the failing check name and the last 10 log lines of the reproduction (0 guesses left as "likely").
- **CG-5** The Swift suite stage in the `swift:6.3.3` container takes at most 500 s on the Mac (741 s before), with the thread sanitizer still run on the concurrency and session suites (2 of 2 suites sanitized) and every other Swift test still run in the plain debug and release runs (340 tests in 56 suites, 0 fewer).
- **CG-6** The Swift scenarios of the full gate test take at most 900 s on the Mac in total (1 338 s before) and every scenario keeps its assertions (0 scenarios removed; 0 assertions removed).
- **CG-7** The exact-version checks of the other toolchains in `ring-toolchains.sh` are unchanged (0 diff lines outside the Swift lines), and `ring` stays under 10 minutes on the runner.
- **CG-8** No tag is created and no registry upload is started (0 tags, 0 uploads).

Inherited from the project: the golden hex `4001000065cd1d00a3e1110100` gate (publish-gate.test.sh) and the 75 % / 90 % coverage floors of `quality-thresholds.md` (no production code changes in this loop, so no coverage delta).
