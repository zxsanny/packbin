# Loop 81 smoke — the frame ring refuses a key or msg_id of the wrong length in all 8 languages

LOCAL_URL: none (scripts and the CI `scaffold`, `ring` and `publish-gate` jobs; no site). Branch: dev. Script: `bash _docs/loops/loop81/smoke81.sh`. Run by the agent (owner rule 2026-10-12 in `_docs/04_deploy/deployment_procedures.md`).

Owner waiver (2026-10-29): this host has no `ruby` and `sudo` needs a password, so four scaffold scripts that parse YAML with `ruby -ryaml` are NOT RUN here: `report-row.test.sh`, `run-suite.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`. They read `test.yml` and `docker-compose.test.yml`, which this loop does not change. CI's `scaffold` job runs them on the push. The port of the CI scripts from Ruby to Python is loop 82 (`handoff82.md`).

## Checks

- [x] 1. No application source is dirty
- [x] 2. `ring-frame.test.sh` passes (37 PASS), among them `id-padded`, `key-aborts` and `empty-key-and-id-keep-fields` — AZ-3378 AC-5, AC-6
- [x] 3. The real ring with all 8 drivers (C++ built in `gcc:16`): `ring-frame: 64 pairs, mismatched: 0` and 8 lines `refusals <lang>: 58 rows, 0 mismatched` — AC-1, AC-2
- [x] 4. `ring-frame-drivers.test.sh`: `all passed (8 languages, 276 checks)`: every driver prints `BadValue` for a key of 0, 31 or 33 bytes (seal, open, mac, verify) and a `msg_id` of 0, 7 or 9 bytes (seal, open) — AC-3, AC-4, AC-7
- [x] 5. Not vacuous: the start-commit loader fails `empty-key-and-id-keep-fields`; the start-commit rows fail `id-padded`, `key-aborts` and that case (3 FAIL); the start-commit Rust and C++ drivers fail 18 and 6 driver checks — AC-5, AC-6
- [x] 6. `ring-wiring-rows.test.sh` and `ring-lib.test.sh` pass
- [x] 7. The `scaffold` stage of `scripts/loop-tests.sh`, command by command (20 commands, same order), without the four waived scripts
- [ ] 8. `scripts/loop-tests.sh --only ring,publish-gate`: **ring PASS (42 s); publish-gate FAIL (194 s)**, only on two Ruby checks: share 7 `publish-workflow.test.sh` (AZ-2095) and `publish-pins.test.sh` (AZ-2214) print `ruby is required to parse the workflow YAML`; 7 of 8 shares and 9 of 11 checks of share 7 pass. Owner waiver 2026-10-29 (second)
- [x] 9. shellcheck clean on the two edited scripts, Python compiles, no touched source file went over 500 lines (`handoff.cpp` is 639 lines, over the cap before this loop)

## Agent walk

`smoke81.sh` at ed7d144 (the commit before the close commit), 395 s, host load 1.3 to 21: steps 1 to 7 and 9 PASS, step 8 FAIL, `smoke81: 1 failed`.

- Step 2: 37 PASS. Step 3: `ring-frame: 64 pairs, mismatched: 0`, 8 x `58 rows, 0 mismatched`. Step 4: `all passed (8 languages, 276 checks)`. Step 5: the start-commit loader fails 22 stand-in cases (every one, since the line loses a field) including `empty-key-and-id-keep-fields`, the start-commit rows fail 3, the start-commit drivers fail 24 (18 Rust, 6 C++).
- Step 7: 20 scaffold commands, 0 failed (123 s in the earlier run). WAIVED: `report-row.test.sh`, `run-suite.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh` (no `ruby`).
- Step 8: `STAGE ring: PASS (42s)`; `STAGE publish-gate: FAIL (194s, exit 1)`: shares `phases`, `phases-rerun`, `readonly,gate`, `readonly-gate-good`, `readonly-gate-bad`, `readonly-gate-nojava` and `swift` PASS; share 7 FAIL (86 s) with `FAIL: AZ-2095 ruby is required to parse the workflow YAML` and `FAIL: AZ-2214 ruby is required to parse the workflow YAML`. NOT RUN (documented skips): the swift consumer resolve (no swift on PATH), the vcpkg consumer check and the vcpkg supports check (no vcpkg tool). None of `publish*`, `test.yml`, `tool-pins.txt` or the compose files changed in this loop.
- The gate ran 194 s here (633 s on the Mac in loop 80, 331 s in loop 79).

## For the operator

Six Ruby scripts did not run on this host: the four scaffold scripts and the two publish-gate checks above. CI runs them on the push (the runners have Ruby). The Ruby-to-Python port of these scripts is loop 82 (`handoff82.md`).

## Result

ed7d144: 8/9 steps passed; step 8 failed only on the two waived Ruby checks; agent run, owner rule 2026-10-12 in `deployment_procedures.md`, with the owner's waivers of 2026-10-29. Smoke: PASS (owner waiver).
