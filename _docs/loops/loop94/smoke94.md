# Loop 94 smoke - proposed checks

LOCAL_URL: none (no UI, no local deploy script: the change is the embedded test stage)
Branch: dev

## Perform these checks in a terminal at the repo root

- [ ] 1. AC-1/AC-2: `git grep -nE 'cpp-m4f|rust-m4f|target_m4f|thumbv7em|mps2-an386' -- cpp rust scripts .github README.md` prints nothing
- [ ] 2. AC-1/AC-5: `bash cpp/embedded/run.sh host arm` ends `embedded stage arm: 0 target(s) failed` with rows cpp-m0plus, cpp-m3-qemu, cpp-m33f, cpp-s390x, cpp-avr-uno and no cpp-m4f; cpp-m33f shows 315 asserted 315, flash 25760 B, stack 724 B
- [ ] 3. AC-3/AC-5: `bash rust/embedded/run.sh host` ends `rust embedded stage: 0 target(s) failed` with rows rust-m33f and rust-mutants only; the SIZE lines equal limits-m33f.txt (15132/456, 27268/2736, 18764/744, 20404/1728)
- [ ] 4. AC-6: `bash cpp/embedded/lib.test.sh`, `bash cpp/embedded/run-parts.test.sh`, `bash rust/embedded/checks.test.sh` all pass
- [ ] 5. AC-7: `.github/workflows/test.yml` step names say Cortex-M33F and `rustup target add thumbv8m.main-none-eabihf` only
- [ ] 6. Words: the README and `_docs/AGENT_GOTCHAS.md` no longer promise an M4F row

## Notes
No credentials. After the close push, read the `embedded-arm` job of CI (it installs only the M33F Rust target).

## Agent walk
Checks 2, 3, 4 from the loop-tests run and the two stage runs at commit 6f1baf9 (3 passed, 0 failed, 198 s) and the scratch proofs of AC-3 and AC-4 (batch report). Check 1 re-run at the close tree: 0 hits. Checks 5 and 6 read in the diff. CI run itself not yet seen.
