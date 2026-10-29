---
loop: 83
branch: dev
---

# One shared module for the ring-wiring checkers

**Task**: AZ-3388_ring_wiring_shared_module
**Name**: One shared module for the helpers of the two ring-wiring checkers
**Description**: The 12 definitions the two checkers duplicate move to one module under `scripts/ci/`; both checkers import it and print the same violations.
**Complexity**: 3 points
**Dependencies**: None (AZ-3384 is shipped)
**Component**: CI scripts (`scripts/ci/`, `.github/workflows/ring-wiring*-check.py`)
**Tracker**: AZ-3388
**Epic**: none

## Problem

`ring-wiring-check.py` (249 lines) and `ring-wiring-swift-check.py` (200) define the same 12 names, 52 lines: `FLAGS`, `CACHE_USES`, `SHA_PIN`, `ASCII_SPACE`, `STRING_ESCAPES`, `to_s`, `inspect`, `first_set`, `dig`, `steps_of`, `code_lines`, `runs`. A fix to one (the quoting in `inspect`, the SHA pin) must be made twice. `violations` and `main` differ and stay. Both already put `scripts/ci` on `sys.path` for `yaml_get`.

## Outcome

- The 12 definitions exist once, in a module next to `scripts/ci/yaml_get.py`.
- The checkers say the same thing as before.

## Scope

### Included
- A new module under `scripts/ci/` (name chosen by the worker, one that says what it is: workflow-YAML helpers) holding the 12 definitions; both checkers import them.
- Both checkers keep running as `python3 -I <checker> ...` (the module is found by the same `sys.path.insert` as `yaml_get`).
- A test of the module only where the three wiring tests do not already exercise a function (`inspect` quoting, `dig`, `first_set` edges): a small shell test next to `yaml_get.test.sh`, or none if the wiring mutants cover it (decided by a mutation: break one helper, a wiring test must fail).

### Excluded
- Changes to `violations`, `main`, a violation text or a check.
- The `setup-python` / `RING_PYTHON` fold; `yaml_get.py` itself.
- Other Python scripts with similar helpers (`publish-*.py`): not picked.

## Acceptance Criteria

**AC-1: Defined once**
Given the tree after the task
When the 12 names are searched with `grep -c -E '^(def (to_s|inspect|first_set|dig|steps_of|code_lines|runs)\b|(FLAGS|CACHE_USES|SHA_PIN|ASCII_SPACE|STRING_ESCAPES) =)'`
Then 0 in each checker and 12 in the new module (HEAD: 12 and 12); lines identical in both checkers 52 -> 0

**AC-2: Wiring tests unchanged**
Given the logs of HEAD (scratchpad): `ring-wiring.test.sh` 49 lines, 38 `rejects:`; `ring-wiring-rows.test.sh` 25 lines, 19; `ring-wiring-swift.test.sh` 67 lines, 53
When the three run after the task
Then all exit 0 and the output is identical to HEAD's line for line (`diff` empty), apart from nothing

**AC-3: Same words**
Given 10 mutated copies of `test.yml` (the ones the wiring tests build) and the real file
When each checker runs on HEAD's version and on the new one
Then stdout, stderr and exit code are byte-identical, including exit 2 with the unreadable-YAML message

**AC-4: Isolated mode**
Given `python3 -I`
When each checker runs from another directory
Then it finds the module (exit 0 on the real `test.yml`)

**AC-5: A broken helper is caught**
Given a scratch copy where `inspect` drops the escape of `"`
When the wiring tests run on it
Then at least 1 fails (the helper is under test)

**AC-6: Pins and guard**
Given `publish-pins.test.sh`
When it runs
Then it passes: no `ruby`, and every job that runs the checkers has the PyYAML install (the module imports only the standard library and `yaml_get`)

## Non-Functional Requirements

**Compatibility**
- Python 3.10 or newer (CI: `RING_PYTHON` 3.14; this host 3.14.4).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | grep count in each file | 0 / 0 / 12 |
| AC-5 | a helper mutation | a wiring test fails |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2 | HEAD logs | the three wiring tests | identical output | none |
| AC-3 | `test.yml` and its mutants | both checkers, HEAD vs new | byte-identical | none |
| AC-4 | cwd elsewhere, `python3 -I` | both checkers | exit 0 | none |
| AC-6 | `publish-pins.test.sh` | run | PASS | none |

## Constraints

- Exclusive paths: `scripts/ci/` (new module and test), `.github/workflows/ring-wiring-check.py`, `.github/workflows/ring-wiring-swift-check.py`. No edit to `ring-wiring*.test.sh` unless a path they call changes (then AC-2 still holds).

## Risks & Mitigation

**Risk 1: The checkers are the net under the CI workflow; a refactor drops a check silently**
- *Mitigation*: AC-2, AC-3 (byte-identical on HEAD's mutants), AC-5.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Refactor of the CI safety net | AC-2, AC-3, AC-5 | open | High |
| A CI job that runs a checker lacks the module's directory | the checkers already read `scripts/ci`; AC-4, AC-6 | open | Low |
