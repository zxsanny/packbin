from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bool as flag_bool,
    eq,
    flag_byte,
    flags,
    group,
    repeat,
    times,
    u2,
    u8,
    when,
)


def _key(name: str):
    return lambda row, name=name: row[name]


def _u8(id_: int, name: str):
    return u8(id_, _key(name))


def _bool(id_: int, name: str):
    return flag_bool(id_, _key(name))


def _slot(id_: int, name: str):
    return (id_, _key(name))


def _timed(*body) -> Scheme:
    return Scheme(1, dict, _u8(0, "c"), times(1, 0, *body))


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _round_trip(scheme: Scheme, hex_bytes: str):
    result = BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))
    assert result.ok, result.error
    return result.value, _pack(scheme, result.value)


def test_ac1_a_short_or_empty_list_for_a_bool_under_flags_is_absent():
    scheme = _timed(flags(1, _bool(1, "on")))

    packed = [
        _pack(scheme, {"c": 2, "on": [True]}),
        _pack(scheme, {"c": 2, "on": []}),
        _pack(scheme, {"c": 2}),
        _pack(scheme, {"c": 2, "on": [True, None]}),
        _pack(scheme, {"c": 2, "on": [True, False]}),
        _pack(scheme, {"c": 2, "on": [None, True]}),
    ]

    assert packed == ["01020100", "01020000", "01020000", "01020100", "01020100", "01020001"]


def test_ac2_a_short_or_empty_list_for_a_scalar_under_flags_is_absent():
    scheme = _timed(flags(1, _u8(1, "v")))

    packed = [
        _pack(scheme, {"c": 2, "v": [5]}),
        _pack(scheme, {"c": 2, "v": []}),
        _pack(scheme, {"c": 2, "v": [5, None]}),
        _pack(scheme, {"c": 2, "v": [5, 6]}),
        _pack(scheme, {"c": 1, "v": [5]}),
        _pack(scheme, {"c": 0, "v": []}),
    ]

    assert packed == ["0102010500", "01020000", "0102010500", "010201050106", "01010105", "0100"]


def test_ac3_a_u2_under_flags_takes_a_short_list_for_every_slot():
    scheme = _timed(flags(1, u2(_slot(1, "a"), _slot(2, "b"))))

    packed = [_pack(scheme, {"c": 2, "a": [1], "b": [2]}), _pack(scheme, {"c": 2, "a": [], "b": []})]

    assert packed == ["0102010900", "01020000"]


def test_ac3_a_nested_flags_takes_a_short_list():
    scheme = _timed(flags(1, flags(1, _u8(1, "v"))))

    assert _pack(scheme, {"c": 2, "v": [5]}) == "010201010500"


def test_ac3_a_group_under_flags_takes_a_short_list_for_every_member():
    scheme = _timed(flags(1, group(1, _u8(1, "a"), _u8(2, "b"))))

    assert _pack(scheme, {"c": 2, "a": [1], "b": [2]}) == "010201010200"


def test_ac3_two_members_under_flags_each_take_their_own_short_list():
    scheme = _timed(flags(1, _u8(1, "v"), _bool(2, "on")))

    packed = [
        _pack(scheme, {"c": 2, "v": [5], "on": [True, False]}),
        _pack(scheme, {"c": 2, "v": [5, 6], "on": [True]}),
        _pack(scheme, {"c": 2, "v": [], "on": []}),
    ]

    assert packed == ["0102030500", "010203050106", "01020000"]


def test_ac3_a_split_flag_bit_bool_takes_a_short_list():
    m = flag_byte()
    scheme = _timed(m, m.bit(_bool(1, "on")))

    assert _pack(scheme, {"c": 2, "on": [True]}) == "01020100"


def test_ac3_a_split_flag_bit_scalar_takes_a_short_list():
    m = flag_byte()
    scheme = _timed(m, m.bit(_u8(1, "v")))

    assert _pack(scheme, {"c": 2, "v": [5]}) == "0102010500"


