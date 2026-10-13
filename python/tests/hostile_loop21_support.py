from __future__ import annotations

from typing import Any

from packbin import (
    BinaryPacker,
    Scheme,
    bits,
    bool as flag_bool,
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
    u16,
    u32,
    when,
)

# The fifteen cases of loop 21 (AZ-2394) in fixtures/hostile/cases.txt. The schemes and rows are the ones their
# README sections give, in Python builder syntax. Python has no named group: the `when`s of
# pack_late_when_in_bit_body sit in an anchored group inside the bit, and the list element of
# construct_empty_round_body_list_element is an anchored group.


def _u8(field_id: int, name: str) -> Any:
    return u8(field_id, lambda row, name=name: row[name])


def _scheme(*fields: Any) -> Scheme[Any]:
    return Scheme(1, dict, *fields)


def _slots_scheme() -> Scheme[Any]:
    return _scheme(
        _u8(0, "n"),
        times(1, 0, _u8(1, "a")),
        repeat(2, _u8(2, "b")),
    ).with_limits(max_slots=3)


def _flags_round_scheme() -> Scheme[Any]:
    return _scheme(
        repeat(0, flags(0, flag_bool(0, lambda row: row["on"]), _u8(1, "v"))),
    ).with_limits(max_slots=4)


def _short_list_scheme() -> Scheme[Any]:
    return _scheme(repeat(0, _u8(0, "w"), flags(1, _u8(1, "v"))))


def _split_times_scheme() -> Scheme[Any]:
    byte = flag_byte()
    return _scheme(
        byte,
        _u8(0, "n"),
        byte.bit(times(1, 0, _u8(1, "pt"))),
        byte.bit(u16(2, lambda row: row["heading"])),
    )


def _late_when_scheme() -> Scheme[Any]:
    byte = flag_byte()
    return _scheme(
        byte,
        _u8(0, "mode"),
        byte.bit(
            group(
                1,
                _u8(1, "d"),
                when(2, eq(0, 1), _u8(2, "a")),
                when(3, eq(0, 2), _u8(3, "b")),
            )
        ),
    )


def _count_one_scheme() -> Scheme[Any]:
    byte = flag_byte()
    return _scheme(
        _u8(0, "mode"),
        when(1, eq(0, 1), _u8(1, "c")),
        byte,
        byte.bit(times(2, 1, _u8(2, "pt"))),
        byte.bit(u16(3, lambda row: row["heading"])),
    )


def _counted_scheme(member: str) -> Scheme[Any]:
    consumers = {
        "bits": lambda: bits(2, lambda row: row["v"], 1),
        "packed": lambda: packed(1, 2, lambda row: row["v"], 1),
        "sized": lambda: sized(2, lambda row: row["v"], 1),
    }
    return _scheme(_u8(0, "mode"), when(1, eq(0, 1), _u8(1, "c")), consumers[member]())


def _pack(scheme: Scheme[Any], row: dict[str, Any]) -> bytes:
    return BinaryPacker.pack(scheme, row)


# case id -> (pack call, exception a `pack_error` case raises, None for a `bytes` case)
LOOP21_PACK_CASES = {
    "pack_round_slots_at_limit": (lambda: _pack(_slots_scheme(), {"n": 1, "a": [1], "b": [2, 3]}), None),
    "pack_round_slots_over_limit": (lambda: _pack(_slots_scheme(), {"n": 1, "a": [1], "b": [2, 3, 4]}), ValueError),
    "pack_round_slots_flags_at_limit": (
        lambda: _pack(_flags_round_scheme(), {"on": [True, True], "v": [5, 6]}),
        None,
    ),
    "pack_round_slots_flags_over_limit": (
        lambda: _pack(_flags_round_scheme(), {"on": [True, True, True], "v": [5, 6, 7]}),
        ValueError,
    ),
    "pack_flags_short_list": (lambda: _pack(_short_list_scheme(), {"w": [1, 2], "v": [5]}), ValueError),
    "pack_flags_short_list_filled": (lambda: _pack(_short_list_scheme(), {"w": [1, 2], "v": [5, None]}), None),
    "pack_split_times_absent_body": (lambda: _pack(_split_times_scheme(), {"n": 2, "heading": 90}), None),
    "pack_late_when_in_bit_body": (lambda: _pack(_late_when_scheme(), {"mode": 1, "d": 5, "a": 9}), None),
    "pack_count_one_clear_when": (
        lambda: _pack(_count_one_scheme(), {"mode": 0, "c": 1, "heading": 90}),
        ValueError,
    ),
    "pack_bits_count_clear_when": (
        lambda: _pack(_counted_scheme("bits"), {"mode": 0, "c": 3, "v": [1, 0, 1]}),
        ValueError,
    ),
    "pack_packed_count_clear_when": (
        lambda: _pack(_counted_scheme("packed"), {"mode": 0, "c": 3, "v": [1, 0, 1]}),
        ValueError,
    ),
    "pack_sized_count_clear_when": (
        lambda: _pack(_counted_scheme("sized"), {"mode": 0, "c": 3, "v": b"\x01\x02\x03"}),
        ValueError,
    ),
}

# case id -> build call of a `construct` case
LOOP21_CONSTRUCT_CASES = {
    "construct_empty_times_body": lambda: _scheme(_u8(0, "n"), times(1, 0)),
    "construct_empty_repeat_body": lambda: _scheme(repeat(0)),
    "construct_empty_round_body_list_element": lambda: _scheme(
        list_field(lambda row: row["items"], group(0, u32(0, lambda row: row["n"]), times(1, 0)))
    ),
}
