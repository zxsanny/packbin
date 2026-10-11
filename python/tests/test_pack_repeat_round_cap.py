from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, eq, flag_byte, flags, group, repeat, u8, when
from packbin import list as list_field

# The rows are the AZ-2355 table of the TypeScript reference `_docs/03_implementation/reference_loop20_budget.md`.

LIMIT = 65_535


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _repeat_k(**limits: int) -> Scheme:
    return Scheme(1, dict, repeat(0, _u8(0, "k"))).with_limits(**limits)


def _refusal(scheme: Scheme, row: dict) -> str:
    with pytest.raises(ValueError) as caught:
        BinaryPacker.pack(scheme, row)
    return str(caught.value)


def test_ac1_row1_a_repeat_list_above_the_default_limit_is_refused_before_any_round():
    # Arrange
    row = {"k": [7] * (LIMIT + 1)}

    # Act
    message = _refusal(_repeat_k(), row)

    # Assert
    assert message == "k: the repeat count is 65536, above the limit of 65535 rounds"


def test_ac2_row2_a_repeat_list_at_the_limit_packs_and_round_trips():
    # Arrange
    scheme = _repeat_k()

    # Act
    packed = BinaryPacker.pack(scheme, {"k": [7] * LIMIT})
    result = BinaryPacker.unpack(packed, scheme.on(lambda _row: None))

    # Assert
    assert len(packed) == 65_536
    assert packed[:16].hex() == "01070707070707070707070707070707"
    assert packed[-16:].hex() == "07" * 16
    assert result.ok
    assert BinaryPacker.pack(scheme, result.value) == packed


def test_ac3_row3_a_raised_limit_packs_a_longer_repeat():
    # Arrange
    scheme = _repeat_k(max_rounds=70_000)

    # Act
    packed = BinaryPacker.pack(scheme, {"k": [7] * 70_000})

    # Assert
    assert len(packed) == 70_001
    assert packed[:16].hex() == "01" + "07" * 15
    assert packed[-16:].hex() == "07" * 16


def test_row4_a_list_one_above_a_lowered_limit_is_refused():
    # Arrange
    scheme = _repeat_k(max_rounds=3)

    # Act
    message = _refusal(scheme, {"k": [1, 2, 3, 4]})

    # Assert
    assert message == "k: the repeat count is 4, above the limit of 3 rounds"


def test_row5_a_list_at_a_lowered_limit_packs():
    # Arrange
    scheme = _repeat_k(max_rounds=3)

    # Act / Assert
    assert BinaryPacker.pack(scheme, {"k": [1, 2, 3]}).hex() == "01010203"


def test_row6_the_member_named_is_the_one_whose_list_passes_the_limit():
    # Arrange
    scheme = Scheme(1, dict, repeat(0, _u8(0, "a"), _u8(1, "b"))).with_limits(max_rounds=3)

    # Act
    message = _refusal(scheme, {"a": 1, "b": [1, 2, 3, 4]})

    # Assert
    assert message == "b: the repeat count is 4, above the limit of 3 rounds"


def test_row7_a_repeat_as_a_flags_member_is_refused():
    # Arrange
    scheme = Scheme(1, dict, flags(0, repeat(0, _u8(0, "k")))).with_limits(max_rounds=3)

    # Act
    message = _refusal(scheme, {"k": [1, 2, 3, 4]})

    # Assert
    assert message == "k: the repeat count is 4, above the limit of 3 rounds"


def test_row8_a_repeat_in_a_split_bit_is_refused():
    # Arrange
    byte = flag_byte()
    scheme = Scheme(1, dict, byte, byte.bit(repeat(0, _u8(0, "k")))).with_limits(max_rounds=3)

    # Act
    message = _refusal(scheme, {"k": [1, 2, 3, 4]})

    # Assert
    assert message == "k: the repeat count is 4, above the limit of 3 rounds"


def test_row9_a_repeat_in_a_when_is_refused():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "m"), when(1, eq(0, 1), repeat(1, _u8(1, "k")))).with_limits(max_rounds=3)

    # Act
    message = _refusal(scheme, {"m": 1, "k": [1, 2, 3, 4]})

    # Assert
    assert message == "k: the repeat count is 4, above the limit of 3 rounds"


def test_row10_a_repeat_in_a_list_element_is_refused():
    # Arrange
    scheme = Scheme(
        1, dict, list_field(lambda row: row["items"], group(0, repeat(0, _u8(0, "k"))))
    ).with_limits(max_rounds=3)

    # Act
    message = _refusal(scheme, {"items": [{"k": [1, 2, 3, 4]}]})

    # Assert
    assert message == "k: the repeat count is 4, above the limit of 3 rounds"
