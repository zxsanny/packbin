# Loop 86 smoke — proposed checks

LOCAL_URL: none (library; no local deploy script, no UI)
Branch: dev

## Perform these checks in a shell at the repo root

- [ ] AC-1: `cd rust && cargo clippy --lib --features text,ecc,frame` ends with no `warning:` line (HEAD had 11); same for `cargo clippy --lib` and `cargo clippy --lib --no-default-features`
- [ ] AC-2: `cd rust && cargo test --features text,ecc,frame` ends `ok` in every suite (agent run: 876 passed, 0 failed, same as HEAD)
- [ ] AC-2: `scripts/loop-tests.sh --all --only ring` prints `STAGE ring: PASS` (JDK on PATH, `LOOP_TESTS_PYTHON=/usr/bin/python3.14`)
- [ ] AC-3: `git show babcee8 --stat` shows 6 files under `rust/src`; `git show babcee8 | grep "allow(clippy"` shows only `duplicate_mod`
- [ ] Regression spot-check: `git diff 02ffcef..babcee8 -- rust/src/walk/text/encode.rs` shows only the `size > raw.len()` and two `is_none_or` edits

## Notes
No credentials involved.
