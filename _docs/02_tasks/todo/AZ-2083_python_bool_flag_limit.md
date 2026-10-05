---
loop: 12
---

# Python bool only inside flags and 8-bit flag limit

**Task**: AZ-2083_python_bool_flag_limit
**Name**: Python bool placement and flag-bit limit
**Description**: A `bool` is accepted only as the direct field of a flag bit, and `flags(...)` with more than 8 children fails at construction.
**Complexity**: 1 point
**Dependencies**: AZ-2071_python_hostile_unpack (same modules; land in order)
**Component**: python
**Tracker**: AZ-2083
**Epic**: AZ-2069

## Problem

Python already sets a `bool` bit only for `True` (`_pack.py:46-47`, `_bool_on` is `value is True`). `{on: False}` packs `0100`, which matches the decision. Two gaps remain. Both were reproduced on `d108141`.

**1. A `bool` outside `flags` is accepted and silently means nothing.**
- `_validate_order` (`_nodes.py:400-424`) accepts `_Bool` anywhere. Pack records it in `seen` and writes nothing (`_pack.py:197-198`). Unpack skips it (`_unpack.py:220-221`, `pass`).
- With `Scheme(1, dict, u8(0, a), bool(1, on))`, `{a: 1, on: True}` packs `0101` and unpacks `{'a': 1}`: the `True` is lost with no error.
- In a group under flags, `flags(0, group(0, u8(0, n), bool(1, on)))`, the group's bit is set from `on`, but unpack of the group's fields hits the same `pass`, so `on` never comes back.
- As a list/dict element, `list(xs, bool(0, ·))` writes only the count. Unpack yields `True` for every item (`_unpack.py:122-123`).
- TypeScript and C# turn a bool outside flags into `True` on unpack. All three disagree.

**2. A ninth `flags` child is accepted at construction.** `flags(anchor, *fields)` (`_nodes.py:318-319`) has no limit, unlike `_FlagByte.bit` (`_nodes.py:101-106`, which raises `ValueError("flags already has 8 bits")`). With nine `u8` children and row `{"f8": 7}`, pack raises `ValueError: byte must be in range(0, 256)` from `bytearray.append` (`_pack.py:200-204`). If `f8` is absent, the scheme packs and unpacks normally, so the error depends on data. TypeScript writes undecodable bytes (`010007`, task 11). C++ and Java reject at construction.

## User decision (2026-10-05), applied verbatim

> The flags bit is set only for `true`; `false` and absent leave it clear. A `bool` (and an empty group) is allowed only inside `flags` / a flag byte — anywhere else is a scheme construction error.

## Outcome

- `Scheme(...)` raises `ValueError` naming the field id when a `bool` is anywhere except the direct child of `flags(...)` or the field of a flag-byte bit.
- `flags(...)` with 9 or more children raises `ValueError` at declaration (at the latest in `Scheme(...)`), naming the anchor.
- Existing behavior for bools inside flags is unchanged: `True` → bit set, `False`/`None`/absent → clear, unpack sets `True` only when the bit is set.

## Scope

### Included
- Placement check for `_Bool`: top level, inside a group (anchored or not, under flags or not), inside `when`/`repeat`/`times`, and as a list/dict element are all errors.
- Ninth-child check on `flags(...)`.
- The split form (`flag_byte().bit(bool(...))`) is accepted by this rule. Its round trip is tested in task 31, because split form cannot be constructed until then.

### Excluded
- Empty `group(anchor)` with no fields. Python has no accessor on `group`, so an empty group carries no value. See the flagged concern.
- Split-form validation and unpack (task 31).
- Error labels (C15).

## Acceptance Criteria

**AC-1: bool inside flags unchanged**
Given `Scheme(1, dict, flags(0, bool(0, lambda r: r["on"]), u8(1, lambda r: r["n"])))`
When `{"on": True, "n": 7}`, `{"on": False}` and `{}` are packed
Then the bytes are `010307`, `0100` and `0100`, and `010307` unpacks to `{"on": True, "n": 7}`

**AC-2: bool at top level is a scheme error**
Given `u8(0, a)`, `bool(1, on)`
When `Scheme(...)` is constructed
Then `ValueError` is raised and its message contains `1`

**AC-3: bool in a group, when, repeat, times or element is a scheme error**
Given a `bool` inside `group(...)` (also under flags), `when(...)`, `repeat(...)`, `times(...)`, or as the element of `list(...)`/`dict(...)`
When `Scheme(...)` is constructed
Then `ValueError` is raised for each

**AC-4: ninth flags child is a scheme error**
Given `flags(0, u8(0, ·), …, u8(8, ·))` (nine children)
When the scheme is declared
Then `ValueError` is raised before any pack; eight children still construct and pack

**AC-5: fixtures unchanged**
Given the golden row and the route fixture (which uses `bool` inside `flags`)
When packed and unpacked
Then the bytes are `4001000065cd1d00a3e1110100` and `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101`

## Non-Functional Requirements

**Compatibility**
- No wire change. Only schemes that silently dropped data stop constructing.

## Unit Tests

| AC Ref | Test name | Input | Required outcome |
|--------|-----------|-------|------------------|
| AC-1 | `test_bool_in_flags_true_false_absent` | 3 rows | `010307`, `0100`, `0100`; round trip |
| AC-2 | `test_bool_top_level_is_scheme_error` | `u8(0)`, `bool(1)` | `ValueError` (fails today: constructs) |
| AC-3 | `test_bool_in_group_when_repeat_times_element_is_scheme_error` | 6 schemes | `ValueError` each |
| AC-4 | `test_ninth_flags_child_is_scheme_error` | 9 children | `ValueError` at construction (today: only at pack with `f8` set) |
| AC-4 | `test_eight_flags_children_pack` | 8 children, `{"f7": 1}` | `018001` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 | cross-language bool vector (C01) | pack `{on: False}` | `0100`, same as TS/C# after tasks 10/11 | project AC-3 |
| AC-5 | `fixtures/golden.hex`, route fixture, language-pair handoffs | unchanged runs | bytes unchanged | project AC-1/3 |
| — | `fixtures/hostile/` (task 01) | all vectors | still errors | Reliability |

## Constraints

- ADR-001: Python only.
- `ValueError` for scheme errors, matching the existing order errors (`_nodes.py:404`, `414`).
- No new runtime dependency.

## Risks & Mitigation

**Risk 1: An existing script has a bool outside flags**
- *Risk*: It stops constructing.
- *Mitigation*: That bool never reached the wire. The error message says to move it into `flags`.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Python `group(anchor)` with no fields can never set its bit (it has no member to read), so the decision's "empty group inside flags" has no Python meaning. This task leaves it unchanged | user decision 2026-10-05 | open | Low |
| "Inside flags" is read as the direct field of a flag bit (a bool inside a group under flags is rejected) | user decision (interpretation) | open | Low |
