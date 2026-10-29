# Loop 82 smoke — the CI scripts no longer use Ruby

LOCAL_URL: none (scripts and the CI `scaffold`, `ring` and `publish-gate` jobs; no site). Branch: dev. Script: `bash _docs/loops/loop82/smoke82.sh`. Run by the agent (owner rule 2026-10-12 in `_docs/04_deploy/deployment_procedures.md` § Loop smoke gate).

This host has no `ruby` (step 2 refuses a PATH that has one), so every PASS below is a run without Ruby. Loop 81 had waived six Ruby scripts here; none is waived now.

## Checks

- [x] 1. No application source is dirty
- [x] 2. No `ruby` on PATH and 0 mentions of it in `.github/workflows` and `scripts` (AZ-3386 AC-1)
- [x] 3. The reader test, one `pyyaml` pin, `report-row.test.sh` and `run-suite.test.sh` with its swift file (AZ-3381 AC-1 to AC-5)
- [x] 4. The precheck: `publish-precheck.test.sh` rejects 11 of 11 mutants; a red run gives `green=false`; the same script without its conclusion check gives `green=true` (AZ-3382 AC-1 to AC-6)
- [x] 5. `publish-jobs.test.sh` (115 rejects), `ring-wiring`, `ring-wiring-rows`, `ring-wiring-swift` pass; a `;` in an `if:` is refused as an unsupported term; a gate job without `timeout-minutes` is refused (AZ-3383 to AZ-3385)
- [x] 6. No PyYAML, a missing file, and a `test.yml` job without the PyYAML install each fail with their cause (AZ-3381 AC-3, AZ-3386 AC-3)
- [x] 7. `scripts/loop-tests.sh --only scaffold,ring,publish-gate --all`: scaffold PASS (157 s), ring PASS (41 s), publish-gate PASS (145 s)
- [x] 8. `bash -n` and syntax clean on every CI script, none over 500 lines

## Agent walk

`smoke82.sh` at ccc2e2f (the commit before the close commit), 411 s, host load 5 to 12: steps 1 to 8 PASS, `smoke82: 0 failed`.

- Step 7: the publish gate printed NOT RUN for the vcpkg supports and consumer checks and the swift consumer resolve (no vcpkg tool and no swift on PATH on this host), as in earlier loops on this host.
- The ring stage needs a JDK on PATH on this host (a user-directory tarball); the script sets it. A first `loop-tests.sh --only ring` without it failed in 5 s on `java: command not found` (step 11 of the loop, before the script).
- CI of the push (AZ-3386 AC-6 / AC-C1), read after the push: `dev` run 40904985660 and `main` run 40904988952 both success in 309 s; the six formerly unrun scripts PASS in the log (details in `record82.md`).

## Result

ccc2e2f: 8/8 steps passed; agent run, owner rule 2026-10-12 in `deployment_procedures.md`. Smoke: PASS.
