---
loop: 12
---

# C++ refuses an empty group with no member inside flags

**Task**: AZ-2147_cpp_empty_group_without_member
**Name**: C++ empty group without member
**Description**: A C++ `group(id)` with no children and no member fails scheme construction wherever it stands, including directly in `flags` and as a `flag_bit`.
**Complexity**: 1 point
**Dependencies**: AZ-2081_cpp_bool_u2_construction
**Component**: cpp
**Tracker**: AZ-2147
**Epic**: AZ-2069

## Problem

Loop 12 feature assessment round 2 (`_docs/loops/loop12/assessment12.md` W1). The variadic `group(int id, children...)` with zero children makes a span-1 Group with no member access. `check_shape` (`cpp/include/packbin/order.hpp`) treats any span-1 group as a presence bit and accepts it under `flags` / a flag bit, but `present()` (`src/core/values.cpp`) can never find it on: `flags(0, group(0))` and `flag_byte(0), flag_bit(0, group(0))` compile, pack `0100`, and unpack of `0101` succeeds while the bit is dropped (same before loop 12). `README.md` says every package refuses this at construction.

## Owner decision (2026-10-05)

U3: A — any empty group that can never carry `true` fails construction wherever it stands. An empty group bound to a `bool` / `Opt<bool>` member stays a presence bit.

## Acceptance Criteria

**AC-1: member-less empty group refused**
Given `scheme<Row>(1, flags(0, group(0)))` and `scheme<Row>(1, flag_byte(0), flag_bit(0, group(0)))`
When validated
Then `SchemeInvalid` at field 0; a constexpr scheme of that shape is a compile error (`breaks_order<0>`)

**AC-2: bool-member empty group unchanged**
Given `flags(0, group<&Row::on>(0))` on an `Opt<bool>` member
When `true` / `false` are packed
Then `0101` / `0100`, and `0101` unpacks `on = true`

## Constraints

- No wire change for valid schemes; header-only change in `order.hpp`; compile-fail case in `tests/compile-fail/`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none | — | — | — |
