# Expected results — loop 86

| Input | Expected |
|-------|----------|
| `cargo clippy --lib --features text,ecc,frame` | 0 warnings (HEAD: 11) |
| `cargo clippy --lib` / `--no-default-features` | 0 warnings (HEAD: 0 for the second) |
| `cargo test --features text,ecc,frame` | HEAD pass count, 0 failed |
| `scripts/loop-tests.sh --all --only ring` | PASS, 64 pairs, 0 mismatched |
