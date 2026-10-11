---
loop: 20
branch: dev
---

# TypeScript pack fails naming the member for a times inside a when inside a split bit whose count is never written while values are given

**Task**: AZ-2363_typescript_times_in_when_split_bit
**Name**: TypeScript times in when in split bit
**Description**: TypeScript pack fails naming the member for a times inside a when inside a split bit whose count is never written while values are given.
**Complexity**: 1 points
**Dependencies**: AZ-2331 (done)
**Component**: typescript
**Tracker**: AZ-2363
**Epic**: AZ-2069

## Problem

Loop 20 clear gap G3 (AZ-2331 follow-up). TypeScript does not detect that shape; the other packages refuse it.

## Outcome

- TypeScript refuses it naming the member, as the other five do.

## Acceptance Criteria

**AC-1: refused**
Given a `times` inside a `when` inside a split flag bit, a count never written, and values
When packed in TypeScript
Then an error naming the member

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | G3 shape | error |

## Constraints

- Wire bytes of every accepted row are unchanged.
