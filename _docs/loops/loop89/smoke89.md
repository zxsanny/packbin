# Loop 89 smoke — proposed checks

LOCAL_URL: none (CI tooling; no app, no browser surface)
Branch: dev

## Perform these checks in a terminal at the repository root

- [ ] 1. `docker compose -f docker-compose.test.yml run --rm rust` ends with exit 0; its log shows `rust_clippy_component` and nine `rust_test_build` steps (`none`, `alloc`, `text`, `ecc`, `text,ecc`, `frame`, `text,ecc,frame`, `default`, `all`) and `run-suite: rust total took ... in 22 steps` (AC-1).
- [ ] 2. `bash .github/workflows/run-suite.test.sh </dev/null` prints `run-suite.test.sh: all checks passed` (AC-2, AC-3, AC-5).
- [ ] 3. Add `pub fn probe(x: u32) -> bool { x % 2 == 0 }` to the end of `rust/src/lib.rs`, run check 1 again: it ends with exit 1 and shows `rust test build of feature set none printed a warning` with the `manual_is_multiple_of` line; then `git checkout -- rust/src/lib.rs` (AC-2).
- [ ] 4. `git diff f21b4d7..HEAD --stat -- rust fixtures` prints nothing, and `git diff f21b4d7..HEAD | grep "allow(clippy"` prints nothing (AC-6).
- [ ] 5. `wc -l .github/workflows/run-suite.sh .github/workflows/run-suite.test.sh .github/workflows/run-suite-rust-clippy.test.sh` shows no file over 500 lines (AC-7).

## Not checkable before the push

- AC-4: the Rust CI job time after the push against the previous green run (at most 120 s more).

## Notes

No credentials. The tree must be clean for check 4.

## Agent walk

No browser. The agent ran checks 1, 2, 3 and 5 itself during Implement (container run exit 0 with 22 steps, 1,788 passed; shell test all checks passed; injected lint run exit 1 naming set `none`; line counts 476 / 472 / 19) and check 4 reads `git status rust` clean. This is evidence for the user, not the gate.

## Result

PASS (owner, 2026-10-30). The owner asked the agent to run all five checks; the agent ran them fresh on the committed code and the owner then answered PASS. Check 1: exit 0, 9 `rust_test_build` steps, 22 steps, 70 s. Check 2: all checks passed. Check 3: exit 1 naming set `none` and the `manual_is_multiple_of` line (file restored). Check 4: no change under `rust` or `fixtures`; `allow(clippy` appears only in `_docs` sentences stating the rule (0 in code paths). Check 5: 472 / 476 / 19 lines.
