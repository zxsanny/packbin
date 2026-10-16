# Loop 29 notes — gate timing evidence (GC-7)

Measured 2026-10-16 on the Mac (arm64, 10 cores, load average 19 to 29 from another project's VM, so absolute seconds are high and noisy; the ratios hold). Driver: a scratch copy of `publish-gate.test.sh` that times each sub-function, then wraps `publish-gate.sh`, `ph_publish` and `sw_publish` (not committed).

## Run 1: per sub-function (total 1 075 s, 0 failures, 0 NOT RUN)

| group | item | s |
|-------|------|---|
| gate | gate_checks | 217 |
| swift | sw_check 5, sw_rerun 3, sw_refusal 4, sw_gate 4, sw_position 1, sw_static 0, sw_credential 1 | 18 |
| swift | sw_real_checks | 131 |
| swift | sw_mutant_checks (30 mutants, run one after another) | 158 |
| readonly | symlink 0, static 1, probe 13, out 13, host_path 9 | 36 |
| readonly | ro_gate_checks | 227 |
| readonly | ro_full_run_check | 46 |
| phases | static 0, setup 12, fabricated 2, empty_plan 0, build_only 28, full_publish 28, failure_injection 46, pipeline_violations 11 | 127 |
| phases | ph_rerun_checks | 113 |

## Run 2: per call (gate_checks 243 s, ro_gate_checks 235, sw_real 139, ph_setup 15, ph_rerun 128; total 763 s)

| call | s |
|------|---|
| gate_checks: publish-gate.sh normal / bad golden fixture (rc 1) / no java | 90 / 68 / 77 |
| ro_gate_checks: publish-gate.sh normal / bad fixture (rc 1) / no java | 81 / 73 / 73 |
| sw_real: real-first / real-again / real-moved | 57 / 56 / 26 |
| ph_rerun: credential matrix (10 refused runs) | 0 each |
| ph_rerun: optional-fails 8, tag-conflict 4, query-503 4, partial 12, optional 25 | 53 |
| ph_rerun: chain-1 / chain-2 / chain-3 (each builds 9 targets) | 23 / 24 / 24 |

## Findings

1. `gate_checks` and `ro_gate_checks` run the same three scenarios against the same script on a tree copy (normal, a bad golden hex, java removed): six real gate runs, 458 s, for three scenarios. The read-only tree runs assert a superset (exit code, plan, tree manifest unchanged) except for two assertions that only `gate_checks` makes: the csharp pack line still carries the real hex (AC-3 "pack ignored the bad fixture") and the log line `absent java` with java absent from the plan (AC-4).
2. The 30 swift mutants are independent (own copy directory, own log, scenario in a subshell) but run one at a time: 158 s on 10 cores.
3. `real-again` repeats `real-first` (57 s) to prove the re-run passes with the real toolchain; kept unless the other cuts fall short.

## Cuts and the assertion ledger (GC-4, GC-5)

### Cut 1: `gate_checks` keeps its default-root run; the bad-fixture and missing-java runs live in `ro_gate_checks` only

Removed from `gate_checks` (publish-gate.test.sh), with the twin that stays:

| removed assertion (run) | twin in `ro_gate_checks` |
|-------------------------|--------------------------|
| bad fixture: exit code non-zero ("AC-3 mismatch still published") | "AZ-2215 AC-5 a bad fixture passed the gate" |
| bad fixture: plan empty ("AC-3 plan was not empty") | "AZ-2215 AC-5 the bad fixture left a plan" |
| bad fixture: csharp pack line carries the real hex ("AC-3 pack ignored the bad fixture") | moved: same assertion added to `ro_gate_checks` |
| no java: java not in the plan ("AC-4 java was published") | moved: added to `ro_gate_checks` |
| no java: log line `absent java` ("AC-4 java was not absent") | moved: added to `ro_gate_checks` |
| no java: 7 plan lines ("AC-4 seven languages") | "AZ-2215 AC-5 seven languages without java" |

0 unique assertions removed. The default-root run (the in-place path CI uses) stays in `gate_checks`; the tree-copy path (SRC_ROOT apart) is what `ro_gate_checks` runs.

Mutation proof (one mutant per changed scenario; a repo copy with `publish-gate.sh` broken, `ro_gate_checks` run against it): M1 `if [ "$mismatch" -gt 0 ]` to `if false`; M2 `echo "pack $lang $hex"` to print the expected hex; M3 `echo "absent $lang"` renamed. Results below.

### Cut 2: swift mutants run 4 at a time (`PACKBIN_MUTANT_JOBS`, default 4)

Same 30 mutants, same pass condition ("a mutant the checks passed is a failure"), verdicts read in call order. Mutants alone on the Mac at the same load: 159 s with 1 job, 97 s with fixed batches of 4, 72 s with a pool of 4, 68 s with 8 (the slowest mutants set the floor). Proof that the verdict still catches a passing mutant: an identity mutant in a scratch copy is reported (result below).

### Cut 3: `sw_real_checks` runs beside the stub scenarios and mutants inside `swift_checks`

The group stays one timed group (`timed swift swift_checks`). The subshell's failure count and NOT RUN note return through a status file; a subshell that stops early is a failure. Swift group on the Mac: 284 to 307 s before, 160 s after.

### Timing annotations

`timed` and `timed_total` also print `::notice title=publish gate timing::...` on GitHub Actions, so the per-group seconds of a CI run are readable from the public check-runs annotations (job logs need a token). `publish-timing.selftest.sh` asserts it and rejects a copy without it.

### Mac full run after cuts 1 to 3 (load average about 9; baseline runs were at 19 to 29)

total 906 s (905 s wall), 14 checks, 0 failures, NOT RUN: the two vcpkg checks (no vcpkg tool on this Mac, as before). Groups: static 0, crates-token 1, registry 3, vcpkg 10, gate 72 (was 217), go 16, swift 160 (was 284), manifest 0, npm 6, position 1, workflow 4, pins 31, phases 272 (was 251), readonly 330 (was 263). GC-2 (at most 800 s) is not met on the Mac: the docker-bound groups readonly and phases did not get faster and carry 602 s of the 906.

### Mutation proof results (2026-10-16)

| mutant | `ro_gate_checks` against the broken copy |
|--------|-------------------------------------------|
| M1 bad fixture still publishes (`if false`) | 2 FAIL: "a bad fixture passed the gate", "the bad fixture left a plan" |
| M2 pack line prints the expected hex | 1 FAIL: "AC-3 pack ignored the bad fixture: expected [4001000065cd1d00a3e1110100] got [00]" |
| M3 `absent` line renamed | 1 FAIL: "AC-4 java was not absent" |
| identity swift mutant ("no pin check" given its own text) | 1 FAIL: "the swift checks passed a copy with: no pin check"; the other 29 rejected |
| timing notice line removed | `publish-timing.selftest.sh`: 2 FAIL (alpha, total) |
