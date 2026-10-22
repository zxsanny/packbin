---
loop: 60
branch: dev
---

# Rust nostd corpus count: kind and lowercase hex, no Vec per line

**Task**: AZ-PENDING_rust_nostd_corpus_kind_hex_rule
**Name**: Rust nostd corpus count: kind and lowercase hex, no Vec per line
**Description**: `listed_inputs` counts an input as three fields with a `[a-z0-9_]+` name, a `[a-z0-9_]+` kind and a lowercase-hex last field, splitting each line without a `Vec`.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `rust/tests/nostd_hostile_tests.rs`
**Tracker**: pending (Jira connector absent, see `_docs/_process_leftovers/2026-10-22_loop60_jira_create_tasks.md`)
**Epic**: AZ-2645

## Problem

The count rule checks the name only: a line with a bad kind or an upper-case hex last field is counted although the README format excludes it; each line allocates a `Vec`.

## Outcome

- The count follows the README rule in full (`name kind hex`, name and kind `[a-z0-9_]+`, hex lowercase) and still differs from the loader's filter.

## Scope

### Included
- Test code in the file named under Component.

### Excluded
- Any product code, the real `fixtures/` tree, the loader in `rust/tests/nostd_support/hostile.rs`, a `-` placeholder (not in the format).

## Acceptance Criteria

**AC-4: Rule** — Given the real `corpus.txt`, When `listed_inputs` runs, Then it returns the loader's count (33), checks name, kind and lowercase hex, and allocates no `Vec` per line.

**AC-5: Copies** — Given a scratch copy with `# note abcd`, Then the count is unchanged and the test passes; given an upper-case hex last field or a kind outside `[a-z0-9_]+`, Then the line is not counted and the test fails naming `lists 33 inputs, the loader read 34`; given one extra valid input line, both counts rise by one; given a loader copy that also drops lines starting with a letter, the test fails naming expected and loaded counts.

## Non-Functional Requirements

**Compatibility**: test code only; flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-4, AC-5 | `cargo test --features text --test nostd_hostile_tests` on the real tree and on corpus copies under the scratchpad | pass |
| AC-5 | broken loader copy | fails naming both counts |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |
