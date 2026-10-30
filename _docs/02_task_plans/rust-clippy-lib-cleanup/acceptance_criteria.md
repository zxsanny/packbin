# Feature acceptance criteria — loop 86

Inherited baseline: project `_docs/00_problem/acceptance_criteria.md` (no row exercised; Rust hygiene only).

## Clippy-clean lib (AZ-A)
- AC-1: In `rust/`, `cargo clippy --lib` with `--features text,ecc,frame`, with default features, and with `--no-default-features` each end with 0 warnings (HEAD: 11 with the first set).
- AC-2: Behavior is unchanged: `cargo test` with `--features text,ecc,frame` has the same pass count as HEAD and 0 failures; `scripts/loop-tests.sh --all --only ring` passes with 0 mismatched.
- AC-3: Only lint-driven edits: no `#[allow(clippy::...)]` is added except `duplicate_mod` on the intentional `#[path]` table share in `src/nostd/text/mod.rs`, which gets a one-line comment saying why.
- AC-4: `field`, `scheme`, `walk` are `std`-only and `nostd/text/mod.rs` changes by an attribute only, so `rust/embedded/run.sh` pins are unchanged (stated by cfg; the embedded stage is not re-run).
