# Loop 66 smoke — checks

LOCAL_URL: none (CI test scripts; nothing to open)
Branch: dev
Script: `smoke66.sh` in this folder (`bash _docs/loops/loop66/smoke66.sh`, about 3.5 minutes).

## Checks

- [x] 1. AC-1: `publish-go.test.sh` passes with the `go` stub sleeping 5 s per call
- [x] 2. AC-2: a copy of `publish-go.sh` whose `proxy_check` stops after one try fails the test naming "asked once only"
- [x] 3. AC-3: `publish-go.test.sh` runs in at most 60 s on a quiet host (NOT RUN above load 8)
- [x] 4. AC-4: `ph_quote` keeps a pip error 10 lines before the failure line; no `tail -n 3` left in `publish-phases-failures.test.sh`
- [x] 5. `publish-timing.selftest.sh` passes (the phase-split guard knows `ph_quote`)

## Result

Agent run 2026-10-24 at `682a5c8` plus the uncommitted loop 66 documents (owner rule 2026-10-12): **5/5 steps passed**, 206 s, host load 8.

## For the operator

- CI of the push: the `publish-gate-*` jobs run one share each; read them after the push.
- The first docs-only push after this loop's close shows whether `paths-ignore` works (no `test` run for that commit).
