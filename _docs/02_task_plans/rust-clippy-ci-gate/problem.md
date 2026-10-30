---
loop: 89
branch: dev
---

# Rust clippy gate in CI (loop 89)

Source: `_docs/loops/loop88/handoff89.md` (candidate "A CI clippy job for the lib and tests"), probed on HEAD f21b4d7 on 2026-10-30. The owner declined this in loops 86 and 87 and chose it at the loop 89 intake ("CI clippy job (lib + tests)"). No UI.

## Problem

Loops 86 and 87 brought `cargo clippy --lib --tests` to 0 warnings, but no CI job runs clippy, so the next lint (or a toolchain bump that adds lints) lands unseen. The Rust suite already fails on any compiler warning in every test target of nine feature sets (`rust_test_build` in `.github/workflows/run-suite.sh`, AZ-3357); clippy is not part of it, and the `rust:1.98` suite image has no `clippy` component (`cargo clippy` there prints `'cargo-clippy' is not installed`).

Probed on HEAD: `cargo clippy --lib --tests` ends with 0 warnings and exit 0 on Rust 1.97.1 and 1.99.1 for all nine sets of `rust_test_build` (`none`, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame`, default, all features). With `-D warnings` the three sets of loop 87 also exit 0 on both toolchains.

## Change location

No UI. Verbal: the Rust part of the CI test run, `.github/workflows/run-suite.sh` (`rust` case and `rust_test_build`), run by `docker-compose.test.yml` service `rust` (image `rust:1.98`). No change under `rust/src`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The owner declined a CI clippy job in loops 86 and 87 | owner chose it at the loop 89 intake | resolved | Low |
| A Rust toolchain bump (`rust:1.98` image tag, `RING_RUST`) can add clippy lints and turn the gate red | the bump change fixes or justifies each new lint; no `allow` added to hide one | open | Medium |
| The `rust:1.98` image needs the `clippy` component added at run time (network; the suite already downloads crates) | a missing component fails the suite, never skips the check | open | Low |
| The extra pass adds wall time to the slowest CI job | AC-4 bound; measured on the first CI run | open | Low |
