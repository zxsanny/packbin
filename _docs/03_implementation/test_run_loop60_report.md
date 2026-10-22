# Test run — loop 60 (step 11)

Date: 2026-10-22. Command: `scripts/loop-tests.sh` at 740e7fe (stages planned by the stamps: rust, cpp; the other 12 stages unchanged since their last pass, none of their files touched).

RESULT: 2 passed, 12 skipped as unchanged, 0 failed, 38 s.

| Stage | Result | Seconds |
|-------|--------|---------|
| rust | PASS | 35 |
| cpp | PASS | 38 |
| go | SKIP (unchanged since ac3cc99) | — |
| typescript, csharp, python, java, ac10 | SKIP (unchanged since daa302d) | — |
| swift, scaffold, cpp-embedded-arm, rust-embedded, ring, publish-gate | SKIP (unchanged since 7aa2d8a) | — |

Also run by hand before the commit: `cargo test --features text --test nostd_hostile_tests` (6 passed), `make -C cpp test` on the Mac host and `make test` in `gcc:16` (all tests passed). Host `build/` held ELF objects from a container run (`size: file is not an object file` in `object-check`); `make -C cpp clean` fixed it (the AGENT_GOTCHAS entry on the shared `cpp/build/`).

Broken-copy proofs (scratch copies, real tree restored by `git checkout` / copy back):

| AC | Copy | Result |
|----|------|--------|
| AC-1, AC-2 | one pair flipped to `Ok` | `FAIL: pack: ab then a: got BadValue, want Ok` |
| AC-3 | a pair with a 5-byte key | `FAIL: put_key: the key fits its Text` and `FAIL: pack: a twice: got TooLong, want BadValue` (the pair is not packed) |
| AC-4, AC-5 | `# note abcd` appended | passes, count unchanged |
| AC-5 | `ring_zz position 01` appended | passes, both counts 34 |
| AC-5 | `hostile_zz position ABCD` appended | fails `corpus.txt lists 33 inputs, the loader read 34` |
| AC-5 | `ring_zz Bad-Kind 01` appended | fails `corpus.txt lists 33 inputs, the loader read 34` |
| AC-5 | loader also drops lines starting with a letter | fails `corpus.txt lists 33 inputs, the loader read 0` |

Specified / executed / not run: 14 stages specified, 2 executed, 12 skipped as unchanged; none not-run.

The library source is untouched in this loop (test files only), so Cortex-M4F figures stay as measured in loop 57: flash 8,032 of 8,192 B (pin 8,032 B, margin 160 B), deepest stack 504 of 512 B. The arm stage was skipped as unchanged, not re-measured.
