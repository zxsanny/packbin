# Feature assessment — loop 87

Verdict: COMPLETE

Spec: `_docs/02_tasks/todo/AZ-3430_rust_test_targets_clippy_clean.md`. Read-only check on the diff of the batch.

| AC | Evidence | Verdict |
|----|----------|---------|
| AC-1 | `cargo clippy --lib --tests` with `--features text,ecc,frame`, default features, `--no-default-features`: 0 warnings each (HEAD: 6 distinct sites with the first set) | met |
| AC-2 | `cargo test --features text,ecc,frame`: 876 passed, 0 failed, 1 ignored (same as loop 86) | met |
| AC-3 | 6 files, +8 -8; no `allow(clippy::...)`; the only file under `rust/src` is `text_vectors_tests.rs` (a `type Rows` alias) | met |

Notes: `cargo fmt --check` already differs on HEAD in other files; the touched files have no fmt diff. `one_in(n)` now uses `is_multiple_of`, which differs from `% n == 0` only for n = 0 (the old form panicked); every caller passes a non-zero n.
