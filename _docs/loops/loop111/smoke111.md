# Loop 111 smoke - C# element row Lows (AZ-4205), checks run by the agent

LOCAL_URL: none (a library; no UI, no local deploy)
Branch: dev

One bash script, `_docs/loops/loop111/smoke111.sh` (run it from the repository root: `bash _docs/loops/loop111/smoke111.sh`). Each step prints `PASS` or `FAIL` with the last lines of its log. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it and passes the gate when every step passes.

Checks:

1. C# element-row and round tests on `net10.0`: all pass, 22 of them the new AZ-4205 tests.
2. The same on `netstandard2.0`.
3. TypeScript writes the hex the C# tests pin for `when` (`010200010700`) and `times` (`01020002050600`) inside an element row.
4. README: the member types of the row form and the two refusal texts.
5. The AZ-4205 commits touch only `csharp/`, `README.md` and `_docs/`.
6. The security lite record says CLEAN.
7. AZ-4206 waits unclaimed in `todo/`; AZ-4205 is in `done/`.

## Result

Commit `bb99503` plus the loop-close docs: 7/7 steps passed (agent run, owner rule 2026-10-12). The first run failed steps 1 and 2 on the script's own count (25 expected, 22 real: a miscount of the theory cases; all 103 tests passed); fixed the count and re-ran: 7/7.
