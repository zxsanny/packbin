# Batch Report

**Batch**: 3 (loop 16)
**Tasks**: AZ-2115 (TypeScript part), AZ-2135 (TypeScript, Java and C++ shares), AZ-2103 (npm JavaScript build); AZ-2099 (embedded errexit), AZ-2193 (CI ring), Python `bitwhen` ring (AZ-2100 flagged concern); documentation pass for batches 1 to 3 (step 13)
**Date**: 2026-10-06

Workers: TypeScript, Java, C++ and harness in parallel (one directory set each), a review per area, a fix pass after the review (two owner decisions on the review findings, two earlier on blocked paths), parent-run Docker, ring, publish gate and embedded stages.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2115, TypeScript part | Done (tests only) | 1 new test file | in the 437 | both rows already packed correctly at HEAD |
| AZ-2135, TypeScript share | Done (AC-1, AC-3) | `flag-scope.ts` (`bindFlagBits`), `fields.ts`, `index.ts`, 1 existing test (spec-forced), 2 new test files | in the 437 | wire change for shared handles, a byte read twice, out-of-order bits |
| AZ-2135, Java share | Done (AC-1, AC-3) + nested-row scope (review, owner A) | `SchemeOrder.java`, `Field.java`, `Scheme.java`, 1 new test class | in the 1324 checks | ninth-bit error now thrown by `new Scheme(...)` |
| AZ-2135 G1, C++ share | Done (AC-2, AC-3) + unpack-side restore the AC rows needed | `order.hpp`, `unpack.cpp`, `grouped_tests.cpp` | 255 `expect` sites (was 237); embedded vectors 241 (was 223) | `flags` / flag-bit scope parity held (owner B) |
| AZ-2103_typescript_npm_javascript | Done (AC-1 to AC-6) after owner approval of two TypeScript-only hunks in the owner's files | `package.json`, `tsconfig.build.json`, `publish-inside.sh`, `publish-gate.test.sh`, new `publish-npm.test.sh`, `.gitignore`, `publish-check.py` and `publish-phases.test.sh` (TypeScript hunks only) | `--npm` checks in the gate | tarball layout changes; versions 0.1.x cannot be imported by plain Node |
| AZ-2099_embedded_errexit | Done (AC-1 to AC-4, AC-6; AC-5 ARM 4 of 4 and ESP 4 of 5 here, full 10 by CI) | `lib.sh`, `run.sh`, `arm.sh`, `esp.sh`, `examples.sh`, new `lib.test.sh` | self-test 30 checks | newly effective errexit may expose a hidden failure in a healthy CI run |
| AZ-2193_ci_cross_language_ring | Done, proof pending the first CI run (owner A: `gcc:16` image through a `CXX` wrapper) | `test.yml` (`ring` job, 2 scaffold steps), new `ring-cxx.sh`, `ring-toolchains.sh`, `ring-wiring.test.sh` | wiring check rejects 28 corrupted copies | `ring` also gates a `v*` tag publish |
| Python `bitwhen` ring | Done | `drivers/handoff.py`, `language-pair.sh` | ring | none |

## Code Review Verdict: PASS_WITH_WARNINGS

Report: `_docs/03_implementation/reviews/batch_03_loop16_review.md`. No Critical or High. Medium findings: Java nested-row scope (fixed, owner A), C++ `flags` / flag-bit scope parity (follow-up, owner B), outer-first numbering test (fixed), `ring` gating tag publishes (accepted), stale docs (step 13).

## Test Suite

CI-parity run by the parent after the fix passes, one stage at a time:

