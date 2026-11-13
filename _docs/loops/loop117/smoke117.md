# Loop 117 smoke — proposed checks

LOCAL_URL: none (library: no site, no local deploy; `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate)
Branch: dev

AZ-4243: a dirty `_docs/` does not block a `scripts/loop-tests.sh` stage stamp. The agent runs `smoke117.sh` itself (owner rule 2026-10-12).

## Run this (one paste, from the repository root, after step 11 of loop 117)

```bash
bash _docs/loops/loop117/smoke117.sh
```

## Checks

- [x] 1. `scripts/loop-tests.test.sh` passes (AC-1 to AC-4)
- [x] 2. shellcheck clean on both scripts
- [x] 3. step 11 wrote the `scaffold` stamp with `_docs/` dirty (the real use)
- [x] 4. `--plan` skips `scaffold` as unchanged while `_docs/` holds this loop's uncommitted files (AC-3)
- [x] 5. `deployment_procedures.md` says a stamp ignores `_docs/` (AC-5)

## Agent walk

Run at `65bee8b` with `smoke117.sh` untracked, host load 41: `smoke 117: 5/5 PASS` (`PLAN scaffold SKIP (unchanged since 65bee8b)`).

## For the operator

none
