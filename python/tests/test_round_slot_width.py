from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    ShortPacket,
    bool as flag_bool,
    bytes as raw_bytes,
    dict as dict_field,
    eq,
    flag_byte,
    flags,
    group,
    list as list_field,
    repeat,
    sized,
    times,
    u2,
    u8,
    when,
)

# AZ-2381 and AZ-2382: rows 1 to 14 of `_docs/03_implementation/reference_loop21_slots.md` section 1, in Python
# builder syntax. Each row packs two rounds at exactly `max_slots` = 2 x W, refuses the third round, and the
# packet written at 3 x W unpacks to the same bytes at 2 x W only up to the round that pack refuses.
# Python differences: a group has no name and an empty one never builds (row 1 is checked as a bool member and as
# the construction error); the `field` of an unpack error is the anchor, so the rows pin `needed` and `left`.


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _flag_on(field_id: int, name: str):
    return flag_bool(field_id, lambda row, name=name: row[name])


def _bytes(field_id: int, name: str, size: int):
    return raw_bytes(field_id, lambda row, name=name: row[name], size)


def _sized(field_id: int, name: str, count: int):
    return sized(field_id, lambda row, name=name: row[name], count)


def _row1():
    return repeat(0, _u8(0, "a"), flags(1, _flag_on(1, "g")))


def _row2():
    return repeat(
        0, _u8(0, "m"), when(1, eq(0, 1), _u8(1, "k")), when(2, eq(0, 2), _u8(2, "k"))
    )


def _row3():
    return repeat(0, flags(0, _flag_on(0, "on"), _u8(1, "v")))


def _row4():
    byte = flag_byte()
    return repeat(0, byte, byte.bit(_u8(0, "a")), byte.bit(_u8(1, "b")))


def _row5():
    return repeat(0, _u8(0, "m"), when(1, eq(0, 1), _u8(1, "k")))


def _row6():
    return repeat(0, _u8(0, "a"), group(1, _u8(1, "b"), group(2, _u8(2, "c"))))


def _row7():
    return repeat(0, _u8(0, "a"), group(1, _u8(1, "b")))


def _row8():
    slots = (u2((1, lambda row: row["p"]), (2, lambda row: row["q"]), (3, lambda row: row["r"])))
    return repeat(0, _u8(0, "a"), slots)


def _row9():
    return repeat(
        0,
        _u8(0, "n"),
        list_field(lambda row: row["l"], u8(0, lambda row: row)),
        dict_field(lambda row: row["d"], u8(0, lambda row: row)),
    )


def _row10():
    return repeat(0, _u8(0, "n"), _bytes(1, "b", 2), _sized(2, "s", 0))


