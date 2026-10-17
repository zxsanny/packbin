# Batch 1 report — loop 31

Task: AZ-2607 (CI speed 2, 5 points), batch 1 of 2: structure and timing. No per-batch review (owner preference: one total review before step 11). Three workers with disjoint file sets (timing notice, parallel Mac gate, phases split); the parent did the read-only split, the guards and the audit.

| Part | Status | Evidence |
|------|--------|----------|
| Read-only gate split (AC-3) | Done | `readonly` → `readonly`, `readonly-gate`, `readonly-full`; `gate_groups` 14 → 16; `test.yml` gate jobs 3 → 5; `publish-jobs.test.sh` mutants 45 → 50 (all rejected); `publish-timing.selftest.sh` `ro_split` (each of the 7 `ro_*_check(s)` functions runs in exactly one group) with 4 mutants rejected |
| Suite timing notice (AC-2) | Done | `run-suite.sh` writes one `::notice title=<lang> suite timing::` (Swift: `swift (<part>) suite timing`) with every step line and a total, pass or fail, only when `GITHUB_ACTIONS` is `true`; `docker-compose.test.yml` passes the bare key to the 8 suite services; `run-suite.test.sh` N1 to N6, `run-suite-swift.test.sh` S2e; 14 mutants rejected (worker table) |
| Parallel Mac gate (AC-4) | Done, proof at step 11 | `scripts/loop-tests.sh` `gate_shares` reads the `--groups` lists of `test.yml`, `run_gate_shares` starts all at once, `tree_manifest` fails the stage when the tree changed; `loop-tests.test.sh` case 16a to 16e; 12 mutants rejected; the 0.7 ratio is printed (`publish-gate shares: wall, sum`) and read at step 11 |
| `publish-phases.test.sh` split (AC-5) | Done | 501 → 323 lines; `publish-phases-failures.test.sh` 193 lines (3 failure scenarios moved byte-identical; inventory of 16 functions identical); `phase_checks` still calls 9 functions |
| Host-delete audit (AC-6) | Done | `notes31.md`: 0 harmful sites |
| Gate trap bug (found by the Mac-gate worker) | Fixed | `publish-vcpkg.test.sh` replaced the gate's `timed_abort` EXIT trap, so a group that aborted after vcpkg in the same job was not named; the trap now calls `timed_abort`; `publish-timing.selftest.sh` refuses an EXIT trap in a check file without `timed_abort`, with a mutant |

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | the Swift step labels kept the swift options (`${*//...}` matched per word): on CI the 110-character cut left `…--build-test` for two different steps | fixed in `run-suite.sh` (cut on the joined line), guarded by S2e and a mutant | clear |
| 2 | `GITHUB_ACTIONS=true` is now set in the suite containers and, through the shared base compose file, in the publish build and gate containers | no tool in the repo reads it; the first CI run is the proof | unclear |
| 3 | `run-suite.sh` prints a plain `run-suite: <lang> total took N s in K steps` line to stderr and a notice even with 0 steps | kept | clear |
| 4 | shares that run at the same time on the Mac share the compose project `packbin-publish` (4 shares), host `~/.platformio` (3 shares), the pip and idf-component-manager caches; no fixed container name, port or `compose down` | low risk; step 11 shows it; up to 6 to 7 toolchain containers at once (Docker Desktop memory: exit 137 would look like a gate failure) | unclear |
| 5 | a group that prints only at its end (`readonly-full`) keeps its log size flat for minutes, so the Mac heartbeat shows it quiet but cannot show it alive | proposed: `timed` prints "<group> started"; not built | unclear |
| 6 | the worker found `echo "$out" \| grep -q` under pipefail failing with a broken pipe once at load 87 in `loop-tests.test.sh` | fixed in that file (20 lines now use `<<<`) | clear |
| 7 | two workers used the same scratch directory `mut/`; one deleted the other's mutant copies once | both reran; future worker prompts name a ticket-specific scratch directory | clear |
| 8 | AC-1 (wall ≤ 360 s as the median of two `dev` runs) cannot be shown until the owner's push go | batch 2 | clear |

## CI-parity

CI-parity: PASS (2026-10-17, Mac at load 20 to 60). Commands, with seconds: `report-row.test.sh` 30, `fixtures/hostile/cases.test.sh` 181, `run-suite.test.sh` 60 (it sources `run-suite-swift.test.sh`, so the S2e row ran there), `cpp/embedded/lib.test.sh` 30, `ring-wiring.test.sh` 30, `scripts/loop-tests.test.sh` 60, `publish-jobs.test.sh` 30 (50 mutants), `publish-timing.selftest.sh` 30, `publish-workflow.test.sh` 30, `docker compose -f docker-compose.test.yml config` 30, all PASS. `shellcheck -x -S warning` on the 7 changed shell files: one warning (SC2154 `here` in `publish-phases.test.sh`), identical to HEAD, so nothing new; CI runs no shellcheck. A first parity run called `run-suite-swift.test.sh` on its own, which fails because only `run-suite.test.sh` sources it (my harness mistake; no file was written, the root filesystem is read-only). No language source changed, so no language compile or unit step applies. The real `docker compose run` of the suites, the publish gate and the new parallel Mac gate stage run once at step 11.
