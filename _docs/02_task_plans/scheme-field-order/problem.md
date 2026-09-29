---
loop: 8
branch: loop/8-scheme-field-order
---

# Scheme field order

A caller numbers every value field, and the scheme constructor checks that those numbers are 0, 1, 2 along the field list. Groups that do not write a value hide that position. `repeat`, `when`, `times`, `flags`, and a group that continues the parent numbers take the next value-field number as an anchor. The anchor is not a new slot and it is not a byte on the wire. `repeat` still fills the rest of the packet with no count in front of the groups.

`list`, `dict`, and a nested group keep a separate numbering that starts at 0. A field after a list keeps the next parent number.

Every public way to build a Rust scheme runs the same check. A gap, a repeated id, an anchor that is not the next value id, or a `when` or borrowed count that names an id not yet walked fails before any byte is written.

## Change location

The scheme constructors in all six languages, and the order sentence next to “Field order is wire order.” The user said: add a positional argument to each field, an anchor id on `repeat`, `when`, `times`, and `flags`, the failure rule written next to the order sentence, and the Rust constructors running that walk. `list` and `dict` stay a nested 0.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A group that continues the parent numbers gets the same anchor as `repeat` | Caller | resolved | Medium |
| A nested group restarts at 0, same as `list` | Caller | resolved | Low |
| Existing call sites must pass the anchor | This loop | resolved | Medium |
