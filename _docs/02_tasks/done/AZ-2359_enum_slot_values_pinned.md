---
loop: 20
branch: dev
---

# The per-language rule for enum values in integer slots is pinned by tests in each package and written in the README

**Task**: AZ-2359_enum_slot_values_pinned
**Name**: Enum slot values pinned
**Description**: The per-language rule for enum values in integer slots is pinned by tests in each package and written in the README.
**Complexity**: 1 points
**Dependencies**: AZ-2309 (done)
**Component**: python, java, rust, typescript, csharp (tests); README in step 13
**Tracker**: AZ-2359
**Epic**: AZ-2069

## Problem

Owner decision 7 of loop 20 (assessment U6, option A). Python accepts an `IntEnum` member (an int subclass); C# refuses enums for numeric fields (AZ-2309); Java, Rust and TypeScript not probed.

## Outcome

- An integer-valued enum is accepted where the language treats it as an int (Python `IntEnum`, TypeScript numeric enum: plain numbers at runtime); C# keeps refusing; Java and Rust enums are not numbers and stay refused (probe first, record the result per package).
- Each package has a test that pins its behavior; no behavior change expected.

## Acceptance Criteria

**AC-1: pinned**
Given an integer-valued enum member in a `u8` slot
When packed in each package that has one
Then Python and TypeScript pack the integer's bytes; C#, Java and Rust refuse naming the field (or the probe result if it differs, reported before any change)

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | enum in u8 slot, per package | behavior pinned |

## Constraints

- Wire bytes of every accepted row are unchanged.
