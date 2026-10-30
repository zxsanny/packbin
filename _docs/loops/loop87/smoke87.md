# Loop 87 smoke — proposed checks

LOCAL_URL: none (Rust library; no local deploy script)
Branch: dev

## Perform these checks in `rust/`

- [ ] `cargo clippy --lib --tests --features text,ecc,frame` ends with 0 warnings (AC-1)
- [ ] `cargo clippy --lib --tests` and `cargo clippy --lib --tests --no-default-features` end with 0 warnings (AC-1)
- [ ] `cargo test --features text,ecc,frame` reports 876 passed, 0 failed, 1 ignored (AC-2)
- [ ] `git show --stat HEAD` lists 6 files under `rust/` and no `allow(clippy` was added (AC-3)

## Agent walk

No browser surface. Agent runs of the first three checks on the edited tree: 0 warnings in all three sets; 876 passed, 0 failed, 1 ignored.
