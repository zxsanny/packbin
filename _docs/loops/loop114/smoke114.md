# Loop 114 smoke — proposed checks

LOCAL_URL: none (library: no site, no local deploy; `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate)
Branch: dev

Short loop (AZ-4237: one test line, no library change). The agent runs `smoke114.sh` itself at the commit before the close commit (owner rule 2026-10-12: all `N/N` steps pass, the gate passes without a question). The C++ suites are the whole test scope of the change; CI runs every package on the push.

## Run this (one paste, from the repository root)

```bash
bash _docs/loops/loop114/smoke114.sh
```

## Checks

- [x] 1. `pack_into_a_small_buffer` declares `out[17]` for its capacity-17 pack (AC of AZ-4237)
- [x] 2. The ASan + UBSan host suite (clang, `-fno-sanitize-recover=all`) prints no sanitizer report and no failing check other than a wall-clock bound (AC-3)
- [x] 3. Apple clang `make -C cpp test` passes, including the string-free and ECC-free builds (AC-1)
- [x] 4. `gcc:16` `make test` passes (AC-2)
- [x] 5. The queue item left `backlog/` and `problem.md` claims loop 114

## Notes

No credentials. About 4 minutes (the sanitizer build about 50 s).

## Agent walk

2026-11-12, at `ccbbadb`, host load 13: `smoke 114: 5/5 PASS`; step 2: exit 0, sanitizer reports 0, other failing checks 0, wall-clock bounds missed 0.

An earlier run at load 50 failed step 2 on the text speed check alone (1.017 s against 1.004 s, 0 sanitizer reports): ASan slows the timed code and not the load factor's reference loop. Step 2 now accepts a missed wall-clock bound and prints it; the fix is the queue item `_docs/02_tasks/backlog/cpp-wall-clock-bounds-under-sanitizers.md`.

## For the operator

Nothing.

## Result

PASS (agent-verified)
