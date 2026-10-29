# Scenarios — loop 82 (ruby-to-python-ci-scripts)

Fit: one component, the CI shell scripts under `.github/workflows/`, `test.yml` and `tool-pins.txt`. Today they read YAML through `ruby -ryaml` in 9 scripts and JSON through `ruby -rjson` in 2; after, a Python helper reads both. Dependents of today: the `scaffold`, `publish-gate-*` and `ring` jobs of `test.yml`, `publish.yml` (job `precheck` runs `publish-precheck.sh`), `scripts/loop-tests.sh`, and any maintainer who runs the scripts by hand. No collision that needs a decision: the one open design point (how CI installs PyYAML) has one recommended answer, recorded in the feature description.

| # | Actor / trigger / state | Proposed behavior | Status | AC |
|---|---|---|---|---|
| 1 | Maintainer, first use on a host with `python3` and PyYAML, no `ruby` | All 10 scripts pass | confirmed | AC-R2 |
| 2 | Maintainer, host with `python3` and no PyYAML | Each YAML script exits non-zero with `PyYAML is required to parse the workflow YAML`; the precheck is unaffected | confirmed | AC-Y5, AC-P2 |
| 3 | CI job that runs a ported script | Installs the pinned PyYAML from `tool-pins.txt` first; the pin test fails when a job lacks the step | confirmed | AC-Y3 |
| 4 | Workflow edited so that a guarded rule breaks (mutation) | The script exits non-zero and names the check | confirmed | AC-K2 |
| 5 | Release path: runs API answers with non-JSON, no `workflow_runs`, or a curl failure | `green=false`, exit 0, reason printed; the publish workflow then runs the full test workflow | confirmed | AC-P1 |
| 6 | An `if:` expression with a quote, semicolon, backtick or `$(` | Refused before any evaluation | confirmed | AC-E2 |
| 7 | Workflow whose `on:` loads as the key `True` (and one with the quoted key) | Triggers read in both forms | confirmed | AC-Y2 |
| 8 | Helper crashes, file missing, YAML malformed (partial failure) inside a `$(...)` capture under `set -e` | The script fails with the cause; no empty value passes a check | confirmed | AC-Y5 |
| 9 | CI runner that has Ruby and Python both | Python is used; Ruby is not referenced | confirmed | AC-R1 |
| 10 | Two scripts run at once by `scripts/loop-tests.sh` | The helper keeps no state and writes no file; no clash | confirmed | AC-Y1 |
| 11 | YAML with anchors, merge keys or the YAML 1.1 words `yes`/`no`/`on` as values | Read as `safe_load` reads them, as Ruby's `safe_load` did; a case in the helper's test | confirmed | AC-Y1, AC-Y2 |
| 12 | PyYAML pin bumped later | One edit in `tool-pins.txt`; the pin test and a green `test.yml` are the check | confirmed | AC-Y3 |

## Task AC map (decompose, 2026-10-29)

| # | Owning task AC |
|---|---|
| 1 | AZ-3381 AC-5, AZ-3382 AC-1, AZ-3383 AC-1, AZ-3384 AC-3, AZ-3385 AC-3, AZ-3386 AC-4 (each script, no Ruby) |
| 2 | AZ-3381 AC-3, AZ-3382 AC-5 |
| 3 | AZ-3381 AC-4, AZ-3386 AC-3 |
| 4 | AZ-3382 AC-6, AZ-3383 AC-5, AZ-3384 AC-2, AZ-3385 AC-2, AZ-3386 AC-2 and AC-4 |
| 5 | AZ-3382 AC-2 |
| 6 | AZ-3383 AC-4 |
| 7 | AZ-3381 AC-2 |
| 8 | AZ-3381 AC-3 |
| 9 | AZ-3386 AC-1 |
| 10 | AZ-3381 AC-1 |
| 11 | AZ-3381 AC-2 |
| 12 | AZ-3381 AC-4 |
