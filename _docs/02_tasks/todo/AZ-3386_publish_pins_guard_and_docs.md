---
loop: 82
branch: dev
---

# publish-pins in Python, no-Ruby guard, install-step check and docs

**Task**: AZ-3386_publish_pins_guard_and_docs
**Name**: publish-pins in Python, no-Ruby guard, install-step check and docs
**Description**: The pins test runs in Python, a check refuses any `ruby` in the CI scripts and any job that runs a ported script without the pinned PyYAML, and the docs say Python 3 and PyYAML.
**Complexity**: 5 points
**Dependencies**: AZ-3381, AZ-3382, AZ-3383, AZ-3384, AZ-3385
**Component**: CI scripts (`.github/workflows/`, `test.yml`, `tool-pins.txt`)
**Tracker**: AZ-3386
**Epic**: none

## Problem

`publish-pins.test.sh` embeds 39 lines of Ruby (lines 13-53) and a `ruby is required` guard (line 361). After the other ports nothing stops a later edit from bringing Ruby back or from adding a job that runs a ported script with no PyYAML. Two documents name Ruby as the YAML reader.

## Outcome

- No `ruby` anywhere in `.github/workflows`; a guard keeps it so.
- Every job that runs a ported script installs the pinned PyYAML; a test fails when one does not.
- Docs and the push are in line.

## Scope

### Included

- `publish-pins.test.sh` ported; its guard becomes the PyYAML guard.
- A check (in the pins test) that fails on the word `ruby` (case-insensitive) in `.github/workflows/*.sh`, `*.yml` and `tool-pins.txt`, and on a job of `test.yml` that runs a script calling the reader without the install step.
- `_docs/02_document/module-layout.md` (line 280) and `_docs/02_document/deployment/ci_cd_pipeline.md` (line 12) and any other `_docs/02_document` line a search finds, and the setup line that lists what a host needs: Python 3 and PyYAML.
- The push of the loop and the CI result.

### Excluded

- Installing a JDK on this host.
- Any change to the ring or the toolchain pins.

## Acceptance Criteria

**AC-1: Ruby is gone**
Given the tree after the loop
When `.github/workflows/*.sh`, `*.yml` and `tool-pins.txt` are searched for `ruby` (case-insensitive)
Then 0 matches (HEAD: 10 scripts and `test.yml`)

**AC-2: A new ruby is refused**
Given a copy of a script with a `ruby -e` call added
When the pins test runs on it
Then it exits non-zero naming the file

**AC-3: Install step required**
Given a copy of `test.yml` with the PyYAML install removed from one job that runs a ported script
When the pins test runs on it
Then it exits non-zero naming the job; the real file passes (jobs with the install = jobs that run a ported script, 100%)

**AC-4: Pins test keeps its checks**
Given `publish-pins.test.sh` at HEAD
When it is ported
Then every labelled check and mutant runs (0 dropped, 0 lost)

**AC-5: Docs**
Given `_docs/02_document/**` and the setup line
When they are read
Then they name Python 3 and PyYAML and name Ruby 0 times as a need of the scripts

**AC-6: CI**
Given the push of this loop to `dev` and `main`
When both `test.yml` runs complete
Then both `success`; the six formerly unrun scripts (`report-row`, `run-suite`, `ring-wiring`, `ring-wiring-swift`, `publish-workflow`, `publish-pins`) PASS in the log; `scaffold` and `publish-gate-rest` grow by at most 60 s over the loop 81 run

## Non-Functional Requirements

**Compatibility**
- Runs with `python3 -I` on the Python of this host (3.14.4) and of the CI jobs; uses only features both have.

**Reliability**
- A reader failure is a failure of the script that called it; no script goes on with an empty value.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | search | 0 matches |
| AC-2 | mutant copy | non-zero |
| AC-3 | mutant `test.yml` | non-zero naming the job |
| AC-4 | ported file | checks all run |
| AC-5 | text search | no Ruby need |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-6 | push to dev and main | `gh run list` / log read | both success; six scripts PASS | - |

## Constraints

- No stand-in: every check of the replaced script is kept (label list taken from the source at HEAD 5a78fb8 before the change); a check that cannot be kept goes to the owner, never dropped.
- Each ported script is proven by one deliberate mutation of what it guards (it exits non-zero and names the check) and runs green on a host without `ruby`.
- Each file stays at or under 500 lines; split by responsibility.
- Inherits project AC-11, AC-12, AC-14, AC-15 unchanged in meaning.

## Risks & Mitigation

**Risk 1: first real run is CI**
- *Risk*: six of the scripts never ran on the loop 81 host; a CI-only difference shows only after the push.
- *Mitigation*: read the log of each red job with `gh api` before naming a cause; fix on `dev`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| CI is the first run of six scripts on its runners | read the log of every job | open | Low |
