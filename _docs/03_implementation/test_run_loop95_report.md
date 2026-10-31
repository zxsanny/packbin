# Test run loop 95 - AZ-3483

TEST RESULTS: 2 passed, 0 failed, 0 skipped, 0 errors (`scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded`, 20 s)
SUITE: specified 2 / executed 2 / not-run 0 — PASS

Also run: `lib.test.sh`, `run-parts.test.sh`, `rust/embedded/checks.test.sh` (all pass); `make object-check` in `gcc:16` (host objects clean after the `check-objects.sh` edit); three seeded-defect scratch runs (batch report).

Not run here (no source they build changed; CI runs them on the close push): go, typescript, csharp, python, rust, java, cpp host suites, swift, ring, ac10, publish gate, scaffold. `shellcheck` is not installed (`bash -n` only).
