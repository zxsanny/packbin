---
loop: 47
branch: dev
---

# Split language-pair.sh by responsibility, with its wiring tests

**Task**: AZ-2744_split_language_pair
**Name**: Split `language-pair.sh` (545 lines) and the wiring tests that read it
**Description**: The driver runner and the handoff helper move out of `language-pair.sh` into `ring-lib.sh`; every script that reads the lines of the ring follows; the all-language session-ecc check leaves the Swift wiring test.
**Complexity**: 3 points
**Dependencies**: None
**Component**: `.github/workflows/language-pair.sh`, `ring-lib.sh` (new), `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `ring-ecc.sh`, `ring-prepare.test.sh`, and a new wiring test file for the session-ecc stage
**Tracker**: AZ-2744
**Epic**: AZ-2645

## Problem

`language-pair.sh` is 545 lines (soft cap 500, `quality-thresholds.md`) after AZ-2739, `ring-wiring.test.sh` sits at exactly 500, and `ring-wiring-swift.test.sh` (467) holds a check of the all-language session-ecc stage that has nothing to do with Swift (loop 46 review, two skipped findings; the AZ-2739 flagged concern).

## Outcome

- Each file of the ring has one job and none is over 500 lines; a later ring row does not push a test over the cap.

## Scope

### Included
- `ring-lib.sh` (new): the work-directory and driver-path variables, `run_lang()` and `handoff()`, moved as they are. `language-pair.sh` sources it and keeps the hex vectors, every `handoff` row and the stages, and is 500 lines or fewer.
- `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `ring-ecc.sh` (it reads `run_lang` out of `language-pair.sh` with `sed`), `ring-prepare.test.sh` (it greps the driver default paths in `language-pair.sh`) and any copy of `language-pair.sh` into a temp tree (the shim ring in `ring-wiring.test.sh` must copy `ring-lib.sh` beside it) updated to read the right file.
- The session-ecc stage check moved from `ring-wiring-swift.test.sh` into its own test file, named for what it checks, with the same mutants and the same exact-line reads.
- `test.yml` and any path filter or file list that names the ring scripts, when it names them.

### Excluded
- Any change to a handoff row, a hex vector, a driver or a package source.
- A new ring stage or a new language.
- Renaming `language-pair.sh` (`test.yml` and `ring-wiring.test.sh` match its name).

## Acceptance Criteria

**AC-1: Same ring**
Given the ring before and after the split
When `bash .github/workflows/language-pair.sh` runs with `PACKBIN_CXX_SYSROOT` and Python 3.10 or newer (`AGENT_GOTCHAS.md`)
Then the same `handoff` rows run (same count, same order) and it prints "language pairs passed".

**AC-2: Sizes**
Given the files of the split
When the line counts are read
Then no file touched is over 500 lines, and `language-pair.sh` is at most 500.

**AC-3: Readers follow**
Given every script that reads the lines of the ring
When `ring-wiring.test.sh`, the Swift wiring test, the new session-ecc wiring test, `ring-ecc.test.sh` and `ring-prepare.test.sh` run
Then each is green, and each of their mutants is still rejected (a mutant that no longer applies is rewritten, not dropped).

**AC-4: A broken split fails loudly**
Given `ring-lib.sh` missing or without `run_lang`
When `language-pair.sh` or `ring-ecc.sh` runs
Then it exits non-zero with a line that names the file.

## Non-Functional Requirements

**Performance**
- No added CI job; the ring time does not grow (one `source`).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-3 | `ring-wiring.test.sh`, Swift wiring test, session-ecc wiring test, `ring-ecc.test.sh`, `ring-prepare.test.sh` | green, mutants rejected |
| AC-4 | a temp tree without `ring-lib.sh` | non-zero, names the file |
| AC-2 | `wc -l` on each touched file | at most 500 |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | `bash .github/workflows/language-pair.sh`, host recipes of `AGENT_GOTCHAS.md` | the whole ring | "language pairs passed" | Performance |

## Constraints

- Before committing: `git grep` every reader of the lines of `language-pair.sh` and of `run_lang`, and run each one (`AGENT_GOTCHAS.md`, loops 34 and 39). `bash -n` and `shellcheck` (if installed) on the changed scripts; bash 3.2 syntax only.
- A worker never runs `git stash/checkout/reset/clean/add/rm/mv`; commands end on their own (stdin from `/dev/null`, a timeout).
- The runtime lock is held for the ring run.

## Risks & Mitigation

**Risk 1: A reader keeps the old path**
- *Risk*: a script reads `run_lang` or a driver default from `language-pair.sh` and still passes because the text is also elsewhere.
- *Mitigation*: AC-3 mutants; a `git grep` for `run_lang`, `swift_ring` and `PACKBIN_RING_WORK` over `.github` before the commit.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| The ring is the slowest CI group | no row or build added; the CI time is read after the push | open | Low |
