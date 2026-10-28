# Loop 78 smoke — frame ring refusal rows and strict drivers

LOCAL_URL: none (scripts and the CI `ring` job; no site). Branch: dev. Script: `bash _docs/loops/loop78/smoke78.sh`. Run by the agent on 2026-10-28 at host load about 7 (owner practice since loop 20: the agent runs the script and the gate passes when every step passes).

## Checks

- [x] 1. No application source is dirty
- [x] 2. The cases file has 11 `refuse-seal`, 6 `refuse-open` and 5 `refuse-mac` rows (38 refusal rows with the tampered ones) and 2 `fit` rows; `ring-frame.test.sh` passes 24 cases, among them `dir0-aborts`, `unloaded-direction-accepted`, `fit-refused`, `writer-prints-word`, `mac-writer-prints-word` and the two name-changed rows
- [x] 3. The real ring with all 8 drivers: `ring-frame: 64 pairs, mismatched: 0`, 64 clean pair lines and 8 lines `refusals <lang>: 38 rows, 0 mismatched`
- [x] 4. `ring-frame-drivers.test.sh`: 44 PASS (8 languages x 4 malformed lines and `skip`, plus 4 Go cases); the Go driver keeps no discarded parse error
- [x] 5. The check is not vacuous: the lenient TypeScript driver of the AZ-3354 commit, in a scratch copy of the tree, fails the driver script and names `FAIL typescript bad-digit`
- [x] 6. Job wiring, loop-tests, ring wiring and ring runner tests pass; the new script is in `test.yml` and the frame ring, its self-test and the driver script are in `scripts/loop-tests.sh`
- [x] 7. No touched source file went over 500 lines in this loop

## Agent walk

7 PASS, 0 FAIL, 0 NOT RUN (`smoke78: 0 failed`, exit 0) on the first trial, at the commit before the close commit.

## For the operator

Nothing: every check ran in the script.