# (id, body, width, two rounds row, hex at 2W, 3-round row, 3-round hex, rounds the third packet refuses at 2W, left)
_ROWS = [
    ("flags_bool", _row1, 2, {"a": [1, 2], "g": [True, None]}, "0101010200",
     {"a": [1, 2, 3], "g": [True, None, True]}, "01010102000301", "a", 2),
    ("duplicate_leaves", _row2, 2, {"m": [1, 2], "k": [7, 8]}, "0101070208",
     {"m": [1, 2, 1], "k": [7, 8, 9]}, "01010702080109", "m", 2),
    ("combined_flags", _row3, 2, {"on": [True, True], "v": [5, 6]}, "0103050306",
     {"on": [True, True, True], "v": [5, 6, 7]}, "01030503060307", "on", 2),
    ("split_bits", _row4, 2, {"a": [1, 2], "b": [4, 5]}, "01030104030205",
     {"a": [1, 2, 3], "b": [4, 5, 6]}, "01030104030205030306", "a", 3),
    ("when_clear", _row5, 2, {"m": [0, 0]}, "010000", {"m": [0, 0, 0]}, "01000000", "m", 1),
    ("nested_groups", _row6, 3, {"a": [1, 2], "b": [4, 5], "c": [7, 8]}, "01010407020508",
     {"a": [1, 2, 3], "b": [4, 5, 6], "c": [7, 8, 9]}, "01010407020508030609", "a", 3),
    ("group", _row7, 2, {"a": [1, 2], "b": [4, 5]}, "0101040205",
     {"a": [1, 2, 3], "b": [4, 5, 6]}, "01010402050306", "a", 2),
    ("u2_slots", _row8, 4, {"a": [1, 2], "p": [1, 1], "q": [2, 2], "r": [3, 3]}, "0101390239",
     {"a": [1, 2, 3], "p": [1, 1, 1], "q": [2, 2, 2], "r": [3, 3, 3]}, "01013902390339", "a", 2),
    ("list_and_dict", _row9, 3, {"n": [1, 2], "l": [[0, 1], [1, 2]], "d": [{"k": 0}, {"k": 1}]},
     "010102000001010001006b000202000102010001006b01",
     {"n": [1, 2, 3], "l": [[0, 1], [1, 2], [2, 3]], "d": [{"k": 0}, {"k": 1}, {"k": 2}]},
     "010102000001010001006b000202000102010001006b010302000203010001006b02", "n", 11),
    ("bytes_and_sized", _row10, 3,
     {"n": [1, 1], "b": [b"\x00\x00", b"\x01\x01"], "s": [b"\x09", b"\x09"]}, "010100000901010109",
     {"n": [1, 1, 1], "b": [b"\x00\x00", b"\x01\x01", b"\x02\x02"], "s": [b"\x09"] * 3},
     "01010000090101010901020209", "n", 4),
]
_IDS = [row[0] for row in _ROWS]


def _scheme(body, max_slots: int) -> Scheme:
    return Scheme(1, dict, body()).with_limits(max_slots=max_slots)


@pytest.mark.parametrize("name,body,width,two,hex_two,three,hex_three,member,left", _ROWS, ids=_IDS)
def test_ac1_a_round_charges_the_reference_width_two_rounds_pack_at_the_limit(
    name, body, width, two, hex_two, three, hex_three, member, left
):
    # Arrange
    scheme = _scheme(body, 2 * width)

    # Act
    packed = BinaryPacker.pack(scheme, two).hex()

    # Assert
    assert packed == hex_two


@pytest.mark.parametrize("name,body,width,two,hex_two,three,hex_three,member,left", _ROWS, ids=_IDS)
def test_ac1_the_third_round_is_refused_naming_the_first_name_and_the_slots_it_would_hold(
    name, body, width, two, hex_two, three, hex_three, member, left
):
    # Arrange
    scheme = _scheme(body, 2 * width)

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, three)

    # Assert
    assert str(caught.value) == (
        f"{member}: the rounds would hold {3 * width} slots, above the limit of {2 * width} slots"
    )


@pytest.mark.parametrize("name,body,width,two,hex_two,three,hex_three,member,left", _ROWS, ids=_IDS)
def test_ac1_three_rounds_pack_at_three_widths(name, body, width, two, hex_two, three, hex_three, member, left):
    # Arrange
    scheme = _scheme(body, 3 * width)

    # Act
    packed = BinaryPacker.pack(scheme, three).hex()

    # Assert
    assert packed == hex_three


@pytest.mark.parametrize("name,body,width,two,hex_two,three,hex_three,member,left", _ROWS, ids=_IDS)
def test_ac1_unpack_refuses_the_third_round_with_the_bytes_the_reference_leaves(
    name, body, width, two, hex_two, three, hex_three, member, left
):
    # Arrange
    scheme = _scheme(body, 2 * width)

    # Act
    result = BinaryPacker.unpack(bytes.fromhex(hex_three), scheme.on(lambda _row: None))

    # Assert
    assert result.ok is False
    assert isinstance(result.error, ShortPacket)
    assert (result.error.needed, result.error.left) == (0, left)


