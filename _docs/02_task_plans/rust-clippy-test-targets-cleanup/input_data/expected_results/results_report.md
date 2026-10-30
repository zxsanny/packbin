# Expected results — loop 87

| Input | Expected |
|-------|----------|
| `cargo clippy --lib --tests --features text,ecc,frame` | 0 warnings (HEAD: 6 distinct sites) |
| `cargo clippy --lib --tests` / `--no-default-features` | 0 warnings |
| `cargo test --features text,ecc,frame` | 876 passed, 0 failed, 1 ignored (HEAD) |
