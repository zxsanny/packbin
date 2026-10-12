from __future__ import annotations

import time

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bytes as raw_bytes,
    dict as dict_field,
    eq,
    flag_byte,
    flags,
    group,
    list as list_field,
    repeat,
    times,
    u8,
    u32,
    when,
)
from packbin._validate import _validate_round_bodies

# AZ-2390 (F33): rows 15 to 26 of `_docs/03_implementation/reference_loop21_slots.md` section 2. A round body
# must hold a member (looking through `when` and groups), or the scheme is refused when it is built.
# Python differences: a group has no name and an empty one never builds (rows 19 and 26 end at that error), and a
# `when` must name a field declared in its own scope, so an empty `when` inside a round is checked on the nodes
# (rows 17 and 18) instead of through `Scheme`.


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _refusal(*fields) -> str:
    with pytest.raises(ValueError) as caught:
        Scheme(1, dict, *fields)
    return str(caught.value)


def _text(kind: str, anchor: int) -> str:
    return f"{kind} {anchor}: the body holds no member; a round of it would charge no slot and write nothing"


def test_ac1_row15_an_empty_repeat_is_refused_naming_the_repeat():
    # Arrange / Act / Assert
    assert _refusal(repeat(0)) == _text("repeat", 0)


def test_ac1_row16_an_empty_times_is_refused_naming_the_times():
    # Arrange / Act / Assert
    assert _refusal(_u8(0, "n"), times(1, 0)) == _text("times", 1)


@pytest.mark.parametrize(
    "body",
    [
        lambda: repeat(0, when(0, eq(0, 1))),
        lambda: repeat(0, when(0, eq(0, 1), when(0, eq(0, 2)))),
        lambda: repeat(0, group(0, when(0, eq(0, 1)))),
    ],
    ids=["empty_when", "nested_empty_whens", "group_of_an_empty_when"],
)
def test_ac1_rows17_and_18_a_body_of_only_empty_whens_and_groups_holds_no_member(body):
    # Arrange
    node = body()

    # Act
    with pytest.raises(ValueError) as caught:
        _validate_round_bodies([node])

    # Assert
    assert str(caught.value) == _text("repeat", 0)


def test_ac1_rows17_and_18_through_a_scheme_the_when_that_names_no_visible_field_is_refused():
    # Arrange / Act / Assert
    assert "allowed only if declared earlier in the same scope" in _refusal(repeat(0, when(0, eq(0, 1))))


def test_ac1_row19_an_empty_group_in_a_body_is_refused_by_the_group_rule_first():
    # Arrange / Act / Assert
    assert _refusal(repeat(0, group(0))) == "group 0 has no fields, so it can never carry a value"


def test_ac2_row20_the_f33_request_shape_fails_at_build_in_under_a_second():
    # Arrange
    started = time.perf_counter()

    # Act
    message = _refusal(list_field(lambda row: row["items"], group(0, u32(0, lambda row: row["n"]), times(1, 0))))
    elapsed = time.perf_counter() - started

    # Assert
    assert message == _text("times", 1)
    assert elapsed < 1.0


def test_ac3_row21_a_zero_width_bytes_body_builds_and_pack_is_bounded_by_the_slots():
    # Arrange
    scheme = Scheme(
        1, dict, _u8(0, "n"), times(1, 0, raw_bytes(1, lambda row: row["v"], 0))
    ).with_limits(max_slots=5)
    row = {"n": 10, "v": [b""] * 10}

    # Act
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, row)

    # Assert
    assert str(caught.value) == "v: the rounds would hold 6 slots, above the limit of 5 slots"


def test_ac3_row22_a_flag_byte_is_a_member():
    # Arrange
    byte = flag_byte()
    scheme = Scheme(1, dict, repeat(0, byte))

    # Act / Assert
    assert BinaryPacker.pack(scheme, {}).hex() == "01"


def test_ac3_row23_a_member_less_flags_is_a_member():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, flags(0)))

    # Act / Assert
    assert BinaryPacker.pack(scheme, {}).hex() == "01"


def test_ac3_row24_a_one_member_body_packs_as_before():
    # Arrange
    repeated = Scheme(1, dict, repeat(0, _u8(0, "k")))
    counted = Scheme(1, dict, _u8(0, "n"), times(1, 0, _u8(1, "k")))

    # Act
    packed = [BinaryPacker.pack(repeated, {"k": [7, 8]}).hex(), BinaryPacker.pack(counted, {"n": 2, "k": [7, 8]}).hex()]

    # Assert
    assert packed == ["010708", "01020708"]


def _under_flags():
    return Scheme(1, dict, flags(0, repeat(0)))


def _under_flag_bit():
    byte = flag_byte()
    return Scheme(1, dict, byte, byte.bit(repeat(0)))


def _under_when():
    return Scheme(1, dict, _u8(0, "m"), when(1, eq(0, 1), repeat(1)))


def _under_group():
    return Scheme(1, dict, group(0, repeat(0)))


def _in_list_item():
    return Scheme(1, dict, list_field(lambda row: row["l"], group(0, repeat(0))))


def _in_dict_item():
    return Scheme(1, dict, dict_field(lambda row: row["d"], group(0, repeat(0))))


def _in_times_inside_flag_bit_in_list_item():
    byte = flag_byte()
    return Scheme(
        1, dict, list_field(lambda row: row["l"], group(0, _u8(0, "n"), byte, byte.bit(times(1, 0))))
    )


@pytest.mark.parametrize(
    "build,anchor,kind",
    [
        (_under_flags, 0, "repeat"),
        (_under_flag_bit, 0, "repeat"),
        (_under_when, 1, "repeat"),
        (_under_group, 0, "repeat"),
        (_in_list_item, 0, "repeat"),
        (_in_dict_item, 0, "repeat"),
        (_in_times_inside_flag_bit_in_list_item, 1, "times"),
    ],
    ids=["flags", "flag_bit", "when", "group", "list_item", "dict_item", "times_in_flag_bit_in_list_item"],
)
def test_ac1_row25_the_same_empty_body_is_refused_wherever_the_round_stands(build, anchor, kind):
    # Arrange / Act
    with pytest.raises(ValueError) as caught:
        build()

    # Assert
    assert str(caught.value) == _text(kind, anchor)
