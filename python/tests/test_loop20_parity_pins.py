from __future__ import annotations

import enum

import pytest

from packbin import BinaryPacker, Scheme, flag_byte, flags, repeat, times, u8, u32

# Loop 20 parity rows (AZ-2356, AZ-2359, AZ-2360, AZ-2362, review B1): each pins the outcome of the TypeScript reference.

SKIPPED_COUNT = (
    "pt: a value is given, but the count of its times is not written, so its bit is clear; "
    "write the count before the times"
)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _count_after_byte() -> Scheme:
    byte = flag_byte()
    return Scheme(1, dict, byte, _u8(0, "n"), byte.bit(times(1, 0, _u8(1, "pt"))))


def _combined_count() -> Scheme:
    return Scheme(1, dict, flags(0, _u8(0, "n"), times(1, 0, _u8(1, "pt"))))


def test_az2356_ac1_split_count_zero_after_the_byte_with_a_list_is_refused_naming_the_member():
    # Arrange
    row = {"n": 0, "pt": [5, 6]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^1: 2 items, times count is 0$"):
        _pack(_count_after_byte(), row)


def test_az2356_ac2_split_count_zero_after_the_byte_with_a_lone_scalar_packs_zero_rounds():
    # Arrange
    scheme = _count_after_byte()

    # Act
    packed = [_pack(scheme, {"n": 0, "pt": 5}), _pack(scheme, {"n": 0, "pt": []}), _pack(scheme, {"n": 0})]

    # Assert
    assert packed == ["010000", "010000", "010000"]


def test_az2356_a_split_count_above_zero_after_the_byte_with_values_is_still_refused():
    # Arrange
    row = {"n": 2, "pt": [5, 6]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^times 1: body values are given, but count field 0 has no value"):
        _pack(_count_after_byte(), row)


def test_az2356_a_split_count_above_zero_after_the_byte_with_no_values_leaves_the_bit_clear():
    # Arrange
    scheme = _count_after_byte()

    # Act / Assert
    assert _pack(scheme, {"n": 2}) == "010002"


@pytest.mark.parametrize("row", [{"pt": [5, 6]}, {"pt": 5}], ids=["list", "lone"])
def test_az2360_ac1_combined_flags_skipped_count_with_values_is_refused_naming_the_member(row: dict):
    # Arrange
    scheme = _combined_count()

    # Act / Assert
    with pytest.raises(ValueError, match=rf"^{SKIPPED_COUNT}$"):
        _pack(scheme, row)


def test_az2360_ac2_combined_flags_skipped_count_without_values_packs_clear_as_before():
    # Arrange
    scheme = _combined_count()

    # Act
    packed = [_pack(scheme, {}), _pack(scheme, {"pt": []}), _pack(scheme, {"n": 2, "pt": [5, 6]})]

    # Assert
    assert packed == ["0100", "0100", "0103020506"]


def test_az2362_a_repeat_with_an_empty_list_as_a_flags_member_leaves_the_bit_clear():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "mode"), flags(1, repeat(1, _u8(1, "k"))))

    # Act
    packed = [_pack(scheme, {"mode": 1, "k": []}), _pack(scheme, {"mode": 1, "k": [5]}), _pack(scheme, {"mode": 1})]

    # Assert
    assert packed == ["010100", "01010105", "010100"]


def test_az2362_a_repeat_next_to_a_value_in_flags_packs_the_value_alone_when_the_list_is_empty():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "mode"), flags(1, _u8(1, "h"), repeat(2, _u8(2, "k"))))

    # Act
    packed = [_pack(scheme, {"mode": 1, "k": [], "h": 3}), _pack(scheme, {"mode": 1, "k": [5], "h": 3})]

    # Assert
    assert packed == ["01010103", "0101030305"]


def test_az2362_a_flags_member_of_a_repeat_round_with_an_empty_list_is_absent_in_every_round():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, _u8(1, "v"))))

    # Act / Assert
    assert _pack(scheme, {"w": [1, 2], "v": []}) == "0101000200"


def test_review_b1_a_required_leaf_with_an_empty_list_beside_a_flags_member_is_missing_not_an_index_error():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "w"), flags(1, _u8(1, "v"))))

    # Act / Assert: TypeScript refuses `missing w`
    with pytest.raises(KeyError) as raised:
        _pack(scheme, {"w": [], "v": [3]})
    assert str(raised.value) == "'missing field w'"


@pytest.mark.parametrize(
    ("row", "member"), [({"a": [1, 2], "b": []}, "b"), ({"a": [], "b": [1, 2]}, "a")]
)
def test_review_b1_a_repeat_with_one_empty_required_list_beside_a_longer_one_names_the_member(row, member):
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "a"), _u8(1, "b")))

    # Act / Assert
    with pytest.raises(KeyError) as raised:
        _pack(scheme, row)
    assert str(raised.value) == f"'missing field {member}'"


def test_review_b1_a_repeat_with_every_list_empty_still_packs_no_rounds():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "a"), _u8(1, "b")))

    # Act / Assert
    assert _pack(scheme, {"a": [], "b": []}) == "01"


class Level(enum.IntEnum):
    LOW = 7
    HIGH = 200


class Plain(enum.Enum):
    LOW = 7


def test_az2359_ac1_an_int_enum_member_packs_as_its_integer():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "level"))

    # Act
    packed = _pack(scheme, {"level": Level.HIGH})

    # Assert
    assert packed == "01c8"


def test_az2359_ac1_an_int_enum_member_packs_in_a_wider_slot_too():
    # Arrange
    scheme = Scheme(1, dict, u32(0, lambda row: row["level"]))

    # Act
    packed = _pack(scheme, {"level": Level.HIGH})

    # Assert
    assert packed == "01c8000000"


def test_az2359_ac1_a_plain_enum_member_is_not_a_number_and_is_refused_naming_the_field():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "level"))

    # Act / Assert
    with pytest.raises(TypeError, match=r"^0: expected int, got Plain$"):
        _pack(scheme, {"level": Plain.LOW})
