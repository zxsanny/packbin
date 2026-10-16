# Deploy status

**Date**: 2026-09-23
**Mode**: resume

Kept `_docs/04_deploy/packages.md` and `loop_end_merge: stage`.

## Deploy artifact inventory

| Item | State |
|------|--------|
| `scripts/` | absent |
| `infra/` | absent |
| `.env.example` | token names, empty values |
| `docker-compose.test.yml` | six test images, no published ports |
| `.github/workflows/test.yml` | test on push and pull request |
| `.github/workflows/publish.yml` | publish on a `v*` tag |
| `_docs/02_document/deployment/` | containerization, procedures, environment, observability |

## Host roles

| Role | Host |
|------|------|
| dev | this workstation |
| ci / builder | GitHub Actions |
| registry | npm, NuGet, PyPI, crates.io, Maven Central, vcpkg git |
| deploy | none — a registry publish is the release |

## Gap list

Remote SSH, Woodpecker, and `scripts/deploy.sh` are not gaps to fill. A laptop deploy script would be a second publisher next to `publish.yml`. Health is the golden hex, not an HTTP endpoint.

## CI run of `f30c87e` (loop 26 close push, 2026-10-14): FAIL, 2 of 3 jobs per run green

Runs 38588698291 (`dev`) and 38588700455 (`main`), `test.yml`. `embedded` PASS (6 min) in both. `scaffold`: the `suites` step (all nine suites including `swift` in `swift:6.3.3`: debug tests, fuzz, sanitizer, release) PASSED on the Ubuntu runner in both runs (16 min 47 s); the `publish gate` step FAILED in one run (exit 1 at line 1966 of its log, 19 min) and PASSED in the other (scaffold 36 min). `ring` FAILED in both at step "toolchain versions" (24 s), the first Swift ring run on a runner.
- Likely cause: `ring` — `ring-toolchains.sh` compares the runner's Swift with `RING_SWIFT` (6.3.3) at full precision and `ubuntu-latest` carries another Swift (or none that matches); read-only evidence is the step name and exit 1, the log itself needs a signed-in GitHub session (403 unauthenticated). `publish gate` — unknown without its log: one run passed on the same commit.
- Flaky vs real: `ring` real and deterministic (both runs); `publish gate` flaky or environment (same commit, one PASS and one FAIL).
- Next canonical action: read the two job logs (runs above, jobs 115937491350 and 115937490795); for `ring`, build the Swift drivers in the pinned `swift:6.3.3` image whenever the runner's Swift differs (as `ring-cxx.sh` does for GCC) and fix on `dev`, push again; for the gate, find the failing check at log line 1966.

## CI run of `aefaf37` (ring fix push to `dev`, 2026-10-15): FAIL, `publish gate` only

Run 38682003152, `test.yml`. `ring` PASS (4 min 44 s: the Swift fix of `aefaf37` holds on the runner), `embedded` PASS (5 min 43 s), `scaffold` FAIL at step 11 `publish gate` after 30 min 20 s (04:53:55 to 05:24:15); its `suites` step passed.
- Likely cause: the gate runs about 30 min on the runner against 1 837 s (30.6 min) on the owner's Mac and 19 min in the failed `f30c87e` run, so the step ends by a time or resource limit or a Swift-scenario failure; the log needs a signed-in GitHub session (403 unauthenticated), the failing check is unread.
- Flaky vs real: not flaky any more: `f30c87e` passed the gate once and failed once, `aefaf37` failed; the Swift gate scenarios (loop 26) are the only change since the last green gate (`b81102f`).
- Next canonical action: the owner reads the gate log of job 116248405906 (the failing check name and last lines), or loop 27 reproduces the gate with the Swift scenarios in the CI image; then fix on `dev` and push again.

### Loop 27: cause of the `aefaf37` publish gate failure (found by reproduction, 2026-10-15)

