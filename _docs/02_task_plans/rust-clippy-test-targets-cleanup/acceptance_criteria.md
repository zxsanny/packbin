# Feature acceptance criteria — loop 87

Inherited baseline: project `_docs/00_problem/acceptance_criteria.md` (no row exercised; Rust hygiene only).

## Clippy-clean test targets (AZ-A)
- AC-1: In `rust/`, `cargo clippy --lib --tests` with `--features text,ecc,frame` ends with 0 warnings (HEAD: 6 distinct sites), and with default features and `--no-default-features` stays at 0 for the targets that build.
- AC-2: Behavior is unchanged: `cargo test --features text,ecc,frame` has the same pass count as HEAD (876) and 0 failures.
- AC-3: Only lint-driven edits in test code: no `#[allow(clippy::...)]` is added and no file under `rust/src` other than `text_vectors_tests.rs` changes.
