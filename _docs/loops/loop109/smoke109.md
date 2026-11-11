# Loop 109 smoke - embedded-arm DNS cause (AZ-4198), checks run by the agent

LOCAL_URL: none (CI files and documents; no UI, no local deploy)
Branch: dev

One bash script, `_docs/loops/loop109/smoke109.sh` (run it from the repository root: `bash _docs/loops/loop109/smoke109.sh`). Each step prints `PASS` or `FAIL` with the first lines of its log. Owner rule 2026-10-12 (`deployment_procedures.md` § Loop smoke gate): the agent runs it and passes the gate when every step passes.

Checks:

1. The findings file says "Not reproduced" and cites both diagnostic runs.
2. The failing job log (130648051396) holds the quoted line `Could not resolve 'archive.ubuntu.com'`.
3. Both diagnostic logs: at least 60 ok lookups per path, at least 10 ok builds, 0 failed, the two resolver lines as quoted.
4. Diagnostic run 43100819627 concluded success.
5. The comments in `cpp/embedded/run.sh` and the `Dockerfile` say the cause is not known and cite the findings.
6. The AZ-4198 commits touch only `.github/`, `cpp/embedded/`, `_docs/`.
7. The security lite record answers ESCALATE with 0 Critical, High, Medium.
8. `test.yml` of the last source push (`c812ff3`): 20 of 20 jobs success.

## Result

Commit `c812ff3`: 8/8 steps passed (agent run, owner rule 2026-10-12). Test runs of this loop: scoped self-tests (`run-parts`, `lib`, `publish-pins`, `publish-workflow`, `publish-readonly`) exit 0; `dev` runs 43100805944 (`412ccc4`), 43102550678 (`5854bd8`) and 43103314475 (`c812ff3`) all 20 of 20.