def test_ac3_a_split_flag_bit_under_when_takes_a_short_list():
    m = flag_byte()
    scheme = _timed(_u8(1, "k"), m, when(2, eq(1, 1), m.bit(_u8(2, "v"))))

    packed = [
        _pack(scheme, {"c": 2, "k": [1, 1], "v": [5]}),
        _pack(scheme, {"c": 2, "k": [1, 1], "v": []}),
        _pack(scheme, {"c": 2, "k": [0, 0], "v": []}),
    ]

    assert packed == ["01020101050100", "010201000100", "010200000000"]


def test_ac4_a_set_u2_that_lacks_a_sibling_still_fails():
    scheme = _timed(flags(1, u2(_slot(1, "a"), _slot(2, "b"))))

    with pytest.raises(ValueError, match=r"^2: expected 2-bit int$"):
        _pack(scheme, {"c": 2, "a": [1, 2], "b": [2]})


def test_ac4_a_set_group_that_lacks_a_sibling_still_fails():
    scheme = _timed(flags(1, group(1, _u8(1, "a"), _u8(2, "b"))))

    with pytest.raises(TypeError, match=r"^2: expected int, got NoneType$"):
        _pack(scheme, {"c": 2, "a": [1, 2], "b": [2]})


@pytest.mark.parametrize("row", [{"c": 2, "x": [1]}, {"c": 2, "x": []}])
def test_ac5_a_plain_member_keeps_refusing_a_short_list(row):
    scheme = _timed(_u8(1, "x"))

    with pytest.raises(IndexError, match=r"^list index out of range$"):
        _pack(scheme, row)


def test_ac5_a_plain_member_keeps_its_other_results():
    scheme = _timed(_u8(1, "x"))

    with pytest.raises(TypeError, match=r"^1: expected int, got NoneType$"):
        _pack(scheme, {"c": 2})
    assert _pack(scheme, {"c": 2, "x": [1, 2]}) == "01020102"


@pytest.mark.parametrize("row", [{"c": 2, "k": [1, 1], "v": [7]}, {"c": 2, "k": [1, 0], "v": []}])
def test_ac5_a_member_under_when_keeps_refusing_a_short_list(row):
    scheme = _timed(_u8(1, "k"), when(2, eq(1, 1), _u8(2, "v")))

    with pytest.raises(IndexError, match=r"^list index out of range$"):
        _pack(scheme, row)


def test_ac5_a_member_under_when_keeps_its_other_results():
    scheme = _timed(_u8(1, "k"), when(2, eq(1, 1), _u8(2, "v")))

    with pytest.raises(TypeError, match=r"^2: expected int, got NoneType$"):
        _pack(scheme, {"c": 2, "k": [1, 0]})
    assert _pack(scheme, {"c": 2, "k": [1, 0], "v": [7]}) == "0102010700"
    assert _pack(scheme, {"c": 2, "k": [0, 0], "v": []}) == "01020000"


@pytest.mark.parametrize(
    "body,row",
    [
        (flags(1, _bool(1, "on")), {"c": 2, "on": [True, True, True]}),
        (flags(1, _u8(1, "v")), {"c": 2, "v": [5, 6, 7]}),
    ],
    ids=["bool", "scalar"],
)
def test_ac6_a_longer_list_stays_refused(body, row):
    with pytest.raises(ValueError, match=r"^1: 3 items, times count is 2$"):
        _pack(_timed(body), row)


def test_ac7_unpacked_rows_are_full_and_pack_back():
    bools = _timed(flags(1, _bool(1, "on")))
    scalars = _timed(flags(1, _u8(1, "v")))

    got = [
        _round_trip(bools, "01020100"),
        _round_trip(bools, "01020000"),
        _round_trip(scalars, "0102010500"),
        _round_trip(scalars, "010201050106"),
    ]

    assert got == [
        ({"c": 2, "on": [True, None]}, "01020100"),
        ({"c": 2, "on": [None, None]}, "01020000"),
        ({"c": 2, "v": [5, None]}, "0102010500"),
        ({"c": 2, "v": [5, 6]}, "010201050106"),
    ]


def test_ac8_repeat_keeps_its_equal_length_rule_and_its_empty_list_failure():
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, _u8(1, "v"))))

    with pytest.raises(ValueError, match=r"^repeat fields must have equal lengths$"):
        _pack(scheme, {"w": [1, 2], "v": [5]})
    with pytest.raises(IndexError, match=r"^list index out of range$"):
        _pack(scheme, {"w": [1, 2], "v": []})
