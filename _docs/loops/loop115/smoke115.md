# Loop 115 smoke — proposed checks

LOCAL_URL: none (library: no site, no local deploy; `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate)
Branch: dev

Short loop (AZ-4241: an investigation, no code change). The agent runs `smoke115.sh` itself (owner rule 2026-10-12: all `N/N` steps pass, the gate passes without a question).

## Run this (one paste, from the repository root)

```bash
bash _docs/loops/loop115/smoke115.sh
```

## Checks

- [x] 1. `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo` ends within 300 s and 5,474 tests pass
- [x] 2. The same with `--logger "console;verbosity=normal"` ends within 300 s and 5,474 tests pass
- [x] 3. `_docs/AGENT_GOTCHAS.md` records the 10 + 10 run counts (AC-3) and the `gh run list --commit` full-SHA quirk
- [x] 4. The queue item left `backlog/` and `problem.md` claims loop 115

## Notes

No credentials. About 40 s.

## Agent walk

2026-11-12, host load 7: `smoke 115: 4/4 PASS` (17 s each form).

## For the operator

Nothing.

## Result

PASS (agent-verified)
