# Expected results — loop 89

| Input | Expected |
|-------|----------|
| `run-suite.sh rust` on HEAD in `rust:1.98` | green; clippy ran on 9 of 9 feature sets, 0 warnings each |
| `run-suite.sh rust` with `x % 2 == 0` on a `u32` added to a test file | fails; output names the set and the `manual_is_multiple_of` line |
| `run-suite.sh rust` with `cargo clippy` unavailable | fails; message names clippy |
| `cargo clippy --lib --tests` on HEAD, Rust 1.97.1 and 1.99.1, 9 sets | exit 0, 0 warnings (probed 2026-10-30) |
| Rust job wall time, first CI run after the push | previous green run + at most 120 s |
