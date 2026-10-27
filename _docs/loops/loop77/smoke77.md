# Loop 77 smoke — cross-language frame ring

LOCAL_URL: none (scripts and the CI `ring` job; no site). Branch: dev at 11a82d2. Script: `bash _docs/loops/loop77/smoke77.sh`. Run by the agent on 2026-10-27 at host load about 10, under the owner rule of 2026-10-12: one paste script, with the agent auto-passing the gate when every step passes.

## Checks

- [x] 1. No application source is dirty
- [x] 2. The cases file has 23 seal, 19 mac, 11 open and 5 verify rows; `ring-frame.test.sh` passes 17 cases, among them the reader that accepts a tampered body and the verify that always says valid
- [x] 3. The real ring with all 8 drivers: `ring-frame: 64 pairs, mismatched: 0`, 64 clean pair lines, and 8 lines `refusals <lang>: 16 rows, 0 mismatched`
- [x] 4. A real driver with a defect fails the ring: TypeScript without the ShortPacket fix (committed tree in a scratch copy) exits 1 and prints `typescript: E3.short open gave error, wanted ShortPacket`
- [x] 5. The suite runner test (14 cargo runs incl. `--all-features`), the job wiring test and the ring wiring and ring runner tests pass
- [x] 6. The Swift `PackbinError.Kind` comment names the 7 frame-mode kinds in both spellings
- [x] 7. No touched source file is over 500 lines

## Agent walk

7 PASS, 0 FAIL, 0 NOT RUN (`smoke77: 0 failed`, exit 0) at 11a82d2. The first trial exited 127 on step 4 (`env VAR=1 limit ...`: `env` cannot call a shell function, the documented trap) and the second failed step 4 because the scratch copy had no `typescript/node_modules`; both were script bugs, fixed, and the third trial passed. The CI `ring` job (Linux) runs these rows after the loop-close push; its result is in the loop record.

## For the operator

Nothing: every check ran in the script.
