# Batch Report

**Batch**: 1
**Tasks**: AZ-3381_ci_yaml_reader_and_pin, AZ-3382_publish_precheck_python
**Date**: 2026-10-29

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3381_ci_yaml_reader_and_pin | Done | 9 files (reader, its test, `tool-pins.txt`, `test.yml`, 3 one-liner scripts, `publish-pins.test.sh` PINS_NAMES, `loop-tests.sh` and its test) | `yaml_get.test.sh` all checks passed; `report-row.test.sh` passed; `run-suite.test.sh` all checks passed (includes the swift file); `loop-tests.test.sh` all checks passed | None |
| AZ-3382_publish_precheck_python | Done (worker, checked by the parent) | 2 files | `publish-precheck.test.sh`: all scenarios ok, 11 of 11 mutants rejected | None |

## Code Review Verdict: not run

No per-batch code review (owner preference, as in loop 81); the parent read the precheck diff line by line.

## Test Suite

- Non-vacuity, AZ-3381: reader with the quoted-`on` branch removed fails `yaml_get.test.sh`; `test.yml` matrix with `go` renamed fails `report-row.test.sh`; a swift part renamed fails `run-suite.test.sh` (swift file); a suite service without `GITHUB_ACTIONS` fails `run-suite.test.sh`; a missing compose file prints `cannot read` and fails; `loop-tests.sh` without `scripts/ci/*` fails case 9c.
- Non-vacuity, AZ-3382 (worker): two extra mutations of the real script fail the test; reverted, script byte-identical.
- The PyYAML install line was run in a fresh venv: `pyyaml 6.0.3` installed wheels-only.
- CI-parity: PARTIAL. `bash scripts/loop-tests.sh --only scaffold --all` (214 s) failed only on `ring-wiring.test.sh`: `ruby is required to parse the workflow YAML` (not ported yet, AZ-3384). Every other scaffold command passed. The Ruby-based checks of `test.yml` cannot run on this host; the change to `test.yml` (two setup-python and PyYAML steps, one scaffold step) was read against their rules (no `if`, no `needs`, no `continue-on-error`, SHA-pinned `uses` with a tag comment).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | `tool-pins.txt` gets a `pyyaml` line, and `publish-pins.test.sh` (`PINS_NAMES`) refused any tool it did not list | AZ-3381 AC-4 | `pyyaml` added to `PINS_NAMES`; the rest of that script is AZ-3386 | clear (the pins file check says "nothing else") |
| 2 | `loop-tests.sh` did not select the `publish-gate` stage for a change under `scripts/ci/` | AZ-3381 AC-1 | `scripts/ci/*` added to the stage's paths, with case 9c in its test | clear |
| 3 | `_docs/04_deploy/ci_cd_pipeline.md` has a pins section and `_docs/02_document` two Ruby lines | AZ-3386 AC-5 | search all of `_docs` (not only `02_document`) for Ruby in AZ-3386; add `pyyaml` to the pins section | clear |
| 4 | The install step uses a literal Python `3.14`; the ring takes its version from `RING_PYTHON` | AZ-3381 AC-4 | kept literal, two jobs; a third place for the number | unclear (a later loop may fold it into one env) |
| 5 | A step `run:` holding `--only-binary=:all: ` unquoted is invalid YAML | AZ-3381 | quoted with single quotes | clear |
| 6 | In the unreadable-file path the old one-liner printed no cause; the new one names it | AZ-3381 AC-3 | kept | clear |

## Commit

`[AZ-3381] [AZ-3382] Python reader for the CI YAML, precheck in Python`. Body: one line + `Loop: 82`.

## Next Batch: AZ-3383, AZ-3384, AZ-3385 (parallel, disjoint files), then AZ-3386
