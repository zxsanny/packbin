# Acceptance criteria — publish gate under load (loop 66)

## Go proxy window (`publish-go.test.sh` AC-3)

- **AC-1**: with the `go` stub delayed by 5 s per call, `bash .github/workflows/publish-go.test.sh` exits 0 and the "never" case records at least 2 proxy asks (observed count printed).
- **AC-2**: on a copy of `publish-go.sh` whose `proxy_check` breaks after one try, the same test exits non-zero naming "asked once only" (broken copy run, output pasted into the batch report).
- **AC-3**: with no delay, the whole `publish-go.test.sh` run takes at most 60 s (28 s measured for `--groups go` in loop 65).

## Container pip install (`publish-phases-failures.test.sh` AZ-2096 AC-4)

- **AC-4**: a failure message of the publish-phases tests that quotes a run's output shows its last 25 lines, so a `pip` error that comes before `build failed: python` (the container install of `build`, `publish-inside.sh:75`) is in the gate log. The two messages that quote 3 lines today are `publish-phases-failures.test.sh` lines 180 and 190. A test feeds the helper a 40-line file with `ERROR: stub pip failed` on line 30 and finds the line in its output; the test fails on the current tree (no helper). The host venv install in `publish-phases.test.sh` line 106 already writes its error to the share log (stderr, `set -e`) and is not changed.
- **AC-5**: `publish-gate.test.sh --groups phases` exits 0 on a quiet host, at most 400 s (325 s in loop 65).
- **AC-6**: a retry of the pip install is added only if AC-4's kept error from a real failure names a network or index error; otherwise AC-6 is "no change to `publish-inside.sh` beyond the log line", signed by the owner in the batch report.

## Gate

- **AC-7**: after the change, the full `scripts/loop-tests.sh` publish gate is run once; its `publish-go` and `publish-phases-failures` results are read from the share logs and reported as PASS / FAIL with the host load at the time. A pass here is evidence, not proof (the failure needed load 9 to 22).
