# Scenarios — rust-clippy-ci-gate

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | CI runs the Rust suite on HEAD, where every set is clean | confirmed | the suite is green and clippy ran on 9 of 9 sets | AC-1 | intake |
| S2 | A contributor adds a lint-triggering line to a test file or the lib | confirmed | the suite fails in the set that builds the file, names the set and quotes the warning line | AC-2 | intake |
| S3 | A contributor adds a plain compiler warning (as AZ-3357 catches today) | confirmed | the suite still fails the same way, naming the set | AC-2 | intake |
| S4 | The container cannot get the clippy component (network down, component missing for the toolchain) | confirmed | the suite fails with a message naming clippy; it never counts the check as passed | AC-3 | intake |
| S5 | Clippy fails on one set in the middle of the nine | confirmed | the later sets do not run and the report row names the failing set, as for a failed test build today | AC-2 | intake |
| S6 | The same suite runs on the owner's Mac through the compose service | confirmed | same result as CI: green on HEAD, same failure messages | AC-1 | intake |
| S7 | The Rust toolchain image is bumped and the new version adds lints | deferred (flagged concern, bump change fixes or justifies each lint, owner) | not handled by this task | — | intake |
| S8 | The no-std probe crate under `rust/embedded` has a clippy warning | out-of-scope | not linted by this gate | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | The test script of the suite is 470 lines and its soft cap is 500 | A — the new cases go in a script of their own | yes |

## Not walked

- clippy pedantic or nursery lint groups; linting `--all-targets` (no examples or benches exist in the crate)
