# Feature assessment — loop 82

loop: 82
feature: ruby-to-python-ci-scripts
rounds: 1
verdict: COMPLETE
report_of_round: 1

## Round 1

**Date**: 2026-10-29
**Implement pass**: batches 01 and 02 (`_docs/03_implementation/batch_01_loop82_report.md`, `batch_02_loop82_report.md`; commits e8c025e and 0da2bc6, and the uncommitted test additions below); no `implementation_report_*` or completeness report: CI-script work, as in loops 78 to 81
**Verdict**: COMPLETE — 17 covered / 3 out-of-scope / 0 gap-clear / 0 gap-unclear

### Coverage matrix

| id | scenario | status | evidence | source |
|----|----------|--------|----------|--------|
| S1 | host with `python3` and PyYAML, no Ruby: all 10 scripts pass | covered | AZ-3381 AC-5, AZ-3382 AC-1, AZ-3383 AC-1, AZ-3384 AC-3, AZ-3385 AC-3, AZ-3386 AC-4; `loop-tests.sh --only scaffold --all` PASS (160 s) and `publish-gate.test.sh --groups workflow,pins,static` PASS (52 s) on this host without Ruby; the ported checkers | scenarios.md 1 |
| S2 | host with `python3`, no PyYAML | covered | AZ-3381 AC-3, AZ-3382 AC-5; `yaml_get.test.sh` (no module: exit 2, `PyYAML is required to parse the workflow YAML`); `publish-precheck.test.sh` (script names no YAML reader); `scripts/ci/yaml_get.py`, `publish-precheck.sh` | scenarios.md 2 |
| S3 | CI job installs the pin; the pin test fails without it | covered | AZ-3381 AC-4, AZ-3386 AC-3; `publish-pins.test.sh` `pins_python_checks` (real `test.yml` ok, copy without the step refused naming the job); `test.yml` steps `setup-python` + `PyYAML` in `scaffold` and `publish-gate-rest`; the install line run in a fresh venv | scenarios.md 3 |
| S4 | a guarded rule is broken: non-zero exit naming the check | covered | AZ-3382 AC-6 (11 mutants), AZ-3383 AC-5 (43 rejects), AZ-3384 AC-2 (38 + 53 rejects), AZ-3385 AC-2 (115 rejects), AZ-3386 AC-2 and AC-4; the five checkers | scenarios.md 4 |
| S5 | precheck: non-JSON, no `workflow_runs`, curl failure | covered | AZ-3382 AC-2; `publish-precheck.test.sh` scenarios `curl fails`, `not json`, `no workflow_runs`; `publish-precheck.sh` lookup | scenarios.md 5 |
| S6 | `if:` with a quote, semicolon, backtick or `$(` | covered | AZ-3383 AC-4; `publish-workflow.test.sh` 12 new refusal checks; `publish-workflow-structure.py` `tokenize` (closed token set; no `eval`/`exec`/`compile`) | scenarios.md 6 |
| S7 | `on:` as `True` and as quoted `"on"` | covered | AZ-3381 AC-2; `yaml_get.test.sh` (both forms read `['push','pull_request']`, 2 of 2); `yaml_get.triggers`, used by the three workflow checkers | scenarios.md 7 |
| S8 | helper failure inside `$(...)` under `set -e` | covered | AZ-3381 AC-3; `yaml_get.test.sh` (no file, malformed); `run-suite.test.sh` with `RUN_SUITE_COMPOSE=/nonexistent` (prints the cause, fails); `expect_rejected` accepts only exit 1 | scenarios.md 8 |
| S9 | runner with both Ruby and Python | covered | AZ-3386 AC-1; `pins_old_reader_mentions` scan (0 matches in `.github`, `scripts`); no `ruby` in any CI script | scenarios.md 9 |
| S10 | scripts run in parallel by `loop-tests.sh` | covered | AZ-3381 AC-1; `yaml_get.py` keeps no state and writes no file (bytecode caches are git-ignored); the scaffold stage ran its commands in parallel | scenarios.md 10 |
| S11 | anchors, merge keys, `yes`/`no` words | covered | AZ-3381 AC-2; `yaml_get.test.sh` `words.yml` case | scenarios.md 11 |
| S12 | pin bump later | covered | AZ-3381 AC-4, AZ-3386 AC-3; one line in `tool-pins.txt` read by `tool-pin.sh`; `pins_file_errors` counts `pyyaml` once | scenarios.md 12 |
| D1 | the `if:` parser refuses more than the old `eval` (lone `&`, `|`, `=`, `===`, `()`, chained `==`, adjacent strings) | covered | AZ-3383 AC-3; the 12 refusal checks; stricter, never looser; no real workflow uses them | batch_02 discoveries 1 |
| D2 | `needs.x.result` inside a quoted string stays literal | covered | AZ-3383 AC-2; `publish-workflow-structure.py` `tokenize` | batch_02 discoveries 2 |
| D3 | `pyyaml` in `tool-pins.txt` and the pins test refusing unknown tools | covered | AZ-3381 AC-4; `publish-pins.test.sh` `PINS_NAMES` includes `pyyaml`; `pins_file_checks` | batch_01 discoveries 1 |
| D4 | a change under `scripts/ci/` selects the `publish-gate` stage | covered | AZ-3381 AC-1; `scripts/loop-tests.test.sh` case 9c (fails without the `scripts/ci/*` path); `scripts/loop-tests.sh` `covers` | batch_01 discoveries 2 |
| D5 | one reader across the tree | covered | AZ-3381 AC-1; `yaml_get.test.sh` scan (a stray `import yaml` is refused); only `publish-jobs-mutate.py` imports `yaml`, to dump | audit in this assessment |
| D6 | literal Python `3.14` in two steps beside `RING_PYTHON` | out-of-scope | `problem.md` flagged concern: "Python 3.14 here against `setup-python` in CI (the version differs) \| the helper uses only features of the CI version; CI is the check \| open \| Low" | batch_01 discoveries 4 |
| D7 | about 50 lines of helpers duplicated in the two ring-wiring checkers | out-of-scope | `AZ-3384` task constraint: files at or under 500 lines, no shared module beyond the reader; a refactor, not a usage angle | batch_02 discoveries 7 |
| D8 | CI of the push shows the six formerly unrun scripts PASS (AC-C1) | out-of-scope | `AZ-3386` AC-6 and `problem.md` flagged concern "CI is the first run of the six scripts": a close-step check, read from the CI log after the push, recorded in the loop record | acceptance_criteria.md AC-C1 |

