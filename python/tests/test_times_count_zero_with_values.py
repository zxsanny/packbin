from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, flags, times, u8


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _timed() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), times(1, 0, _u8(1, "pt"), _u8(2, "pu")))


def _timed_in_flags() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), flags(1, times(1, 0, _u8(1, "pt")), _u8(2, "h")))


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def test_ac1_count_zero_with_a_list_of_one_value_is_refused_naming_the_member():
    # Arrange
    row = {"n": 0, "pt": [5]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^1: 1 items, times count is 0$"):
        _pack(_timed(), row)


def test_ac1_count_zero_with_a_value_for_the_second_name_is_refused_naming_that_member():
    # Arrange
    row = {"n": 0, "pt": [], "pu": [1]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^2: 1 items, times count is 0$"):
        _pack(_timed(), row)


def test_ac1_count_zero_with_a_list_of_one_value_is_refused_under_flags():
    # Arrange
    row = {"n": 0, "pt": [5], "h": 1}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^1: 1 items, times count is 0$"):
        _pack(_timed_in_flags(), row)


@pytest.mark.parametrize(
    "row", [{"n": 0}, {"n": 0, "pt": [], "pu": []}, {"n": 0, "pt": None}], ids=["absent", "empty", "none"]
)
def test_ac2_count_zero_without_values_writes_zero_rounds(row: dict):
    # Arrange
    scheme = _timed()

    # Act
    packed = _pack(scheme, row)

    # Assert
    assert packed == "0100"


def test_ac2_count_zero_without_values_writes_zero_rounds_under_flags():
    # Arrange
    row = {"n": 0, "h": 1}

    # Act
    packed = _pack(_timed_in_flags(), row)

    # Assert
    assert packed == "01000201"


def test_a_list_value_outside_the_member_range_with_count_zero_is_still_refused_as_a_list():
    # Arrange
    row = {"n": 0, "pt": [300]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^1: 1 items, times count is 0$"):
        _pack(_timed(), row)
