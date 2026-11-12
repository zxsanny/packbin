# Loop 112 smoke - a repeat that is not the last thing read (AZ-4206), checks run by the agent

LOCAL_URL: none (a library; no UI, no local deploy)
Branch: dev

One bash script, `_docs/loops/loop112/smoke112.sh` (run it from the repository root: `bash _docs/loops/loop112/smoke112.sh`). Each step prints `PASS` or `FAIL` with the last lines of its log. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it and passes the gate when every step passes.

Checks:

1. The nine probes run from one command (`scripts/probes/repeat-followed-by-field/run.sh`), exit 0, and leave `git status --porcelain --ignored` unchanged.
2. Every package, and the Rust heap-free API, reads its control scheme back (`01090506`, `same`): 10 lines.
3. The measured class: shapes `a`, `d`, `e-when`, `e-flags` are built and refused on unpack in all 10 forms (40 lines); `b` and `c` in the 7 packages whose element can be a row (14 lines); `f` packs `010506` and reads back as other values in all 10 forms.
4. The appendix of `_docs/06_metrics/repeat-followed-by-field_2026-11-12.md` equals a fresh run, line for line.
5. The rule count: 4 TypeScript test schemes refused, none of the 11 ring driver schemes.
6. The eleven scripts parse and pass `shellcheck`.
7. The follow-up: `todo/AZ-4210` to `AZ-4219` unclaimed, each with its ticket and epic AZ-4209 and a row in the dependencies table; the contract names its producer and consumers; no `unknown` scenario; AZ-4206 is in `done/`.
8. The loop changed only `scripts/probes/` and `_docs/` (no package source, no workflow).

## Result

Commit `5bac143` plus the loop-close docs: 8/8 steps passed (agent run, owner rule 2026-10-12 in `deployment_procedures.md`), 31 s. The first trial failed step 4 on the script's own reading of the appendix (it took the table's separator row for a data row: 84 rows against 85 lines); the script was fixed, the check was not changed, and the second run passed 8/8.
