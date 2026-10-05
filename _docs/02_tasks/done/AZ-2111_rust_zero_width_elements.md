---
loop: 11
---

# Rust zero-width list and dict elements and orphan flag bits

**Task**: AZ-2111_rust_zero_width_elements
**Name**: Rust zero-width elements and orphan flag bits
**Description**: A list or dict element that reads 0 bytes returns the interim error at unpack, and a split flag bit without its flag byte in scope is a scheme construction error.
**Complexity**: 3 points
**Dependencies**: None
**Component**: rust
**Tracker**: AZ-2111
**Epic**: AZ-2069

## Problem

Loop 11 made a zero-progress `repeat` and `times` round an error. List and dict elements have the same shape: `list(list(bytes(0)))` lets a packet of about 131 KB ask for 65 535 x 65 535 empty items, and every item is stored. Measured in Rust: a 163-byte packet took 429 ms; extrapolated to the full count it is minutes of CPU and tens of GB. The zero-width forms built by `bool` or an empty group are already construction errors through AZ-2079, AZ-2080, AZ-2082, AZ-2083 and AZ-2089; `bytes(0)` and an element whose `when` never matches are not covered by any ticket.

A split-form flag bit whose flag byte is never read in its scope (the byte sits inside a `when` that did not match, or outside the list element) is read as clear today in Rust (feature-assess U2). Decision (2026-10-05): refuse it at construction in every package.

## Outcome

- An element that reads 0 bytes in a list or dict returns the interim error (same shape as the `times` zero-width error in this package: bad-value result, `needed` 0, `left` = bytes left at the start of that element), no value, handler not called, in under 1 s with bounded memory.
- A list or dict count of 0 with a zero-width element scheme still unpacks to an empty list/dict.
- Wire bytes are unchanged for every packet that unpacked before and read at least one byte per element.

## Scope

### Included
- Unpack of `list` and `dict` elements in clear and session unpack.
- A split flag bit must have its flag byte in the same scope (same `when`-free container: top level, repeat round, times round, list or dict element), checked when the scheme is built.
- Tests that read the same shapes in this package; the shared vector file is not changed.

### Excluded
- Error kind and label of the error value (C15).
- `bool` and empty-group construction rules (AZ-2079, AZ-2080, AZ-2082, AZ-2083, AZ-2089).
- The u16 list and dict count limits.

## Acceptance Criteria

**AC-1: Zero-width list element**
Given a list whose element is a zero-width `bytes(0)` inside an outer list
When `01ffffffff` (outer count 65 535, inner count 65 535) is unpacked
Then the call returns an error within 1 s, no value, handler not called

**AC-2: Zero-width dict value**
Given a dict whose value is zero-width
When a packet with dict count `ffff` and one key is unpacked
Then the call returns an error within 1 s, no value

**AC-3: Element that is zero-width only for some packets**
Given a list element made of a `when` that never matches
When a packet with a non-zero count is unpacked
Then the call returns the same error

**AC-4: Valid packets unchanged**
Given every existing list and dict test, the golden vector and the language-pair handoffs
When they run
Then they pass unchanged; a count of 0 with a zero-width element scheme (`01 0000`) unpacks to an empty list

**AC-5: Orphan flag bit is a construction error**
Given a split flag byte inside a `when` (or outside the list element) and a `.bit(...)` field outside that scope
When the scheme is built
Then building fails naming the flag bit; a flag byte and its bits in the same scope still build, pack and unpack to the same bytes as before

## Unit Tests

Write these first. They must fail on the current code. Guard hang tests with the package's existing time guard.

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `zero_width_list_element_is_error` | `01ffffffff` | error, < 1 s |
| AC-2 | `zero_width_dict_value_is_error` | dict count `ffff` | error, < 1 s |
| AC-3 | `never_matching_when_element_is_error` | count 3 | error |
| AC-4 | `empty_list_of_zero_width_still_unpacks` | `010000` | ok, empty list |
| AC-5 | `orphan_flag_bit_is_construction_error`, `same_scope_flag_bit_still_builds` | byte in a false-able `when`, bit outside; byte and bit together | first fails construction naming the bit; second builds |

## Constraints

- ADR-001: the fix is in this package's walker only; no import from another package.
- No new public error type before C15; use the package's existing interim bad-value helper.
- Files stay at or under 500 lines (split by responsibility).

## Risks & Mitigation

**Risk 1: A real schema relied on an empty element**
- *Risk*: A scheme whose list element can be empty now errors instead of returning empty items.
- *Mitigation*: Such a packet could never carry data; the error names the element start.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Error kind and label are undecided (C15) | user / C15 | open | Medium |
