from __future__ import annotations

# The rule each refused case in fixtures/hostile/cases.txt must name (AZ-2392), so a refusal by some other rule
# does not pass. The error type and the message are Python's own (README: the vector asserts only that pack or
# the build refused); they are pinned here, one entry per `pack_error` case and per `construct` case.
# A message is compared whole, so a text that only differs in the field id or the count names another rule.

_AFTER_BYTE = " (it was skipped, or is written after the flag byte that decides this bit)"
_NO_MEMBER = "{kind} {anchor}: the body holds no member; a round of it would charge no slot and write nothing"
_NO_VALUE = (
    "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member "
    "reads nothing; give the count 0, leave it out, or make the when hold"
)
_LATER = "is allowed only if declared earlier in the same scope"

# id -> (exception type, message)
PACK_REFUSAL: dict[str, tuple[type[Exception], str]] = {
    "pack_out_of_range_integer": (OverflowError, "0: 300 does not fit in u8"),
    "pack_missing_required_value": (KeyError, "'missing field 1'"),
    "pack_times_list_too_long": (ValueError, "1: 3 items, times count is 2"),
    "pack_times_list_too_short": (ValueError, "1: 1 items, times count is 2"),
    "pack_times_count_over_limit": (
        ValueError,
        "x: the times count is 65536, above the limit of 65535 rounds",
    ),
    "pack_times_zero_with_values": (ValueError, "1: 1 items, times count is 0"),
    "pack_split_when_source_after_byte": (
        ValueError,
        "when 1: a body value is given, but condition field 0 is written after the flag byte that decides this bit",
    ),
    "pack_split_times_count_after_byte": (
        ValueError,
        "times 1: body values are given, but count field 0 has no value" + _AFTER_BYTE,
    ),
    "pack_split_times_count_skipped": (
        ValueError,
        "times 2: body values are given, but count field 1 has no value" + _AFTER_BYTE,
    ),
    "pack_lone_bytes_in_round": (
        TypeError,
        "member d: a byte buffer in a repeat or times round must be a list with one buffer per round, "
        "got a single buffer",
    ),
    "pack_lone_utf8_under_times_over_budget": (
        ValueError,
        "s: the packet would be 16777477 bytes, above the limit of 16777216 bytes",
    ),
    "pack_element_times_over_budget": (
        ValueError,
        "k: the rounds would hold 1048577 slots, above the limit of 1048576 slots",
    ),
    "pack_slots_over_limit": (
        ValueError,
        "m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots",
    ),
    "pack_repeat_over_limit": (ValueError, "k: the repeat count is 65536, above the limit of 65535 rounds"),
    "pack_split_count_zero_after_byte_list": (ValueError, "1: 2 items, times count is 0"),
    "pack_flags_skipped_count_with_values": (
        ValueError,
        "pt: a value is given, but the count of its times is not written, so its bit is clear; "
        "write the count before the times",
    ),
    "pack_round_slots_over_limit": (
        ValueError,
        "b: the rounds would hold 4 slots, above the limit of 3 slots",
    ),
    "pack_round_slots_flags_over_limit": (
        ValueError,
        "on: the rounds would hold 6 slots, above the limit of 4 slots",
    ),
    "pack_flags_short_list": (
        ValueError,
        "v: 1 items, repeat count 2; give one entry per round, None where the member is absent",
    ),
    "pack_count_one_clear_when": (
        ValueError,
        "pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear), so its times "
        "reads no round; give the count 0, leave it out, or make the when hold",
    ),
    "pack_element_times_over_bytes_budget": (
        ValueError,
        "s: the packet would be 16777233 bytes, above the limit of 16777216 bytes",
    ),
    "pack_bits_count_clear_when": (RuntimeError, "2: count 1 is missing"),
    "pack_packed_count_clear_when": (RuntimeError, "2: count is missing"),
    "pack_sized_count_clear_when": (RuntimeError, "2: count 1 is missing"),
    "pack_novalue_count_clear_when_bits": (ValueError, _NO_VALUE),
    "pack_novalue_count_clear_when_packed": (ValueError, _NO_VALUE),
    "pack_novalue_count_clear_when_sized": (ValueError, _NO_VALUE),
}

# id -> message of the ValueError the build raises
CONSTRUCT_REFUSAL: dict[str, str] = {
    "nine_flag_bits": "flags 0 has 9 children; one flags byte holds 8 bits",
    "nine_flag_bits_split": "flags already has 8 bits",
    "when_names_later_field": "when 1: eq names field id 2 " + _LATER,
    "count_names_later_field": "sized 0: count field id 1 " + _LATER,
    "when_names_outer_field_in_repeat": "when 1: eq names field id 0 " + _LATER,
    "bool_outside_flags": "field id 1: bool is allowed only as a direct child of flags or a flag-byte bit",
    "empty_group_outside_flags": "group 1 has no fields, so it can never carry a value",
    "eq_bool_false": "when 1: eq tests bool field 0 against False; a bool is compared only with true",
    "eq_out_of_range": "when 1: eq tests u8 field 0 against 300, which is outside 0..255",
    "construct_empty_times_body": _NO_MEMBER.format(kind="times", anchor=1),
    "construct_empty_repeat_body": _NO_MEMBER.format(kind="repeat", anchor=0),
    "construct_empty_round_body_list_element": _NO_MEMBER.format(kind="times", anchor=1),
    "construct_empty_when_times_body": _NO_MEMBER.format(kind="times", anchor=2),
    "construct_empty_when_repeat_body": _NO_MEMBER.format(kind="repeat", anchor=1),
    "construct_empty_nested_when_body": _NO_MEMBER.format(kind="times", anchor=2),
}
