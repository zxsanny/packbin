---
loop: 21
branch: dev
---

# Hostile loaders in Python, Java, Rust and C++ pin the refusal rule and message

**Task**: AZ-2392_hostile_loader_rule_tables
**Name**: Hostile loaders in Python, Java, Rust and C++ pin the refusal rule and message
**Description**: Each loader names the rule or message a refused `pack` case must give, as TypeScript's `PACK_REFUSAL` and C#'s `NamedMember` do; the C++ pins that pass through the wrong rule are corrected.
**Complexity**: 3 points
**Dependencies**: AZ-2394 (new cases), after the packages' rule work
**Component**: python, java, rust, cpp (test files)
**Tracker**: AZ-2392
**Epic**: AZ-2069

## Problem

Gaps G2 and G3 from the loop 20 review. Python, Java, Rust and C++ hostile loaders pin only that pack refused, so a refusal by the wrong rule passes. The C++ AZ-2356 pin and `pack_split_count_zero_after_byte_list` pass through the late rule, not the count-0 rule.

## Outcome

- A table per loader maps each refused pack case to a rule id or message fragment; a refusal by another rule fails the test.
- The two C++ pins check the count-0 rule (the scheme is changed if needed so the late rule does not fire first).

## Scope

### Included
- The four loaders' test files and `fixtures/hostile/cases.txt` rule column if the format allows it.

### Excluded
- Library code.

## Acceptance Criteria

**AC-1: rule pinned**
Given every refused `pack` case
When the four loaders run
Then each checks the rule or message

**AC-2: wrong rule fails**
Given a case refused by another rule
When the loader runs
Then it fails (shown once per loader by a temporary edit, reverted)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | all pack cases | pass with the table |
| AC-2 | negative check | fails as expected |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | hostile stage | all `pack` rows | six loaders pass | — |

## Constraints

- One worker per package directory; the fixture format change (if any) is made by the AZ-2394 worker first.
