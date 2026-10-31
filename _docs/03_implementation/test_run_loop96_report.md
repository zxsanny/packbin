# Test run loop 96 - AZ-3495

TEST RESULTS: 2 passed, 0 failed, 0 skipped, 0 errors (`scripts/loop-tests.sh --all --only scaffold,ring`: scaffold 182 s, ring 46 s)
SUITE: specified 2 / executed 2 / not-run 0 — PASS

Also run: `bash .github/workflows/ring-frame.sh` (64 pairs x 56 rows, 0 mismatched, 76 refusal rows per language, 30 s), `ring-frame.test.sh` (all passed, 45 checks), `ring-frame-drivers.test.sh` (8 languages, 340 checks, 0 failed), the Go `parts[0]` mutation (red, rows named, restored).

Ring stage time: ring-frame.sh 30 s on HEAD and on the changed tree (NFR: at most +30 s).

Not run here (no package source changed; CI runs them on the close push): go, typescript, csharp, python, rust, java, cpp host suites, swift, `cpp-embedded-arm`, `rust-embedded`, ac10, publish gate. `shellcheck` is not installed (`bash -n` only).
