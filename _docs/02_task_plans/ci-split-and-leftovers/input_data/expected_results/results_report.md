# Loop 28 expected results (input to output)

| # | Input (command or action) | Expected output |
|---|---------------------------|-----------------|
| 1 | `bash .github/workflows/publish-gate.test.sh` (Mac or CI) | 14 lines `publish-gate: <check> took N s`, a total line, then the last line `publish gate tests passed` (or `publish gate: no failures, NOT RUN: ...`); exit 0 |
| 2 | `bash .github/workflows/ring-wiring.test.sh` on the new `test.yml` | exit 0; the same run against a copy of `test.yml` with a suite removed from the `suites` job exits non-zero and names the missing suite |
| 3 | `scripts/loop-tests.sh --all --only cpp,scaffold --jobs 3` | `cpp` and `scaffold` both PASS, no "re-run alone" line; exit 0 (3 runs in a row) |
| 4 | `bash scripts/loop-tests.test.sh` with the shared build path put back in a stage | exit non-zero, names the two stages and the path |
| 5 | CI run of the pushed commit | jobs `scaffold`, `suites`, `publish-gate`, `embedded`, `ring` all `success`; end to end at most 25 minutes |
| 6 | Swift unpack of the F10 packet and the wide round, measured with `/usr/bin/time -l` | one maximum resident set size per case in MB, recorded with the command |
| 7 | README Swift section and ADR-005 | each carries the S3 limit sentence; a grep for `swift:5.9` finds nothing |
