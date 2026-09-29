---
loop: 8
branch: loop/8-scheme-field-order
---

# Write the field-order failure rule

**Task**: AZ-2016_order_sentence
**Name**: Write the field-order failure rule
**Description**: The sentence after field order is wire order states how a bad number fails, and that the anchor is not written.
**Complexity**: 1 point
**Dependencies**: None
**Component**: library
**Tracker**: AZ-2016
**Epic**: AZ-1865

## Problem

Field order is described as wire order. The failure for a gap, a repeated id, or a bad anchor is only inside each constructor.

## Outcome

- The next sentence states that a gap, a repeated id, or an anchor that is not the next value id fails construction.
- It states that the anchor is not written and that `repeat` still has no count on the wire.
- It states that a list, a dict, and a nested group still start at 0.

## Scope

### Included

- That sentence beside the existing order sentence.

### Excluded

- Changing pack or unpack.

## Acceptance Criteria

**AC-1: The failure rule is next to the order sentence.**
Given the sentence that field order is wire order.
When a reader reads the next sentence.
Then it names the gap, the repeated id, and the bad anchor, and it says the anchor is not written.

## Feature Acceptance Criteria

Exercises AC-5 of the scheme-field-order feature.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the order sentence and the next sentence | both statements are present |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | the order sentence | the following sentence | gap, repeat, and bad anchor fail; the anchor is not written | — |

## Constraints

- Do not change the bytes of an existing packet.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| — | — | — | — |
