from __future__ import annotations

from dataclasses import dataclass

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bool as flag_bool,
    eq,
    flag_byte,
    flags,
    group,
    i32,
    list as list_field,
    repeat,
    times,
    u2,
    u8,
    u16,
    when,
)

TRAIL = "0101000a000000140000001e00000028000000"
TIMES_TRAIL = "01020a000000140000001e00000028000000"


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _on(field_id: int):
    return flag_bool(field_id, lambda row: row["on"])


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


@dataclass
class Trail:
    sid: int = 0
    lat: object = 0
    lon: object = 0


def _trail_scheme(row_type) -> Scheme:
    return Scheme(
        1,
        row_type,
        u16(0, lambda row: row.sid),
        repeat(1, i32(1, lambda row: row.lat), i32(2, lambda row: row.lon)),
    )


def test_ac4_repeat_ignores_row_defaults():
    scheme = _trail_scheme(Trail)

    result = _unpack(scheme, TRAIL)

    assert result.ok
    assert (result.value.lat, result.value.lon) == ([10, 30], [20, 40])


def test_ac5_repeat_does_not_mutate_class_list():
    class SharedTrail:
        sid = 0
        lat: list = []
        lon: list = []

    scheme = _trail_scheme(SharedTrail)

    first = _unpack(scheme, TRAIL)
    second = _unpack(scheme, TRAIL)

    assert first.value.lat == [10, 30]
    assert second.value.lat == [10, 30]
    assert SharedTrail.lat == []
    assert SharedTrail.lon == []


def test_ac6_times_ignores_row_defaults():
    @dataclass
    class Counted:
        n: int = 0
        lat: object = 0
        lon: object = 0

    scheme = Scheme(
        1,
        Counted,
        u8(0, lambda row: row.n),
        times(1, 0, i32(1, lambda row: row.lat), i32(2, lambda row: row.lon)),
    )

    result = _unpack(scheme, TIMES_TRAIL)

    assert result.ok
    assert (result.value.lat, result.value.lon) == ([10, 30], [20, 40])


def test_a_dataclass_row_with_a_repeat_list_packs_again():
    scheme = _trail_scheme(Trail)
    result = _unpack(scheme, TRAIL)

    packed = BinaryPacker.pack(scheme, result.value).hex()

    assert packed == TRAIL


def test_ac7_repeat_with_flags_packs():
    scheme = Scheme(1, dict, _u8(0, "a"), repeat(1, flags(1, _u8(1, "v"))))

    packed = _pack(scheme, {"a": 1, "v": [1, None]})
    result = _unpack(scheme, packed)

    assert packed == "0101010100"
    assert result.ok
    assert result.value["v"] == [1, None]


def test_ac8_times_with_flags_per_item():
    scheme = Scheme(1, dict, _u8(0, "n"), times(1, 0, flags(1, _u8(1, "v"))))

    packed = _pack(scheme, {"n": 2, "v": [5, None]})

    assert packed == "0102010500"


def test_repeat_with_a_when_packs_per_item():
    scheme = Scheme(1, dict, repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "v"))))

    packed = _pack(scheme, {"k": [1, 0], "v": [9, None]})
    result = _unpack(scheme, packed)

    assert packed == "01010900"
    assert result.ok
    assert result.value == {"k": [1, 0], "v": [9, None]}


def test_repeat_with_a_group_packs_per_item():
    scheme = Scheme(1, dict, repeat(0, group(0, _u8(0, "x"), _u8(1, "y"))))

    packed = _pack(scheme, {"x": [1, 2], "y": [3, 4]})
    result = _unpack(scheme, packed)

    assert packed == "0101030204"
    assert result.value == {"x": [1, 2], "y": [3, 4]}


def test_times_with_a_group_under_flags_packs_per_item():
    scheme = Scheme(1, dict, _u8(0, "n"), times(1, 0, flags(1, group(1, _u8(1, "x"), _u8(2, "y")))))

    packed = _pack(scheme, {"n": 2, "x": [1, None], "y": [3, None]})

    assert packed == "0102" + "0101" + "03" + "00"


def test_repeat_with_u2_slots_packs_per_item():
    scheme = Scheme(1, dict, repeat(0, u2((0, lambda row: row["p"]), (1, lambda row: row["q"]))))

    packed = _pack(scheme, {"p": [1, 2], "q": [3, 0]})
    result = _unpack(scheme, packed)

    assert packed == "010d02"
    assert result.value == {"p": [1, 2], "q": [3, 0]}


