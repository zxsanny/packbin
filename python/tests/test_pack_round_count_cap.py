from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, flags, group, list as list_field, times, u8, u32

LIMIT = 65_535


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _timed() -> Scheme:
    return Scheme(1, dict, u32(0, lambda row: row["n"]), times(1, 0, _u8(1, "x")))


def test_ac1_count_over_the_limit_with_a_lone_scalar_is_refused_naming_the_member():
    # Arrange
    row = {"n": LIMIT + 1, "x": 7}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^x: the times count is 65536, above the limit of 65535 rounds$"):
        BinaryPacker.pack(_timed(), row)


def test_ac1_a_four_billion_count_is_refused_before_any_round():
    # Arrange
    row = {"n": 4_000_000_000, "x": 7}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^x: the times count is 4000000000, above the limit of 65535 rounds$"):
        BinaryPacker.pack(_timed(), row)


def test_ac1_count_over_the_limit_is_refused_when_the_value_is_a_list():
    # Arrange
    row = {"n": LIMIT + 1, "x": [1] * (LIMIT + 1)}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^x: the times count is 65536, above the limit of 65535 rounds$"):
        BinaryPacker.pack(_timed(), row)


def test_ac1_count_over_the_limit_is_refused_for_a_times_member_of_flags():
    # Arrange
    scheme = Scheme(
        1,
        dict,
        u32(0, lambda row: row["n"]),
        flags(1, times(1, 0, _u8(1, "x"))),
    )

    # Act / Assert
    with pytest.raises(ValueError, match=r"^x: the times count is 65536, above the limit of 65535 rounds$"):
        BinaryPacker.pack(scheme, {"n": LIMIT + 1, "x": 7})


def test_ac1_count_over_the_limit_is_refused_inside_a_list_element():
    # Arrange
    scheme = Scheme(
        1,
        dict,
        list_field(lambda row: row["items"], group(0, u32(0, lambda row: row["n"]), times(1, 0, _u8(1, "x")))),
    )
    row = {"items": [{"n": 1, "x": 7}, {"n": LIMIT + 1, "x": 7}]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^x: the times count is 65536, above the limit of 65535 rounds$"):
        BinaryPacker.pack(scheme, row)


def test_ac2_count_at_the_limit_packs_and_round_trips():
    # Arrange
    scheme = _timed()

    # Act
    packed = BinaryPacker.pack(scheme, {"n": LIMIT, "x": 7})
    result = BinaryPacker.unpack(packed, scheme.on(lambda _row: None))

    # Assert
    assert packed == bytes([1, 0xFF, 0xFF, 0, 0]) + bytes([7]) * LIMIT
    assert result.ok
    assert result.value == {"n": LIMIT, "x": [7] * LIMIT}


def test_ac3_a_scheme_that_raised_the_limit_packs_a_larger_count():
    # Arrange
    scheme = _timed().with_limits(max_rounds=70_000)

    # Act
    packed = BinaryPacker.pack(scheme, {"n": 70_000, "x": 7})

    # Assert
    assert len(packed) == 5 + 70_000


def test_a_scheme_that_lowered_the_limit_refuses_a_smaller_count():
    # Arrange
    scheme = _timed().with_limits(max_rounds=3)

    # Act / Assert
    with pytest.raises(ValueError, match=r"^x: the times count is 4, above the limit of 3 rounds$"):
        BinaryPacker.pack(scheme, {"n": 4, "x": 7})
