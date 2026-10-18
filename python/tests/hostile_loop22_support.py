from __future__ import annotations

from typing import Any

from packbin import (
    BinaryPacker,
    Scheme,
    bits,
    eq,
    flag_byte,
    flags,
    group,
    list as list_field,
    packed,
    repeat,
    sized,
    times,
    u8,
    u32,
    utf8,
    when,
)
from packbin._validate import _validate_round_bodies

# The ten cases of loop 22 (AZ-2417) in fixtures/hostile/cases.txt. The schemes and rows are the ones their
# README sections give, in Python builder syntax. Python runs all seven pack cases and all three construct cases.
# The construct schemes put the `when`s' source field `mode` outside the round, and Python's `Scheme` refuses
# that first (a `when` must name a field of its own scope), so the empty-body rule they pin is checked on the nodes,
# as test_empty_round_body.py does for rows 17 and 18; test_hostile_vectors.py also checks that `Scheme` refuses them.


def _u8(field_id: int, name: str) -> Any:
    return u8(field_id, lambda row, name=name: row[name])


def _scheme(*fields: Any) -> Scheme[Any]:
    return Scheme(1, dict, *fields)


def _novalue_count_scheme(member: str) -> Scheme[Any]:
    byte = flag_byte()
    consumers = {
        "bits": lambda: bits(2, lambda row: row["v"], 1),
        "packed": lambda: packed(1, 2, lambda row: row["v"], 1),
        "sized": lambda: sized(2, lambda row: row["v"], 1),
    }
    return _scheme(_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")), byte, byte.bit(consumers[member]()))


def _repeat_lone_scheme() -> Scheme[Any]:
    return _scheme(repeat(0, _u8(0, "a"), _u8(1, "b")))


def _repeat_when_scheme() -> Scheme[Any]:
    return _scheme(repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "v"))))


def _times_flags_scheme() -> Scheme[Any]:
    return _scheme(_u8(0, "c"), times(1, 0, flags(1, _u8(1, "v"))))


def _element_times_utf8_scheme() -> Scheme[Any]:
    return _scheme(
        list_field(
            lambda row: row["items"],
            group(0, u32(0, lambda row: row["n"]), times(1, 0, utf8(1, lambda row: row["s"]))),
        )
    )


def _pack(scheme: Scheme[Any], row: dict[str, Any]) -> bytes:
    return BinaryPacker.pack(scheme, row)


# case id -> (pack call, exception a `pack_error` case raises, None for a `bytes` case)
LOOP22_PACK_CASES = {
    "pack_novalue_count_clear_when_bits": (
        lambda: _pack(_novalue_count_scheme("bits"), {"mode": 0, "c": 3}),
        ValueError,
    ),
    "pack_novalue_count_clear_when_packed": (
        lambda: _pack(_novalue_count_scheme("packed"), {"mode": 0, "c": 3}),
        ValueError,
    ),
    "pack_novalue_count_clear_when_sized": (
        lambda: _pack(_novalue_count_scheme("sized"), {"mode": 0, "c": 3}),
        ValueError,
    ),
    "pack_repeat_unequal_lists_lone": (lambda: _pack(_repeat_lone_scheme(), {"a": [1, 2], "b": 7}), None),
    "pack_repeat_unequal_lists_when": (lambda: _pack(_repeat_when_scheme(), {"k": [1, 2], "v": [9]}), None),
    "pack_times_short_list_flags": (lambda: _pack(_times_flags_scheme(), {"c": 2, "v": [5]}), None),
    "pack_element_times_over_bytes_budget": (
        lambda: _pack(_element_times_utf8_scheme(), {"items": [{"n": 65535, "s": "q" * 16} for _ in range(16)]}),
        ValueError,
    ),
}


# The three `construct` schemes, spelled outside `Scheme`: `mode` (id 0) and `c` (id 1) stand in the outer scope.
def _empty_when_times_fields() -> tuple[Any, ...]:
    return (_u8(0, "mode"), _u8(1, "c"), times(2, 1, when(2, eq(0, 1))))


def _empty_when_repeat_fields() -> tuple[Any, ...]:
    return (_u8(0, "mode"), repeat(1, when(1, eq(0, 1))))


def _empty_nested_when_fields() -> tuple[Any, ...]:
    return (_u8(0, "mode"), _u8(1, "c"), times(2, 1, when(2, eq(0, 1), when(2, eq(0, 1)))))


LOOP22_CONSTRUCT_FIELDS = {
    "construct_empty_when_times_body": _empty_when_times_fields,
    "construct_empty_when_repeat_body": _empty_when_repeat_fields,
    "construct_empty_nested_when_body": _empty_nested_when_fields,
}

# case id -> build call of a `construct` case: the round-body rule on the nodes
LOOP22_CONSTRUCT_CASES = {
    case_id: (lambda fields=fields: _validate_round_bodies(list(fields())))
    for case_id, fields in LOOP22_CONSTRUCT_FIELDS.items()
}
