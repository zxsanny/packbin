# Loop 28 acceptance criteria (CI speed and leftovers)

Measured on the pushed commit's `test.yml` run on `ubuntu-latest` unless a row says Mac or "docs".

## CI split and timings

- **SP-1** `test.yml` jobs `suites` (8 languages), `publish-gate`, `scaffold` (static checks), `embedded`, `ring` conclude `success`, 5 of 5, on the pushed `dev` commit, and `publish.yml` still gates on them (`needs: test` unchanged).
- **SP-2** End-to-end `test.yml` time on `dev` is at most 25 minutes in 2 of 2 runs (baseline 33 to 38 minutes), each job within its `timeout-minutes`, and the `publish gate` step at most 1 500 s.
- **SP-3** No check is removed: every command of the old `scaffold` job runs in exactly one new job (count of `run:` commands before and after is equal), and the 8 `docker compose ... run --rm <lang>` suites are all present (8 of 8).
- **SP-4** Each guard that read the `scaffold` job (`publish-gate.test.sh`, `ring-wiring.test.sh`, `run-suite-swift.test.sh`, `report-row.test.sh` where it applies) follows the new job layout and rejects 100 % of its mutants (a copy of `test.yml` with a step dropped, moved to a job with `if:` or `continue-on-error`, or a suite removed from the list is refused, one mutant per rule).
- **SP-5** `publish-gate.test.sh` prints one line `publish-gate: <check> took N s` for each of its check groups (static, crates-token, registry, vcpkg, gate, go, swift, manifest, npm, position, workflow, pins, phases, readonly: 14 lines, no group untimed) and a total, with 0 assertions removed or changed (the failure count and the mutant counts of every group are equal before and after).

## cpp race

- **CR-1** The command and the path that collide with the `cpp` stage are named in the status report with the log lines of the reproduction (0 "likely").
- **CR-2** After the fix, 3 of 3 pool runs of `scripts/loop-tests.sh --all --only cpp,scaffold --jobs 3` on the Mac pass with 0 serial retries, and `scripts/loop-tests.test.sh` holds a check that the `cpp` stage does not write `cpp/build` from the host and fails when the old command is put back (1 mutant rejected). Amended 2026-10-15 after the reproduction: the cause is the stage's own host-side clean followed at once by the container start, not a second pool stage.

## Documentation

- **DO-1** ADR-005 and the README (the language table line and the Swift section) each state the S3 limit: Swift 6.0 consumer and Xcode 16.0 unproven, the swift-asn1 1.7.3 tools-6.1 reason, and the two toolchains that are built (`swift:6.3.3`, `swift:6.4.1`); 3 of 3 places, and 0 places that claim a 6.0 or Xcode 16.0 build as tested.
- **DO-2** Every environment named in the README Swift text (Linux, CI image, platform minimums) maps to a run recorded in the status report or is marked "not built or tested": 0 unsupported claims, 0 mentions of `swift:5.9`.

## Peak memory

- **PM-1** The peak resident memory of the Swift unpack of the F10 max-slots packet and of the default-limit wide round is measured on the Mac (and in the `swift:6.3.3` container if it runs in 30 minutes), as MB per case with the command, and recorded beside the Go figures (625 MB and 94 MB) in `_docs/05_security/` or the status report; 2 of 2 figures recorded. A figure above 1 000 MB is opened as a finding, not fixed here.

## Inherited

- The golden hex `4001000065cd1d00a3e1110100` gate and the 75 % / 90 % coverage floors (`quality-thresholds.md`); no production code changes are planned, so no coverage delta.
- No tag, no registry upload (0 tags, 0 uploads); a push of `dev` only with the owner's go.