@pytest.mark.parametrize("name,body,width,two,hex_two,three,hex_three,member,left", _ROWS, ids=_IDS)
def test_ac2_the_packet_pack_writes_at_the_limit_unpacks_and_packs_again_to_the_same_bytes(
    name, body, width, two, hex_two, three, hex_three, member, left
):
    # Arrange
    scheme = _scheme(body, 2 * width)
    rows: list = []

    # Act
    result = BinaryPacker.unpack(bytes.fromhex(hex_two), scheme.on(rows.append))

    # Assert
    assert result.ok, result.error
    assert BinaryPacker.pack(scheme, rows[0]).hex() == hex_two


def test_row1_an_empty_group_never_builds_so_the_flags_bool_stands_for_it():
    # Arrange / Act
    with pytest.raises(ValueError) as caught:
        Scheme(1, dict, repeat(0, _u8(0, "a"), flags(1, group(1))))

    # Assert
    assert str(caught.value) == "group 1 has no fields, so it can never carry a value"


def test_row2_a_name_that_two_whens_declare_is_one_slot_not_two():
    # Arrange: W = 2 (m, k); a count of the leaves would be 3 and refuse the second round at 4
    scheme = _scheme(_row2, 4)

    # Act
    packed = BinaryPacker.pack(scheme, {"m": [1, 2], "k": [7, 8]})

    # Assert
    assert packed.hex() == "0101070208"


def _times_two_whens() -> Scheme:
    return Scheme(
        1,
        dict,
        _u8(0, "n"),
        times(1, 0, _u8(1, "m"), when(2, eq(1, 1), _u8(2, "k")), when(3, eq(1, 2), _u8(3, "k"))),
    )


def test_row11_a_times_with_two_slots_per_round_packs_two_rounds_at_four_slots():
    # Arrange
    scheme = _times_two_whens().with_limits(max_slots=4)

    # Act
    packed = BinaryPacker.pack(scheme, {"n": 2, "m": [1, 2], "k": [7, 8]})

    # Assert
    assert packed.hex() == "010201070208"


def test_row12_three_rounds_of_it_hold_six_slots_and_are_refused():
    # Arrange
    scheme = _times_two_whens().with_limits(max_slots=4)

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, {"n": 3, "m": [1, 2, 1], "k": [7, 8, 9]})

    # Assert
    assert str(caught.value) == "m: the rounds would hold 6 slots, above the limit of 4 slots"


def _times_then_repeat() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), times(1, 0, _u8(1, "a")), repeat(2, _u8(2, "b")))


def test_row13_one_counter_is_shared_by_a_times_and_a_repeat_of_one_call():
    # Arrange
    scheme = _times_then_repeat().with_limits(max_slots=3)

    # Act
    packed = BinaryPacker.pack(scheme, {"n": 1, "a": [1], "b": [2, 3]})

    # Assert
    assert packed.hex() == "0101010203"


def test_row14_the_fourth_slot_of_the_call_is_refused_naming_the_repeat_member():
    # Arrange
    scheme = _times_then_repeat().with_limits(max_slots=3)

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, {"n": 1, "a": [1], "b": [2, 3, 4]})

    # Assert
    assert str(caught.value) == "b: the rounds would hold 4 slots, above the limit of 3 slots"


@pytest.mark.parametrize("max_slots,refused", [(3, False), (2, True)])
def test_ac2_unpack_of_the_times_and_repeat_row_charges_what_pack_charges(max_slots: int, refused: bool):
    # Arrange
    scheme = _times_then_repeat().with_limits(max_slots=max_slots)

    # Act
    result = BinaryPacker.unpack(bytes.fromhex("0101010203"), scheme.on(lambda _row: None))

    # Assert
    assert result.ok is not refused


def test_ac2_one_over_at_the_limit_is_still_refused_by_pack():
    # Arrange
    scheme = _scheme(_row7, 3)

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, {"a": [1, 2], "b": [4, 5]})

    # Assert
    assert str(caught.value) == "a: the rounds would hold 4 slots, above the limit of 3 slots"