The log of job 116248405906 was never read (sign-in). Reproduced in `swift:6.4.1` (Linux, the runner's Swift minor) running `publish-swift.test.sh`: 9 failures, all `position:` checks, `expected [4001000065cd1d00a3e1110100] got []` and `did not build a copy named packbin in its own scratch: swift --version`. Cause: since `aefaf37` `ring-swift.sh` `use_local_swift` reads `swift --version` on Linux (on Darwin it returns true first, so the Mac never showed it). The test's stand-in `swift` (`sw_write_ring_swift` in `publish-swift-gate.test.sh`) printed nothing for `--version`, so on the runner the position program took the `docker run swift:6.3.3` build path instead of the stand-in, the stand-in's build log stayed empty, and every position assertion failed (after up to three cold image builds, hence the 30 min). Fix: the stand-in answers `--version` with `Swift version <pin> (stub)`. Verified: same container, 0 failures, 30 mutants rejected, 164 s. The earlier `f30c87e` gate failure (one of two runs, before `aefaf37`) has a different cause that this does not explain; CG-3 (three green runs) decides.

### CI run of `94834ef` (loop 27 gate fix, 2026-10-15): PASS

Run 38694589648, `test.yml`: `ring` 265 s, `embedded` 296 s, `scaffold` 2 618 s (`suites` 1 238 s, `publish gate` 1 322 s), all `success`; 43 min 42 s end to end. The `aefaf37` cause named above is confirmed on the runner. CG-1 and CG-2 met (gate <= 1 500 s, `scaffold` <= 3 000 s); CG-3 (three green gate runs in a row) stands at 1 of 3.

### CI run of `00ad75f` (Swift sanitizer scope, 2026-10-15): PASS

Run 38700362252, `test.yml`: `ring` 270 s, `embedded` 352 s, `scaffold` 1 977 s (`suites` 860 s against 1 238 s before, `publish gate` 1 061 s), all `success`; 33 min 1 s end to end (was 43 min 42 s). CG-3 stands at 2 of 3 green gate runs; the loop close push is the third.

### CI runs of `b940ec4` (loop 27 close, `dev` and `main`, 2026-10-15): PASS

Runs 38705480464 (`dev`) and 38705483876 (`main`), `test.yml`, all jobs `success`: `scaffold` 2 153 s and 2 295 s (`suites` 940 s and 984 s, `publish gate` 1 160 s and 1 245 s), `ring` 283 s and 242 s, `embedded` 317 s and 326 s; 36 and 38 minutes end to end. The gate has passed in 4 runs in a row (`94834ef`, `00ad75f`, and both runs of `b940ec4`): CG-3 met. `scaffold` stays under 3 000 s (CG-2); the two runs were slower than the 1 977 s of `00ad75f`, the spread between runs on the same code is about 3 minutes.

### Loop 28: cause of the `cpp` pool stage failure (found by reproduction, 2026-10-15, AZ-2565)

Not a race between pool stages. Only the `cpp` stage writes `cpp/build` in the pool (`scaffold` runs temp-tree tests and never builds C++). The stage ran `make -C cpp clean` on the host and then `docker compose run --rm cpp`; on Docker Desktop a container started within about a second of the host `rm -rf` still sees the old entries (a probe 0.34 s after the delete saw the stale file and directory twice; at 1.4 s and later they were gone). Reproduced with no other stage running: the old command alone, 12 runs from a populated build, failed 6 times in 0 to 1 s (`build/pack_without_scheme.cpp.out: No such file or directory`); each run after a failure (no `build/` left to delete) passed in 22 to 25 s. The loop 27 logs show the same sequence (`rm -rf build` on the host, `mkdir -p build` in the container, 35 s of g++, `ld: cannot open output file build/packbin_tests`). Fix: the container cleans (`make -C /src/cpp clean && exec run-suite.sh cpp`). Six stage runs from a populated build passed (24 to 28 s); 3 pool runs of `--all --only cpp,scaffold --jobs 3` passed with 0 retries (cpp 24 to 27 s, scaffold 172 to 174 s); a Mach-O `cpp/build` from the host is rebuilt as ELF without a manual clean. The exact `ld` message was not seen locally, only its sibling (same mechanism, different stale entry). Guard: `loop-tests.test.sh` check 15 rejects the old command (1 mutant).

### Loop 28: Swift peak memory (AZ-2567)

See `_docs/05_security/swift_peak_memory_loop28.md`: F10 packet 731 MB (macOS) and 738 MB (`swift:6.3.3` container), wide round 154 MB and 147 MB; no finding (below 1 000 MB). The Go figures (625 MB, 94 MB) are Go heap, not resident size.

### CI run of `b7d6577` (loop 28, job split, 2026-10-15): PASS

Run 38731123341, `test.yml`, five jobs all `success`, started together at 11:58:07 to 11:58:08: `scaffold` 53 s, `ring` 4 min 45 s, `embedded` 6 min 3 s, `suites` 17 min 17 s (the suites step 1 030 s), `publish-gate` 22 min 50 s (pull images 96 s, publish gate step 1 269 s). End to end 22 min 51 s against 33 to 38 minutes for the single `scaffold` job (SP-1 met; SP-2 met once, the close push of `dev` and `main` gives the second run). The wall time is now the gate job; the gate's four large groups (swift 284 s, readonly 263 s, phases 251 s, gate 191 s on the Mac) are where it is cut next.

### CI runs of `182fbba` (loop 28 close, `dev` and `main`, 2026-10-15): PASS

Runs 38736351180 (`dev`) and 38736693696 (`main`), `test.yml`, all five jobs `success` in both: `scaffold` 63 s and 50 s, `ring` 287 s and 304 s, `embedded` 354 s and 352 s, `suites` 1 044 s and 876 s, `publish-gate` 1 144 s and 1 392 s; end to end 19 min 5 s (`dev`) and 23 min 12 s (`main`). With run 38731123341 (22 min 51 s) that is 3 of 3 runs under 25 minutes: SP-2 met. The `main` run was 4 minutes slower on the gate job than the `dev` run on the same code; the spread between runs is about that size, so 25 minutes is tight when the runner is slow.


## Loop 29: publish gate cut (AZ-2582, 2026-10-16)

Goal: the `publish-gate` job of `test.yml` at most 18 minutes (median of 3 runs of the final code), without losing an assertion or a mutant. Evidence, ledger and mutation proofs: `_docs/loops/loop29/notes29.md`; step 11: `_docs/03_implementation/test_run_loop29_report.md`.

### Where the gate time went (Mac, load average 19 to 29, per sub-function and per call)

Total 1 075 s: `gate_checks` 217 s and `ro_gate_checks` 227 s (each runs the real `publish-gate.sh` three times: 90 / 68 / 77 s and 81 / 73 / 73 s), `sw_real_checks` 131 s (real swift: 57 / 56 / 26 s), the 30 swift mutants 158 s (about 5 s each, one at a time), `ph_rerun_checks` 113 s, `ro_full_run_check` 46 s, `ph_failure_injection` 46 s. The other 9 groups: about 37 s.

### Changes

1. Duplicate runs: `gate_checks` keeps the default-root run; the bad-fixture and missing-java scenarios live in `ro_gate_checks` (three assertions moved there, three had twins that were already there).
2. Swift mutants run four at a time (159 s to 72 s alone, same load).
3. `sw_real_checks` runs beside the stub scenarios and mutants (swift group 284 to 160 s).
4. `ro_gate_checks` runs its three scenarios together on three tree copies (227 to 124 s alone).
5. The timing lines are also one `::notice` annotation on GitHub Actions (GitHub keeps 10 notices per step: the first version lost the last five lines, found on the first CI run).

### CI runs

| Run | Commit | publish-gate job | gate step | suites | end to end |
|-----|--------|------------------|-----------|--------|------------|
| 38731123341 (loop 28) | b7d6577 | 1 370 s | 1 269 s | 1 037 s | 22 min 51 s |
| 38868021571 (batch 1) | 178349f | 1 069 s | 1 005 s | 956 s | about 17 min 50 s |
| 38888934994 (final code, run 1) | 1ce48a2 | 689 s | 593 s | 888 s | about 14 min 50 s (`suites` is the longest job) |
| 38891164077 (close push, `dev`, run 2) | 2cade74 | 825 s | 720 s | 1 071 s | about 17 min 50 s (`suites` longest) |
| 38891168328 (close push, `main`, run 3) | 2cade74 | 1 011 s | 947 s | 874 s | about 16 min 50 s (gate longest) |

GC-1 is met: median of the three runs of the final code 825 s (limit 1 080 s), longest 1 011 s (limit 1 200 s). The same code varies by about 320 s between runs. `scaffold` 54 to 61 s, `embedded` 296 to 357 s, `ring` 271 to 284 s in the three runs.

Per-group seconds of the last run (annotation): static 0, crates-token 0, registry 0, vcpkg 11, gate 74, go 5, swift 116, manifest 0, npm 4, position 1, workflow 3, pins 20, phases 158, readonly 201, total 593 in 14 checks.

### Mac

`scripts/loop-tests.sh` at e20e8fd: scaffold PASS 163 s, publish-gate PASS 754 s (load 10 to 16). Two complete gate tests at once: 989 s and 990 s, both pass.

### Left open

`suites` (888 s) is now the longest job: a matrix of one job per language is the next step if the wall time matters. The phases group (158 s on the runner, 334 s on the Mac with two runs) and `readonly` (201 s) hold the remaining gate time: six builds of nine targets run one after another in the phases scenarios. An aborted gate leaves its `mktemp` directories (unchanged). The median of 3 is done (825 s).
