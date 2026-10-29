---
loop: 82
branch: dev
---

# publish-precheck.sh and its test in Python (release path)

**Task**: AZ-3382_publish_precheck_python
**Name**: publish-precheck.sh and its test in Python (release path)
**Description**: The release-path precheck reads the runs API answer with Python's standard library, and its test builds runs in Python with its mutants rewritten for the new text.
**Complexity**: 3 points
**Dependencies**: None
**Component**: CI scripts (`.github/workflows/`, `test.yml`, `tool-pins.txt`)
**Tracker**: AZ-3382
**Epic**: none

## Problem

`publish-precheck.sh` (called by `publish.yml` job `precheck`) decides `green=true` only for a completed, successful push run of `test.yml` of this repository at the tagged commit. Its lookup is a 17-line Ruby program; its test builds the runs with `ruby -rjson` and has 11 `sed` mutants written against the Ruby text. A wrong port can pass a run that should refuse.

## Outcome

- The lookup runs on `python3` with the standard library only (no PyYAML) and gives the same verdict for every scenario.
- The test keeps all 10 run scenarios, the 3 failure scenarios, the request parts, the 3 bad commits, the bad repository, and the 11 condition mutants, each still failing at least one scenario.

## Scope

### Included

- `.github/workflows/publish-precheck.sh`: the `RUBY` heredoc and `ruby -rjson` call replaced by Python.
- `.github/workflows/publish-precheck.test.sh`: `run_json` in Python; the 11 `mutant` sed expressions rewritten so each changes the new text and fails a scenario.

### Excluded

- `publish.yml` and the precheck's contract with it (outputs, `green=` line, exit codes) stay as they are.
- The shared YAML reader (not needed here).

## Acceptance Criteria

**AC-1: Verdicts unchanged**
Given the 10 run scenarios (a green push run, no run, a failed run, a cancelled run, a run in progress, a pull request run, another commit, another workflow file, another repository, a path with a ref suffix)
When the ported script runs on each with a stub `curl`
Then `green=true` for exactly 2 (the green run and the ref-suffix path), `green=false` for the other 8; exit 0

**AC-2: Failure paths**
Given a curl exit of 22, an answer `not json`, an answer `{}`
When the script runs
Then `green=false`, exit 0; for curl the reason `runs API call failed` is printed

**AC-3: Bad input**
Given `PACKBIN_SHA` empty, `abc` or upper case hex, or `PACKBIN_REPO` `not a repo`
When the script runs
Then exit 2 and nothing written to the output file (4 of 4)

**AC-4: Request and token**
Given a green run
When the script runs
Then the request holds `workflows/test.yml/runs`, `head_sha=<sha>`, `event=push`, `status=success` and `Authorization: Bearer <token>`; the token is in neither stdout nor the output file

**AC-5: No YAML needed**
Given a host where PyYAML is absent
When the script runs
Then it gives the same verdicts; it imports no `yaml`

**AC-6: Mutants**
Given 11 changed copies, one per condition (head_sha, event, status, conclusion, workflow path, repository, no-proof output, failed call, sha filter in the request, sha validation, token)
When the test runs on each
Then each changes the script text and fails at least one scenario (11 of 11)

## Non-Functional Requirements

**Compatibility**
- Runs with `python3 -I` on the Python of this host (3.14.4) and of the CI jobs; uses only features both have.

**Reliability**
- A reader failure is a failure of the script that called it; no script goes on with an empty value.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | 10 scenarios | verdicts as above |
| AC-2 | 3 scenarios | green=false, exit 0, reason |
| AC-3 | 4 inputs | exit 2, no output |
| AC-4 | request log | 5 parts present, token absent from output |
| AC-5 | `yaml` import blocked | same verdicts |
| AC-6 | 11 mutants | 11 rejected |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | stub `curl`, this host without Ruby | `bash publish-precheck.test.sh` | all scenarios ok; the 11 mutants rejected | - |

## Constraints

- No stand-in: every check of the replaced script is kept (label list taken from the source at HEAD 5a78fb8 before the change); a check that cannot be kept goes to the owner, never dropped.
- Each ported script is proven by one deliberate mutation of what it guards (it exits non-zero and names the check) and runs green on a host without `ruby`.
- Each file stays at or under 500 lines; split by responsibility.
- Inherits project AC-11, AC-12, AC-14, AC-15 unchanged in meaning.
- The script never fails a run for a lookup result and never decides to publish (its header contract).

## Risks & Mitigation

**Risk 1: a verdict flips on the release path**
- *Risk*: the Python condition differs from the Ruby one (for example the `path` split on `@`).
- *Mitigation*: one scenario per condition and a mutant per condition; the `refs/heads/dev` path-suffix scenario is kept; CI's `publish-gate-rest` runs it.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Release path: a weaker condition passes a red run | each condition has a scenario and a mutant | open | High |