def test_ac_aligned_1_repeat_flags_keep_one_entry_per_round():
    scheme = Scheme(1, dict, repeat(0, flags(0, _on(0), _u8(1, "n"))))
    row = {"on": [True, False, True], "n": [1, 2, 3]}

    packed = _pack(scheme, row)
    result = _unpack(scheme, packed)

    assert packed == "01030102020303"
    assert result.ok
    assert result.value == {"on": [True, None, True], "n": [1, 2, 3]}
    assert _pack(scheme, result.value) == packed


def test_ac_aligned_2_times_flags_keep_one_entry_per_round():
    scheme = Scheme(1, dict, _u8(0, "c"), times(1, 0, flags(1, _on(1), _u8(2, "n"))))
    row = {"c": 3, "on": [True, False, True], "n": [1, 2, 3]}

    packed = _pack(scheme, row)
    result = _unpack(scheme, packed)

    assert packed == "0103030102020303"
    assert result.ok
    assert result.value == {"c": 3, "on": [True, None, True], "n": [1, 2, 3]}
    assert _pack(scheme, result.value) == packed


def test_times_bool_under_flags_reads_its_own_round():
    scheme = Scheme(1, dict, _u8(0, "a"), times(1, 0, flags(1, _on(1))))

    packed = _pack(scheme, {"a": 2, "on": [True, False]})

    assert packed == "01020100"


def test_aligned_when_body_shows_none_for_the_round_that_skipped_it():
    scheme = Scheme(1, dict, repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "v"))))

    result = _unpack(scheme, "01" "01" "09" "02")

    assert result.ok
    assert result.value == {"k": [1, 2], "v": [9, None]}


def test_repeat_that_reads_no_round_leaves_the_row_as_it_was():
    scheme = Scheme(1, dict, _u8(0, "a"), repeat(1, _u8(1, "x")))

    result = _unpack(scheme, "0107")

    assert result.ok
    assert result.value == {"a": 7}


def test_repeat_lists_of_unequal_length_are_refused():
    scheme = Scheme(1, dict, repeat(0, _u8(0, "x"), _u8(1, "y")))

    with pytest.raises(ValueError, match="equal lengths"):
        _pack(scheme, {"x": [1, 2], "y": [3]})


def test_repeat_a_none_entry_in_the_middle_skips_only_that_rounds_value():
    scheme = Scheme(1, dict, repeat(0, _u8(0, "x"), flags(1, _u8(1, "n"))))

    packed = _pack(scheme, {"x": [1, 2], "n": [5, None]})
    result = _unpack(scheme, packed)

    assert packed == "010101050200"
    assert result.value == {"x": [1, 2], "n": [5, None]}


def test_repeat_split_form_bool_keeps_one_entry_per_round():
    flag = flag_byte()
    scheme = Scheme(1, dict, repeat(0, flag, flag.bit(_on(0))))

    packed = _pack(scheme, {"on": [True, False, True]})
    result = _unpack(scheme, packed)

    assert packed == "01010001"
    assert result.value == {"on": [True, None, True]}


NESTED_ROUNDS = {
    "repeat_in_repeat": lambda: Scheme(1, dict, repeat(0, repeat(0, _u8(0, "v")))),
    "times_in_repeat": lambda: Scheme(1, dict, repeat(0, _u8(0, "c"), times(1, 0, _u8(1, "v")))),
    "repeat_in_times": lambda: Scheme(
        1, dict, _u8(0, "n"), times(1, 0, _u8(1, "c"), repeat(2, _u8(2, "v")))
    ),
    "times_in_times": lambda: Scheme(
        1, dict, _u8(0, "n"), times(1, 0, _u8(1, "c"), times(2, 1, _u8(2, "v")))
    ),
    "under_when": lambda: Scheme(
        1, dict, repeat(0, _u8(0, "c"), when(1, eq(0, 1), repeat(1, _u8(1, "v"))))
    ),
    "under_flags": lambda: Scheme(1, dict, repeat(0, flags(0, repeat(0, _u8(0, "v"))))),
    "under_group": lambda: Scheme(1, dict, repeat(0, group(0, repeat(0, _u8(0, "v"))))),
    "under_flag_bit": lambda: _nested_under_flag_bit(),
}


def _nested_under_flag_bit() -> Scheme:
    flag = flag_byte()
    return Scheme(1, dict, repeat(0, flag, flag.bit(repeat(0, _u8(0, "v")))))


@pytest.mark.parametrize("place", sorted(NESTED_ROUNDS))
def test_repeat_holding_another_round_is_refused_at_construction(place: str):
    with pytest.raises(ValueError, match="inside a repeat or times round"):
        NESTED_ROUNDS[place]()


def test_a_round_inside_a_list_element_of_a_round_is_not_nested():
    scheme = Scheme(
        1,
        dict,
        repeat(0, list_field(lambda row: row["xs"], group(0, repeat(0, _u8(0, "v"))))),
    )

    assert scheme is not None
