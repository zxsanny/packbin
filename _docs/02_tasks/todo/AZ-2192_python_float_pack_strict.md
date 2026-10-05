# Python pack refuses a string or bool for a float and names the field on f32 overflow

**Task**: AZ-2192_python_float_pack_strict
**Name**: Python float fields accept only numbers and name the field on overflow
**Description**: Pack raises `TypeError` naming the member for a string, bool or other non-number given to an `f32` or `f64` field, and raises an error naming the member when a finite value does not fit `f32`.
**Complexity**: 1 point
**Dependencies**: AZ-2083_python_bool_flag_limit (same pack module; land in order)
**Component**: python
**Tracker**: AZ-2192
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X9, T7, C15); resolves AZ-2084 Flagged concern 1 ("Python accepts numeric strings for floats; TypeScript will refuse them").

- Python converts whatever it is given with `float(...)`. Probes on the current code, `Scheme(1, dict, f64(0, ...))` unless noted:

| Value | Today | Should be |
|-------|-------|-----------|
| `"1.5"` | packs `01 00 00 00 00 00 00 f8 3f` | `TypeError` naming the field |
| `"abc"` | `ValueError: could not convert string to float` (no field) | `TypeError` naming the field |
| `True` | packs `01 00 00 00 00 00 00 f0 3f` | `TypeError` naming the field |
| `b"1"` | packs `01 00 00 00 00 00 00 f0 3f` | `TypeError` naming the field |
| `f32` `1e39`, `-1e39`, `3.5e38` | `OverflowError: float too large to pack with f format` (no field) | error naming the field |

- Integer fields already refuse a bool or a non-int with a message that names the field (`0: expected int, got float`) and an out-of-range value with `OverflowError("0: 300 does not fit in u8")`. TypeScript refuses all of these for floats (AZ-2084 AC-3, AC-4).
- The same conversion runs for a float inside a `list`, `dict` or `times` element: `{"xs": ["1.5"]}` packs today.

## Outcome

- A float field accepts an `int` or a `float` (not a bool); anything else raises `TypeError` naming the field and the type it got.
- A finite value that does not fit `f32` raises `OverflowError` naming the field, like the integer path.
- `inf`, `-inf` and `nan` given explicitly are written, and every valid value keeps its bytes.

## Scope

### Included
- `f32` and `f64` at the top level, under `flags`, `when`, `times`, and as list or dict elements.
- Tests for the probes below.

### Excluded
- Integer fields (already strict); unpack.
- Other error labels (C15): Python names a member by its field id, as its other pack errors do.
- An integer too large for any float (`10**400`) also raises an unnamed `OverflowError` today; see the flagged concern.

## Acceptance Criteria

**AC-1: A string is refused**
Given `f64(0, ...)`, and `f32(0, ...)`, and a `list` of `f32`
When `"1.5"` and `"abc"` are packed into each
Then each raises `TypeError` whose message names field 0 and `str`, and no bytes are returned.

**AC-2: A bool is refused**
Given `f64(0, ...)` and `f32(0, ...)`
When `True` and `False` are packed
Then each raises `TypeError` naming field 0 and `bool`.

**AC-3: Other non-numbers are refused**
Given `f64(0, ...)`
When `b"1"` is packed
Then it raises `TypeError` naming field 0 and `bytes`; `None` still raises `KeyError` `missing field 0`, as today.

**AC-4: `f32` overflow names the field**
Given `f32(0, ...)`, and a `list` of `f32`
When `1e39`, `-1e39` and `3.5e38` are packed
Then each raises `OverflowError` whose message names field 0 and `f32`; `3.4028235e38` packs `01 ff ff 7f 7f`.

**AC-5: Valid values are unchanged**
Given `f64(0, ...)` and `f32(0, ...)`
When the following are packed: `f64` `3`, `1.5`, `-0.0`, `inf`, `nan`; `f32` `1.5`, `inf`, `nan`
Then the bytes are `01 00 00 00 00 00 00 08 40`, `01 00 00 00 00 00 00 f8 3f`, `01 00 00 00 00 00 00 00 80`, `01 00 00 00 00 00 00 f0 7f`, `01 00 00 00 00 00 00 f8 7f`, `01 00 00 c0 3f`, `01 00 00 80 7f` and `01 00 00 c0 7f`.

**AC-6: Round trip and README example**
Given `f32` with `{"x": 1.5}` (the README Floats example) and the wire `01 00 00 c0 3f`
When the row is packed, and the wire is unpacked and packed again
Then the bytes are `01 00 00 c0 3f` both times.

## Non-Functional Requirements

**Compatibility**
- Wire bytes of every value that packed as a number are unchanged.

**Reliability**
- A float field never holds a value other than the number the caller passed.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `"1.5"`, `"abc"` into `f64`, `f32`, list element | `TypeError` names field 0 (packs `1.5` today; `"abc"` was an unnamed `ValueError`) |
| AC-2 | `True`, `False` into `f32`, `f64` | `TypeError` names field 0 (packs 1.0 and 0.0 today) |
| AC-3 | `b"1"`; `None` | `TypeError` names field 0; `KeyError` unchanged |
| AC-4 | `1e39`, `-1e39`, `3.5e38`; `3.4028235e38` | `OverflowError` names field 0 and `f32`; `01 ff ff 7f 7f` |
| AC-5 | values listed | bytes as listed |
| AC-6 | README example, unpack and repack | `01 00 00 c0 3f` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-5 | `fixtures/golden.hex`, route fixture, `language-pair.sh` rings | Python producer and consumer | unchanged hex; 0 mismatched bytes | Compatibility |

## Constraints

- ADR-001: Python only; mirror TypeScript AZ-2084 (number only; overflow refused; explicit specials written); do not share code.
- Error types: `TypeError` for a wrong type (as the integer path), `OverflowError` for overflow (as the integer path, so callers that catch it keep working).
- No public API change. Wire bytes in the ACs come from probes of the current code and the IEEE 754 layout; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A caller passed a numeric string, `Decimal` or `Fraction`**
- *Risk*: rows that packed through `float(...)` now raise `TypeError`.
- *Mitigation*: the message names the field and the type; README upgrade note; TypeScript already refuses them.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `Decimal` and `Fraction` pack today (probe: both give `01 00 00 00 00 00 00 f8 3f` for 1.5). These ACs refuse them with every non-number (as TypeScript and the integer path do); the owner confirms before implementation | owner | open | Low |
| An integer too large for any float (`10**400` into `f64`) raises `OverflowError: int too large to convert to float` with no field. Folding it into AC-4 is one line; left out because the ticket names only `f32` | owner | open | Low |
