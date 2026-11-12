# Loop 116 smoke — proposed checks

LOCAL_URL: none (library: no site, no local deploy; `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate)
Branch: dev

AZ-4242: element-row probes in seven packages, no package source. The agent runs `smoke116.sh` itself (owner rule 2026-10-12: all `N/N` steps pass, the gate passes without a question).

## Run this (one paste, from the repository root)

```bash
bash _docs/loops/loop116/smoke116.sh
```

## Checks

- [x] 1. the element-row probe runs: 7 packages, 168 lines (AC-1)
- [x] 2. a second run is byte-identical and writes nothing into the checkout (AC-4)
- [x] 3. every packet written equals TypeScript's for its shape (AC-3)
- [x] 4. the probe shows the Java and Python defects and Go / Swift refusing at build (AC-2, AC-3)
- [x] 5. no package source changed in the loop; shellcheck clean (AC-5)
- [x] 6. queue items and decisions D10, D11 are written (AC-3)

## Agent walk

Run at `951a2fd`, host load 28 to 33: `smoke 116: 6/6 PASS` (168 lines in 43 s; 61 packets compared, 0 differ; 5 threw lines: java 4, python 1).

## For the operator

none