### Gaps that need a decision (gap-unclear)

None.

### Gaps that are clear (gap-clear)

None. Three AC checks that had no test at the end of batch 02 were found by this pass and fixed before the verdict (they are shortfalls of the implementation, not of the specs): AZ-3381 AC-1 (the tree scan in `yaml_get.test.sh`), AZ-3382 AC-5 (the precheck names no YAML reader, in `publish-precheck.test.sh`), AZ-3386 AC-5 (`pyyaml` in the pins section of `ci_cd_pipeline.md`, in `publish-pins.test.sh`); each was shown to fail on a deliberate break.

### Not walked

- A host with Ruby only and no Python 3: the scripts no longer run there; `python3` is on every dev host and runner of the project (Linux, the owner's Mac, `ubuntu-latest`), so not walked.
- `python3` older than 3.8 on a hand-run host: the code uses f-strings and `pathlib` only; CI and this host run 3.14.

### Harness gaps

- none (both batch reports have the `## Discovered during implementation` table)
- Step 2 re-walk: new persisted artifact: `__pycache__` next to the checkers and the reader (git-ignored by `**/__pycache__/`); new failure mode: a host without PyYAML (named message, exit 2); new caller: `publish-pins-install.py` reads every script to find the jobs that read the YAML (comments are ignored). No new configuration key.
