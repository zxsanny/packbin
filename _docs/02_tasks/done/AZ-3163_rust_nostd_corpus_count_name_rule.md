---
loop: 59
branch: dev
---

# Rust nostd corpus count by the README name rule

**Task**: AZ-3163_rust_nostd_corpus_count_name_rule
**Name**: Rust nostd corpus count by the README name rule
**Description**: `listed_inputs` counts an input as three fields with a `[a-z0-9_]+` name and a hex last field, so a hex-ended comment is not counted and the dead `is_empty` check is gone.
**Complexity**: 2 points
**Dependencies**: None
**Component**: `rust/tests/nostd_hostile_tests.rs`
**Tracker**: AZ-3163
**Epic**: AZ-2645

## Problem

`listed_inputs` accepts any three-field line with a hex last token, so a three-field `#` comment is counted; its `!f[2].is_empty()` can never be false.

## Outcome

- The count follows the README rule (`name kind hex`, name in `[a-z0-9_]+`) and still differs from the loader's filter.

## Scope

### Included
- Test code in the file named under Component.

### Excluded
- Any product code, the real `fixtures/` tree, the loader in `rust/tests/nostd_support/hostile.rs`, a `-` placeholder (not in the format).

## Acceptance Criteria

**AC-1: Rule** — Given the real `corpus.txt`, When `listed_inputs` runs, Then it returns the loader's count and holds no `is_empty` check.

**AC-2: Comment and extra line** — Given a copy with `# note abcd`, Then the count is unchanged and the test passes; given one extra input line, both counts rise by one.

**AC-3: Loader sensitivity** — Given a loader copy that also drops lines starting with a letter, Then the test fails naming expected and loaded counts.

## Non-Functional Requirements

**Compatibility**: test code only; flash 8,032 B and the stack figures stay as in loop 57.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1, AC-2 | `cargo test` on the real tree and on corpus copies under the scratchpad | pass |
| AC-3 | broken loader copy | fails naming both counts |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Test-only change | no edit under `cpp/src`, `cpp/include` or any library source | open | Low |

## Outcome of loop 59

AC-1 to AC-3 met. `listed_inputs()` counts three-field lines whose name is `[a-z0-9_]+` and whose last field is hex; the dead `is_empty` check is gone. Scratch copies: a `# note abcd` line leaves the count unchanged and the test passes; one extra input line raises both counts (34 and 34); a loader that also drops lines starting with a letter fails `corpus.txt lists 34 inputs, the loader read 0`. Real tree: `cargo test --features text --test nostd_hostile_tests` 6 passed.
