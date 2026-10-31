# Test run — loop 93 (step 11)

Date: 2026-10-31. Tree: 71bb478.

Command: `scripts/loop-tests.sh --only cpp-embedded-arm,rust-embedded,scaffold`. RESULT: 3 passed, 0 failed, 186 s (scaffold 162 s, cpp-embedded-arm 21 s, rust-embedded 3 s).

Also run: the real `docker compose run` of `cpp-embedded` (6 of 6 rows PASS, `cpp-m33f` with the figures of loop 92) and `rust-embedded` (`rust-m4f`, `rust-m33f`, `rust-mutants` PASS); `lib.test.sh`, `run-parts.test.sh`, `checks.test.sh`. Failure runs: `_docs/03_implementation/batch_01_loop93_report.md`.

SUITE: 14 stages specified, 3 executed, 11 not run. Not run locally: go, typescript, csharp, python, rust, java, cpp, swift, ring, ac10, publish-gate (the change touches only the embedded shell, the AN505 script and a README; a plain `scripts/loop-tests.sh` has no stamps on this host and was stopped after about 30 s; its stray containers are listed in the loop record). CI runs them on the close push.

Result: PARTIAL by the documented not-run stages (continue-with-report).