- TypeScript (node 24, Docker): 437 of 437 (was 425 at the start of the batch); strict `tsc` clean.
- Java (JDK 26, Docker): all four mains pass; 1324 checks counted on the host (was 1210); api-check PASS; `javadoc --release 17` exit 0; `javap -public` of `Field`, `Scheme`, `Packbin` identical to HEAD.
- C++ (gcc 16, Docker): `all tests passed`; host 255 `expect` sites (also with g++-15 and `-Wall -Wextra -Werror`).
- `scaffold` stage as CI runs it now (report rows, hostile case file, `check-cases.sh`, embedded harness self-test, ring wiring check): pass.
- `language-pair.sh`: PASS in 65 s, Python now in the `bitwhen` ring (six hand-offs); run on an overlay tree (HEAD plus the batch, the owner's C# hunks not included).
- `publish-gate.test.sh` (full, with the new npm checks): PASS in 372 s.
- Embedded ARM stage: 4 of 4 PASS (Cortex-M4F flash 7784 B of 8192 B, stack 488 B of 512 B, vectors 241 of 241). ESP stage: 4 of 5 PASS; `cpp-example-pico` fails on this arm64 host by design (no linux-arm64 build of the PlatformIO toolchain; `_docs/AGENT_GOTCHAS.md`).
- AC-6 on `packbin-embedded:local` with a broken `arm-none-eabi-nm`: old harness exit 0 and 4 PASS; new harness exit 1 and FAIL for `cpp-m0plus`, `cpp-m3-qemu`, `cpp-m4f`.
- Python 286 and Rust 288 were not touched by this batch (last green run after batch 2).

CI-parity: PASS locally. Linux-only parts that only the first CI run proves: the whole `ring` job (setup actions, `rustup` alias, `npm ci`, driver builds, the `gcc:16` container wrapper with uid/gid, mounts and the static link on x86_64, run time against the 15 minute target, the unauthenticated pull of `gcc:16`); `lib.test.sh` and the embedded targets on bash 5.x with GNU date; the Pico and Arduino examples on a cold cache; the TypeScript build inside the `node:24` container with the read-only mount, proven by the first `v*` tag run.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | C++ treats a flag byte inside a `flags` member or a flag-bit child as visible to later bits; Rust, TypeScript and Java do not (`01000013` unreadable against `01010013`) | AZ-2135 G1, review CP-F1 | follow-up spec (owner, 2026-10-06) | clear |
| 2 | Python numbers split bits by `.bit()` call order and refuses a handle shared by two schemes; Python is not in AZ-2135's component list | AZ-2100, AZ-2135 | add Python to AZ-2135 | unclear (owner) |
| 3 | A same-handle split bit inside a combined `flags` under a split bit is dropped on pack (TypeScript); a `flag_bit` used directly as a `flags` member is never present (C++); both pre-existing | review TS-F2, CP-F2 | same class as the held AZ-2128 concern | unclear |
| 4 | Java: a flag byte outside a nested row with its bit inside builds and packs unreadable bytes; a nested row whose member is absent writes nothing but unpack reads its fields (pre-existing) | AZ-2135 | follow-up spec | unclear |
| 5 | `ring` gates a `v*` tag publish (`publish.yml` calls `test.yml`); a flaky toolchain download or the `gcc:16` pull blocks a publish until "Re-run failed jobs" | AZ-2193, review HW-F1 | accepted | clear |
| 6 | The `gcc:16` container needs neither network nor a writable repo (`--network none`, read-only mount, `--cap-drop ALL` would tighten it); `ring` holds no secret | AZ-2193, review HW-F7 | owner call, not done | unclear |
| 7 | A failing ring consumer is not named in the log (only producer mismatches are) | AZ-2193 AC-3, review HW-F4 | one line in `handoff()`; the spec says the script does not change | unclear |
| 8 | README accessor examples (`u16(0, (x) => x.sid)`) do not type-check under `--strict` (`x` is `unknown`): a strict consumer writes `(x: Target) => x.sid` | AZ-2103 | annotate the README examples or give the accessor helpers a default type parameter | unclear (owner) |
| 9 | `.d.ts` files keep `./x.ts` specifiers: consumers need TypeScript 5.0 or newer unless they set `skipLibCheck` | AZ-2103, review TS-F4 | documented | clear |
| 10 | `publish-position.sh` uses `npm ci --prefix <mktemp dir>`, which fails on macOS when `node_modules` is absent (`/var` symlink); latent, not hit on Linux | AZ-2103 | use `(cd "$work/typescript" && npm ci)` | clear |
| 11 | Rust map `times` with a list longer than the count still drops the extras (`01020102`); Rust map `when` on a field an earlier `when` skipped still writes the body | docs worker, batch 1 and 2 specs | follow-up specs (AZ-2185 to AZ-2187 covered the other packages) | unclear |
| 12 | The embedded harness spec said it cannot run on macOS; on Darwin 25.6 `date +%s%N` works (older macOS prints a literal `N` and the self-test refuses with exit 2) | AZ-2099 | no change | clear |

## Commit

`[AZ-2135] [AZ-2103] [AZ-2099] Number split bits by scheme, ship npm JS` (≤72 chars: count when writing). Body: one line per area + ticket ids + `Loop: 16`.

## Next Batch: B4 (AZ-2098 vcpkg port builds, vendored sources), then steps 10.5 to 17
