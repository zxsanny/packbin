# Test Run — loop 11

**Date**: 2026-10-05
**Commit under test**: 39d3a88 (code unchanged since; later commits touch `_docs/` only)
**Mode**: functional, Docker (`docker-compose.test.yml`, the same jobs `.github/workflows/test.yml` runs) plus the two scaffold checks

```
TEST RESULTS: 454 passed, 0 failed, 0 skipped, 0 errors (python 78, typescript 80, csharp 136, rust 88; java and cpp print per-runner "all tests passed")
SUITE: specified 6 / executed 6 / not-run 0
```

Runner manifest fallback: `traceability-matrix.md` rows are mapped to tests inside these six suites (153 of 155 rows Covered, 2 WAIVED: R-11, R-12, unchanged this loop). The runners do not report matrix rows individually, so the suite count is the manifest of six.

## Verdict: PASS

| Suite | Result | Detail |
|-------|--------|--------|
| csharp | PASS | 136 passed |
| typescript | PASS | 80 passed |
| python | PASS | 78 passed |
| rust | PASS | 68 lib + 6 + 10 + 4 = 88 passed |
| cpp | PASS | untouched this loop, all tests passed |
| java | PASS | PackbinTest, SchemeTest, FieldIdBindingTest, SessionTest all passed (44 methods + 10 shared vectors) |
| `fixtures/hostile/cases.test.sh` | PASS | |
| `.github/workflows/report-row.test.sh` | PASS | |

`test-results/report.csv` shows PASS for all six suites.

## Reality gate

- Every hostile case in `fixtures/hostile/cases.txt` of stage `unpack` is replayed against the real packer in python, typescript, csharp, java and rust, each with a time guard (1 s). No internal module is stubbed.
- Python and TypeScript also run the session path for the zero-progress packet. Session coverage for the zero-width element packets in all five packages, and for C#/Java/Rust zero-progress, is open as AZ-2114 (extended) — a test gap, not a failure.
- Race tests (C#, Java) run two threads x 200 000 unpacks on one shared scheme.

## CI parity

CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {csharp,typescript,python,rust,cpp,java}`, `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`. CI has no separate compile or typecheck job.

## Not run

Nothing. The C++ embedded job (Cortex-M QEMU, big-endian, ESP-IDF via `cpp/embedded/run.sh`) is a separate CI job on `ubuntu-latest`; C++ source is untouched in this loop.
