# Batch Report

**Batch**: 2 (loop 15)
**Tasks**: AZ-2215_build_containers_read_only, AZ-2219_rust_round_limits
**Date**: 2026-10-06

Two workers in parallel on disjoint paths (`.github/` + compose files, `rust/`). Parent re-verified the whole tree afterwards, one stage at a time.

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2215_build_containers_read_only | Done locally (AC-1 to AC-8); Linux-only parts (ownership, Compose 2.38.2 merge, `/out` mount) proven only by the first CI `scaffold` run | new `docker-compose.publish.yml`, new `publish-readonly.test.sh`; modified `publish-lib.sh` (`publish_container`), `publish-build.sh`, `publish-gate.sh`, `publish-inside.sh` (C# packs from a copy), `publish-position.sh`, `publish-gate.test.sh` (hook), `ci_cd_pipeline.md` (two copies); parent added `docker-compose.publish.yml` to the required files of `test.yml` | `publish-gate.test.sh` passes (415 s) | see review |
| AZ-2219_rust_round_limits | Done (AC-1 to AC-13) | `field/map_scheme.rs`, `field/mod.rs`, `field/order.rs`, `field/shape.rs`, `walk/pack.rs`, `walk/unpack.rs`, `walk/mod.rs`, `lib.rs`, `scheme/mod.rs`, new `tests/round_limits_tests.rs` | 234 of 234 (217 before, +17); no existing test edited | none |

## Decisions

- **AZ-2215:** a second compose file `docker-compose.publish.yml` (repo root) mounts `./:/src:ro` and a tmpfs at `/test-results` for the six services; `docker-compose.test.yml` is unchanged because the suites build in the tree. One function `publish_container` is the only `docker compose` call of the publish scripts (build phase and golden gate). Each build container gets only its own `artifacts/<lang>` folder writable, at `/out/artifacts/<lang>` with `PACKBIN_OUT=/out`; the "PACKBIN_OUT must be inside the repo" rule is gone. The C# pack and the C# golden driver work from a container-local copy; the TypeScript gate runs `npm ci` in a copy when `node_modules` is absent. The loop 14 chown of the artifacts folder stays. The Compose behavior that `run -v` over an existing mount is silently ignored (checked on 2.24.3) is the reason for the second file; the config test and a mutation test keep the property.
- **AZ-2219:** `MapScheme::with_limits(self, max_rounds, max_slots)` and `Scheme<T>::with_limits` (delegating to the layout), getters, crate-root `DEFAULT_MAX_ROUNDS` (65,535) and `DEFAULT_MAX_SLOTS` (4,194,304); a zero limit panics naming the limit; the per-call `Cursor` carries the counters; `FieldKind::Repeat` and `Times` gain a `slots` count computed once at construction; the refusal is `Short { field: "repeat" | "times", needed: 0, left }` (no new error variant: the enum is not `non_exhaustive`).

## Memory (Rust, 1 MiB one-byte rounds, `VmHWM` on Linux)

| Case | Before | After (defaults) |
|------|--------|------------------|
| map `repeat`, one-byte rounds | 281 MB | 20 MB, refused |
| map `repeat`, 8 flag bits set | 871 MB | 57 MB, refused |
| map `times`, count 1,048,576 | 314 MB | 20 MB, refused |
| map `times`, 8 flag bits set | 1,167 MB | 57 MB, refused |
| typed `times` rows, 8 bool flag bits | 1,175 MB | 57 MB, refused |

No Rust one-byte round can hold 36 names (one byte reads at most 8 flag bits or 4 `u2` names), so the README (AZ-2220) quotes the 8-flag-bit figures for Rust.

## Code Review Verdict: PASS_WITH_WARNINGS

Parent read every hunk of both tasks. Mutation checks by the workers: removing the Rust check fails 10 of the 17 new tests; dropping the override file makes the container probe write into `/src` in 7 of 7 attempts and the new test file fails on the unchanged scripts. Findings, none blocking:

| # | Severity | Finding | Handling |
|---|----------|---------|----------|
| 1 | Low | `docker-compose.publish.yml` lists the six services by hand and the config test checks the same fixed list: a seventh service added to the base file would stay read-write with no test failing | Open; the test should read `docker compose config --services` of the base file (follow-up) |
| 2 | Low | Rust `with_limits` panics on a zero limit while C#, TypeScript and Java throw a typed error | Open, as the spec decided; recorded for the README |
| 3 | Medium (verification gap) | The `/out` bind mount, the merge of the second compose file and file ownership on Compose 2.38.2 and the Ubuntu runner are not reproducible on Docker Desktop (the loop 14 failure was of this kind) | Accepted: the first CI `scaffold` run after the push is the final proof; nothing is tagged before it is green |

CI-parity: PASS locally. Parent ran, one stage at a time and with no competing job: the six `docker compose -f docker-compose.test.yml run --rm <lang>` suites (C# 407, TypeScript 276, Python 103, Rust 234, C++ and Java all passed), `cpp-embedded` (4 of 4 targets), `cpp-embedded-esp` (4 of 5; `cpp-example-pico` fails on this arm64 host by design, covered by CI and the loop 14 runs with both toolchains), `cases.test.sh`, `report-row.test.sh`, `publish-gate.test.sh` (415 s), strict `tsc`, `language-pair.sh` (68 s). 12 of 13 stages passed. `cargo clippy` shows 6 warnings, all older and outside the changed lines; the crate is not rustfmt-clean at HEAD (unrelated files).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `test.yml` required-file list should name `docker-compose.publish.yml` | AZ-2215 Scope (docs) | Done by the parent in this batch | clear |
| 2 | `docker_stack.md:3` (says the only compose file is `docker-compose.test.yml`), `containerization.md` and the build-phase paragraph of `packages.md:36` still need a mention of `docker-compose.publish.yml` and the `/out` mount | AZ-2215 | The docs pass (step 13) | clear |
| 3 | Inside the container the other targets' artifacts are still visible read-only at `/src/.github/workflows/out/artifacts/...` when `PACKBIN_OUT` is in the repo; only `/out` is exclusive | AZ-2215 AC-2 | Accepted: those files are published anyway; hiding them needs a nested mount in a read-only bind | clear |
| 4 | `publish-gate.test.sh` is 453 lines and `publish-phases.test.sh` is still exactly 500; the gate test now takes about 7 minutes | AZ-2215 | None; next additions go in new sibling files | clear |
| 5 | Rust 36-name one-byte rounds are not constructible; README figures for Rust are the 8-flag-bit ones | AZ-2219 | AZ-2220 | clear |

## Commit

`[AZ-2215] [AZ-2219] Read-only build containers, Rust round limits`. Body: one line + `Loop: 15`.

## Next Batch: AZ-2220_round_limits_hostile_and_docs
