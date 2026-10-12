from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, eq, flag_byte, flags, group, repeat, times, u2, u8, when
from packbin import bool as flag_bool

# AZ-2383 (U3): rows 27 to 39 of `_docs/03_implementation/reference_loop21_slots.md` section 3. In a `repeat`, a
# non-empty list shorter than the rounds under a member a flag bit can leave absent is refused, named by the
# member. `times` keeps accepting it.
# Python differences: the text says `None` where TypeScript says `undefined`; a lone value, a short list for a
# required member and a short list under a `when` outside `flags` (rows 30 lone, 31, 38) are refused by the
# equal-length rule of `repeat` (README, Repeat), where TypeScript packs the lone value and the `when` row.


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _on(field_id: int, name: str):
    return flag_bool(field_id, lambda row, name=name: row[name])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _refusal(scheme: Scheme, row: dict) -> str:
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, row)
    return str(caught.value)


def _short(member: str, items: int, rounds: int) -> str:
    return f"{member}: {items} items, repeat count {rounds}; give one entry per round, None where the member is absent"


def _w_flags_v() -> Scheme:
    return Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, _u8(1, "v"))))


def test_ac1_row27_a_short_list_under_flags_is_refused_naming_the_member():
    # Arrange / Act / Assert
    assert _refusal(_w_flags_v(), {"w": [1, 2], "v": [5]}) == _short("v", 1, 2)


def test_ac1_row28_the_repeat_count_is_the_longest_list():
    # Arrange / Act / Assert
    assert _refusal(_w_flags_v(), {"w": [1, 2, 3], "v": [5, None]}) == _short("v", 2, 3)


def test_ac2_row29_a_none_entry_marks_the_round_the_member_is_absent_in():
    # Arrange
    scheme = _w_flags_v()

    # Act
    packed = [_pack(scheme, {"w": [1, 2], "v": [5, None]}), _pack(scheme, {"w": [1, 2], "v": [5, None]})]

    # Assert
    assert packed == ["010101050200", "010101050200"]


@pytest.mark.parametrize(
    "row,expected",
    [
        ({"w": [1, 2], "v": [5, 6]}, "01010105020106"),
        ({"w": [1, 2]}, "0101000200"),
        ({"w": [1, 2], "v": []}, "0101000200"),
    ],
    ids=["full", "absent", "empty"],
)
def test_ac2_row30_a_full_list_an_empty_list_and_no_list_pack_as_before(row: dict, expected: str):
    # Arrange / Act / Assert
    assert _pack(_w_flags_v(), row) == expected


@pytest.mark.parametrize(
    "row",
    [{"w": [1, 2], "v": 5}, {"w": [1], "v": [5, 6]}],
    ids=["lone_value", "required_member_short"],
)
def test_row30_row31_python_keeps_the_equal_length_rule_for_a_lone_value_and_a_short_required_list(row: dict):
    # Arrange / Act / Assert
    assert _refusal(_w_flags_v(), row) == "repeat fields must have equal lengths"


def test_ac1_row32_a_short_bool_list_is_refused_and_a_none_entry_packs():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, _on(1, "on"))))

    # Act / Assert
    assert _refusal(scheme, {"w": [1, 2], "on": [True]}) == _short("on", 1, 2)
    assert _pack(scheme, {"w": [1, 2], "on": [True, None]}) == "0101010200"


def test_ac1_row33_a_short_list_behind_a_split_flag_bit_is_refused():
    # Arrange
    byte = flag_byte()
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), byte, byte.bit(_u8(1, "v"))))

    # Act / Assert
    assert _refusal(scheme, {"w": [1, 2], "v": [5]}) == _short("v", 1, 2)
    assert _pack(scheme, {"w": [1, 2], "v": [5, None]}) == "010101050200"


def test_ac1_row34_a_short_list_of_a_group_member_under_flags_is_refused():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, group(1, _u8(1, "v")))))

    # Act / Assert
    assert _refusal(scheme, {"w": [1, 2], "v": [5]}) == _short("v", 1, 2)


def test_ac1_row35_the_first_short_u2_slot_is_named():
    # Arrange
    slots = u2((1, lambda row: row["p"]), (2, lambda row: row["q"]))
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, slots)))

    # Act / Assert
    assert _refusal(scheme, {"w": [1, 2], "p": [1], "q": [2, 3]}) == _short("p", 1, 2)


def test_ac1_row36_a_short_list_of_a_when_under_flags_is_refused():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, when(1, eq(0, 1), _u8(1, "v")))))

    # Act / Assert
    assert _refusal(scheme, {"w": [1, 1], "v": [5]}) == _short("v", 1, 2)


def test_ac1_row37_the_first_short_member_in_declaration_order_is_named():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, flags(0, _u8(0, "a"), _u8(1, "b"))))

    # Act / Assert
    assert _refusal(scheme, {"a": [1], "b": [5, 6]}) == _short("a", 1, 2)
    assert _refusal(scheme, {"a": [1, 2, 3], "b": [5, 6]}) == _short("b", 2, 3)


def test_row38_a_short_list_under_a_when_outside_flags_stays_refused_by_the_equal_length_rule():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "v"))))

    # Act / Assert
    assert _refusal(scheme, {"k": [1, 2], "v": [9]}) == "repeat fields must have equal lengths"
    assert _pack(scheme, {"k": [1, 2], "v": [9, None]}) == "01010902"


def test_ac2_row39_times_keeps_reading_a_short_list_under_flags_as_absent():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "c"), times(1, 0, flags(1, _u8(1, "v"))))

    # Act / Assert
    assert _pack(scheme, {"c": 2, "v": [5]}) == "0102010500"
