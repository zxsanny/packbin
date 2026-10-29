---
loop: 82
branch: dev
---

# CI YAML reader, PyYAML pin and the three one-liner scripts

**Task**: AZ-3381_ci_yaml_reader_and_pin
**Name**: CI YAML reader, PyYAML pin and the three one-liner scripts
**Description**: One Python reader for the workflow and compose YAML, a pinned PyYAML installed where a ported script runs, and the three `ruby -ryaml -e` one-liners switched to it.
**Complexity**: 5 points
**Dependencies**: None
**Component**: CI scripts (`.github/workflows/`, `test.yml`, `tool-pins.txt`)
**Tracker**: AZ-3381
**Epic**: none

## Problem

Nine scripts read YAML through `ruby -ryaml`; ten copies of the loading idea would follow a port script by script. The three one-liners (`report-row.test.sh` line 14, `run-suite.test.sh` line 455, `run-suite-swift.test.sh` line 368) read a matrix or the compose services and print a sorted list.

## Outcome

- One reader that the other ported scripts call; PyYAML pinned in `tool-pins.txt`; the CI jobs that run a ported script install that pin.
- The three one-liners run without Ruby and print what they printed.

## Scope

### Included

- The reader (for example `scripts/ci/yaml_get.py`, run with `python3 -I`, `yaml.safe_load` only), its test (anchors, merge keys, `yes`/`no`/`on` values, `on:` as the key `True` and quoted `"on"`, no module, no file, malformed YAML).
- One `pyyaml==X.Y.Z` line in `.github/workflows/tool-pins.txt` (a version at least two weeks old; this host has 6.0.3) read through `tool-pin.sh`.
- The install step, from the pins file, in each job of `test.yml` that runs a script that calls the reader (traced from the scripts, not guessed); the reader's own test is run in `scaffold`.
- `report-row.test.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh`: the `ruby` call replaced.

### Excluded

- The four large scripts and the precheck (AZ-3382, AZ-3383, AZ-3384, AZ-3385, AZ-3386).
- The no-Ruby grep guard and the check that every such job has the install (AZ-3386).

## Acceptance Criteria

**AC-1: One reader**
Given the ported scripts of this loop
When their YAML loading code is searched
Then it exists in 1 file; it calls `yaml.safe_load` and never `yaml.load`; it is run with `python3 -I`

**AC-2: `on:` and YAML 1.1 words**
Given a workflow with the key `on` loaded as `True`, one with the quoted key `"on"`, one with anchors and a merge key, one with `yes`/`no` values
When the reader reads the triggers and values
Then both `on` forms give the same triggers (2 of 2) and the rest reads as Ruby's `safe_load` did

**AC-3: A failing reader fails the caller**
Given a host without the module, a missing file, a malformed file
When a one-liner script calls the reader
Then it exits non-zero and names the cause (`PyYAML is required to parse the workflow YAML` for the absent module); it does not continue with an empty value (3 of 3)

**AC-4: Pin installed**
Given `tool-pins.txt` and `test.yml`
When they are read
Then exactly 1 `pyyaml==X.Y.Z` line exists; each job that runs a ported script at this task's stage installs that version from the pins file before the script

**AC-5: One-liners unchanged**
Given `test.yml` and `docker-compose.test.yml` at HEAD
When the three one-liner scripts run on a host with no `ruby`
Then each prints the same list as at HEAD (the matrix languages sorted and unique; the swift parts sorted; the suite services) and exits 0

## Non-Functional Requirements

**Compatibility**
- Runs with `python3 -I` on the Python of this host (3.14.4) and of the CI jobs; uses only features both have.

**Reliability**
- A reader failure is a failure of the script that called it; no script goes on with an empty value.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | search of the tree | 1 file loads YAML; 0 `yaml.load(` |
| AC-2 | reader test with 4 workflow texts | same triggers and values |
| AC-3 | reader test with 3 causes | non-zero exit, named cause |
| AC-4 | text of `tool-pins.txt` | 1 pyyaml line with `==` |
| AC-5 | the three scripts, no `ruby` on `PATH` | exit 0, same lists |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-3 | `PATH` without `ruby`, PyYAML hidden (`PYTHONPATH` to a dir with a stub `yaml.py` that raises ImportError) | run `report-row.test.sh` | exit non-zero, message names PyYAML | - |
| AC-5 | this host | run the three one-liner scripts | all pass without Ruby | - |

## Constraints

- No stand-in: every check of the replaced script is kept (label list taken from the source at HEAD 5a78fb8 before the change); a check that cannot be kept goes to the owner, never dropped.
- Each ported script is proven by one deliberate mutation of what it guards (it exits non-zero and names the check) and runs green on a host without `ruby`.
- Each file stays at or under 500 lines; split by responsibility.
- Inherits project AC-11, AC-12, AC-14, AC-15 unchanged in meaning.
- The pin is read through `tool-pin.sh`; no second place holds the version.

## Risks & Mitigation

**Risk 1: PyYAML absent in a CI job**
- *Risk*: a job runs a ported script on the runner's Python with no PyYAML.
- *Mitigation*: the install step per job; AZ-3386 adds the check that fails when one is missing; CI is the first real run.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A job runs the reader before the install step | trace jobs to scripts; CI log is the proof | open | Medium |
| Python version differs between this host (3.14) and `setup-python` | helper uses only features of both | open | Low |
