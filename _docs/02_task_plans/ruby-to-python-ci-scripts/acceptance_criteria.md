# Acceptance criteria — loop 82 (ruby-to-python-ci-scripts)

Inherited project criteria that must keep their meaning: AC-11 (CI runs the tests on every push and pull request; a failing test fails the check), AC-12 (a tag whose languages match publishes one package per language), AC-14 (a tag that fails the golden-byte check publishes 0 packages), AC-15 (a language missing from the tagged tree publishes 0 packages). The publish workflow's gate is the thing most of these scripts check, so a port that weakens a check weakens AC-12, AC-14 and AC-15. Baseline for "HEAD" below is commit 5a78fb8.

## R: no Ruby

**AC-R1: Ruby is gone from the scripts**
Given the tree after this loop
When `.github/workflows/*.sh`, `.github/workflows/*.yml` and `.github/workflows/tool-pins.txt` are searched for the word `ruby` (case-insensitive)
Then there are 0 matches (HEAD: 10 scripts and `test.yml`).

**AC-R2: The ten scripts run without Ruby**
Given a host whose `PATH` has no `ruby` and no `java` (this Linux host) and where `python3` and the pinned PyYAML are present
When each of the 10 ported scripts (`publish-jobs`, `publish-workflow`, `ring-wiring`, `ring-wiring-swift`, `publish-pins`, `publish-precheck`, `report-row`, `run-suite`, `run-suite-swift` tests, and `publish-precheck.sh` itself through its test) is run
Then 10 of 10 exit 0, and none prints `ruby is required`, `ruby: command not found` or `NOT RUN` for a check that Ruby carried.

## K: no check dropped

**AC-K1: Same checks, counted**
Given the checks of each script at HEAD, listed by label (every `ok` / `fail` / `mutant` call and every scenario row)
When the ported script is run
Then it runs every labelled check of HEAD (0 dropped); a label may be renamed only with a line in the task's report; a new check may be added.

**AC-K2: Each script still fails on a mutation**
Given a deliberate change to the thing each script guards (one per script: a job renamed in `test.yml`, an `if:` condition flipped, a pin loosened, a ring wiring edge removed, the precheck's `head_sha` comparison dropped, a matrix language removed, and so on)
When the ported script is run on the changed copy
Then 10 of 10 scripts exit non-zero and name the failed check; the mutants the scripts already hold (HEAD: 111 `mutant` calls in `publish-jobs.test.sh`, 11 in `publish-precheck.test.sh`, and those of the other scripts) are 0 lost and each still fails.

## P: the release path

**AC-P1: Precheck verdicts are unchanged**
Given the 10 named run scenarios, the 3 failure scenarios (curl fails, answer not JSON, answer without `workflow_runs`), the 5 request parts, the 3 bad commits and the bad repository of `publish-precheck.test.sh`
When the ported `publish-precheck.sh` runs on each
Then every scenario gives the same `green=` line and exit code as at HEAD (`green=true` for exactly 2 of the 10 run scenarios: a green push run, and a path with a ref suffix; exit 2 for the 4 bad inputs), and the token is printed 0 times.

**AC-P2: Precheck needs no YAML**
Given `publish-precheck.sh`
When it runs
Then it reads the runs answer with Python's standard library only (no PyYAML import) and does not fail on a host where PyYAML is absent.

## E: the `if:` evaluator

**AC-E1: Same refusals**
Given the `if:` expressions of `publish.yml` and `test.yml` and the refusal cases of `publish-workflow.test.sh` (an unsupported term, an expression that does not evaluate)
When the ported evaluator reads them
Then it gives the same value for every expression that HEAD evaluates and refuses the same cases with a message; 0 cases that HEAD refuses are accepted.

**AC-E2: Workflow text is never run as code**
Given an `if:` expression with a character outside the filter (a quote, a semicolon, a backtick, `$(`)
When the ported evaluator reads it
Then it refuses it before any evaluation; the ported script contains 0 calls to `eval` or `exec` on workflow text.

## Y: YAML reading and the pin

**AC-Y1: One reader**
Given the ported scripts
When the YAML loading code is searched
Then it exists in 1 file (the shared helper), and the other scripts call it; the helper is run with `python3 -I`, and it calls `yaml.safe_load` only (0 calls to `yaml.load`).

**AC-Y2: `on:` is read**
Given a workflow whose `on:` key PyYAML loads as the boolean key `True`
When the helper and a script read the triggers
Then they read them from either `on` or `True`; a test with a workflow that has the key under each form gives the same triggers (2 of 2).

**AC-Y3: PyYAML is pinned and installed**
Given `tool-pins.txt` and `test.yml`
When the pins and the jobs that run a ported script are read
Then `tool-pins.txt` holds exactly 1 `pyyaml==X.Y.Z` line, and every job that runs a ported script installs that version from the pins file (jobs with the install = jobs that run a ported script, 100%); the pin test fails when the install step of one such job is removed.

**AC-Y5: A helper failure is a failure**
Given a host where `python3` runs but PyYAML is absent, or the YAML file is missing or malformed
When a ported script reads it
Then the script exits non-zero and prints a message naming the cause (`PyYAML is required to parse the workflow YAML` for the absent module); 0 of the ported scripts go on with an empty value after the helper failed (checked with 3 causes: no module, no file, malformed YAML).

**AC-Y4: Docs say so**
Given the setup and CI docs (`_docs/02_document/**` that name Ruby, and the README or setup line that lists what a host needs)
When they are read after this loop
Then they name Python 3 and PyYAML and name Ruby 0 times as a need of the scripts.

## C: CI

**AC-C1: CI is green and runs the six**
Given the push of this loop to `dev` and `main`
When both `test.yml` runs complete
Then both are `success`, and the CI log shows the six scripts that did not run on the loop 81 host (`report-row`, `run-suite`, `ring-wiring`, `ring-wiring-swift`, `publish-workflow`, `publish-pins`) as PASS; wall time of the `scaffold` and `publish-gate-rest` jobs grows by at most 60 s over the loop 81 run (`dev` 4 m 58 s, `main` 7 m 45 s in total).
