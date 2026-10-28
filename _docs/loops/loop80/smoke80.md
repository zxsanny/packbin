# Loop 80 smoke — the ring names a refused row; a passed stage is stamped with a dirty position file

LOCAL_URL: none (scripts and the CI `scaffold` and `ring` jobs; no site). Branch: dev. Script: `bash _docs/loops/loop80/smoke80.sh`. Run by the agent (owner rule 2026-10-12 in `_docs/04_deploy/deployment_procedures.md`: the agent runs the script and the gate passes when every step passes).

## Checks

- [x] 1. No application source is dirty
- [x] 2. `ring-frame.test.sh` passes (34 PASS), among them `seal-refused-by-reference` and `mac-refused-by-reference`: exit 1, the file line, the case and `BadValue`, no traceback in any case — AZ-3369 AC-1, AC-2
- [x] 3. The real ring with all 8 drivers: `ring-frame: 64 pairs, mismatched: 0` and 8 lines `refusals <lang>: 43 rows, 0 mismatched` — AC-3
- [x] 4. Not vacuous: the loop-start `ring_frame.py`, in a scratch copy, fails exactly the two new cases with a traceback in the output — AC-4
- [x] 5. `loop-tests.test.sh` passes; the loop-start `loop-tests.sh` fails its new case (the position file blocked the stamp) — AC-5
- [x] 6. Job layout, ring wiring and ring-lib tests pass
- [x] 7. `scripts/loop-tests.sh` against stamps at 692edcc (loop 79's total run): the plan runs exactly `scaffold`, `ring`, `publish-gate`, skips the other 11 as unchanged, and the three pass
- [x] 8. shellcheck no worse than the loop start, Python compiles, no touched source file over 500 lines

## Agent walk

8 PASS, 0 FAIL, 0 NOT RUN (`smoke80: 0 failed`, exit 0, 1,086 s) on the first trial, at 56eb43f (the commit before the close commit). Host load 20 to 105: the publish gate runs its 8 shares at once, and its wall was 633 s (loop 79's step 11 saw 331 s at load 4 to 35). Step 7 stages: `scaffold` 267 s, `ring` 65 s, `publish-gate` 633 s (tree manifest the same before and after, 2,847 paths); the two vcpkg checks of share `readonly-full` print NOT RUN on this Mac, and CI runs them (L78-2).

## For the operator

Nothing: every check ran in the script.

## Result

56eb43f: 8/8 steps passed; agent run, owner rule 2026-10-12 in `deployment_procedures.md`. Smoke: PASS.
