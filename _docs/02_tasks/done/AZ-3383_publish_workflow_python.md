---
loop: 82
branch: dev
---

# publish-workflow.test.sh in Python with an if: evaluator that never evals

**Task**: AZ-3383_publish_workflow_python
**Name**: publish-workflow.test.sh in Python with an if: evaluator that never evals
**Description**: The structure checker of `publish.yml` and `test.yml` and the truth-table evaluator of GitHub `if:` expressions run in Python with the same refusals and no `eval`.
**Complexity**: 5 points
**Dependencies**: AZ-3381
**Component**: CI scripts (`.github/workflows/`, `test.yml`, `tool-pins.txt`)
**Tracker**: AZ-3383
**Epic**: none

## Problem

`workflow_structure` is a 128-line Ruby program. Its evaluator rewrites `needs.<job>.result`, `needs.<job>.outputs.<name>`, `cancelled()` and `always()` into Ruby text, filters the characters, and `eval`s it for every result a needed job can have.

## Outcome

- The same structure checks and the same truth tables run on the shared reader.
- The evaluator is a small parser that accepts `==`, `!=`, `&&`, `||`, `!`, parentheses, quoted strings, `true`/`false`, the two `needs` forms, `cancelled()` and `always()`, and refuses everything else before evaluating.

## Scope

### Included

- `.github/workflows/publish-workflow.test.sh`: `workflow_structure` and the `command -v ruby` guard (line 177) replaced; the surrounding scenarios and their mutants kept.
- The evaluator (in the same file, or a sibling file if the 500-line cap needs it).

### Excluded

- Changes to `publish.yml` or `test.yml`.
- The reader itself (AZ-3381).

## Acceptance Criteria

**AC-1: Same structure checks**
Given `test.yml` and `publish.yml` at HEAD
When the ported checker runs
Then it reports 0 errors, as Ruby did, and every error message of HEAD still exists for its rule

**AC-2: Same truth tables**
Given the `if:` of the test call and of the publish job, over `success/failure/cancelled/skipped` results, the 3 `green` values and `cancelled` true/false
When the ported evaluator evaluates them
Then the same value as HEAD for every combination; `runs` for the test call exactly when there is no green proof

**AC-3: Same refusals**
Given an `if:` with a term outside the supported set, and one that does not evaluate (an unbalanced parenthesis)
When the evaluator reads it
Then it refuses with a message naming the term, or `does not evaluate`; 0 of the cases HEAD refuses are accepted

**AC-4: No code from workflow text**
Given an `if:` containing a quote not closed, a semicolon, a backtick or `$(`
When the evaluator reads it
Then it refuses before any evaluation; the file has 0 calls to `eval` or `exec` on workflow text

**AC-5: Each rule fails on a mutation**
Given the mutants the file holds at HEAD plus one per rule that had none
When the checker runs on each
Then each exits non-zero naming the rule (0 lost)

## Non-Functional Requirements

**Compatibility**
- Runs with `python3 -I` on the Python of this host (3.14.4) and of the CI jobs; uses only features both have.

**Reliability**
- A reader failure is a failure of the script that called it; no script goes on with an empty value.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | real workflows | 0 errors |
| AC-2 | all combinations of HEAD | same booleans |
| AC-3 | 2 refusal cases | refused with message |
| AC-4 | 4 characters | refused, no evaluation |
| AC-5 | mutants | all rejected |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | this host without Ruby | run through the sourcing path of `publish-gate.test.sh` | passes | - |

## Constraints

- No stand-in: every check of the replaced script is kept (label list taken from the source at HEAD 5a78fb8 before the change); a check that cannot be kept goes to the owner, never dropped.
- Each ported script is proven by one deliberate mutation of what it guards (it exits non-zero and names the check) and runs green on a host without `ruby`.
- Each file stays at or under 500 lines; split by responsibility.
- Inherits project AC-11, AC-12, AC-14, AC-15 unchanged in meaning.
- The file is sourced by `publish-gate.test.sh`, which defines `fail`, `$root` and `$here`; the sourcing contract stays.

## Risks & Mitigation

**Risk 1: the parser accepts more than the filter did**
- *Risk*: a grammar wider than the old character class plus quoted strings.
- *Mitigation*: tokenizer with a closed token set; a test per refusal; no `eval`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The evaluator widens what it accepts | closed tokenizer, one test per refusal | open | Medium |
