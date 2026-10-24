# Acceptance criteria — publish gate under load (loop 66)

## Go proxy window (`publish-go.test.sh` AC-3)

- **AC-1**: with the `go` stub delayed by 5 s per call, `bash .github/workflows/publish-go.test.sh` exits 0 and the "never" case records at least 2 proxy asks (observed count printed).
- **AC-2**: on a copy of `publish-go.sh` whose `proxy_check` breaks after one try, the same test exits non-zero naming "asked once only" (broken copy run, output pasted into the batch report).
- **AC-3**: with no delay, the whole `publish-go.test.sh` run takes at most 60 s (28 s measured for `--groups go` in loop 65).

## Container pip install (`publish-phases-failures.test.sh` AZ-2096 AC-4)

- **AC-4**: when the pip install of `build` fails (a stub `pip` that exits 1 and prints a line), the build log of that run contains that line, at most 3 lines after `build failed: python`; checked by a test that fails on the current tree and passes after the change.
- **AC-5**: `publish-gate.test.sh --groups phases` exits 0 on a quiet host, at most 400 s (325 s in loop 65).
- **AC-6**: a retry of the pip install is added only if AC-4's kept error from a real failure names a network or index error; otherwise AC-6 is "no change to `publish-inside.sh` beyond the log line", signed by the owner in the batch report.

## Gate

- **AC-7**: after the change, the full `scripts/loop-tests.sh` publish gate is run once; its `publish-go` and `publish-phases-failures` results are read from the share logs and reported as PASS / FAIL with the host load at the time. A pass here is evidence, not proof (the failure needed load 9 to 22).
