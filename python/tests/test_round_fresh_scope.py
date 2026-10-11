from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, eq, repeat, times, u8, when


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _timed() -> Scheme:
    """A round whose `when` names a value an earlier round wrote and this round may skip."""
    return Scheme(
        1,
        dict,
        _u8(0, "a"),
        times(1, 0, _u8(1, "k"), when(2, eq(1, 1), _u8(2, "v")), when(3, eq(2, 5), _u8(3, "w"))),
    )


def _repeated() -> Scheme:
    return Scheme(
        1, dict, repeat(0, _u8(0, "k"), when(1, eq(0, 1), _u8(1, "v")), when(2, eq(1, 5), _u8(2, "w")))
    )


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


def test_ac1_times_round_does_not_see_a_value_an_earlier_round_wrote():
    # Arrange
    row = {"a": 2, "k": [1, 0], "v": [5, None], "w": [7, None]}

    # Act
    packed = BinaryPacker.pack(_timed(), row).hex()

    # Assert
    assert packed == "010201050700"


def test_ac1_repeat_round_does_not_see_a_value_an_earlier_round_wrote():
    # Arrange
    row = {"k": [1, 0], "v": [5, None], "w": [7, None]}

    # Act
    packed = BinaryPacker.pack(_repeated(), row).hex()

    # Assert
    assert packed == "0101050700"


def test_ac1_a_stale_value_in_the_skipped_slot_is_not_written():
    # Arrange
    row = {"a": 2, "k": [1, 0], "v": [5, None], "w": [7, 9]}

    # Act
    packed = BinaryPacker.pack(_timed(), row).hex()

    # Assert
    assert packed == "010201050700"


def test_ac2_unpack_times_round_starts_with_a_fresh_scope():
    # Arrange
    wire = "010201050700"

    # Act
    result = _unpack(_timed(), wire)

    # Assert
    assert result.ok
    assert result.value == {"a": 2, "k": [1, 0], "v": [5, None], "w": [7, None]}


def test_ac2_unpack_leaves_the_byte_a_stale_when_would_have_read_as_trailing():
    # Arrange: round two skips `v`, so its `w` is not read and the last byte is left over
    wire = "0102010507" "0007"

    # Act
    result = _unpack(_timed(), wire)

    # Assert
    assert not result.ok


def test_ac2_unpack_repeat_round_starts_with_a_fresh_scope():
    # Arrange
    wire = "0101050700"

    # Act
    result = _unpack(_repeated(), wire)

    # Assert
    assert result.ok
    assert result.value == {"k": [1, 0], "v": [5, None], "w": [7, None]}


@pytest.mark.parametrize("wire", ["010201050700", "0102010507" "0107", "01020105070007"])
def test_unpacked_bytes_repack_to_the_same_bytes_or_are_refused(wire: str):
    # Arrange
    scheme = _timed()

    # Act
    result = _unpack(scheme, wire)

    # Assert
    if result.ok:
        assert BinaryPacker.pack(scheme, result.value).hex() == wire
    else:
        assert wire == "01020105070007"


def test_a_value_outside_the_member_range_in_a_later_round_is_still_refused():
    # Arrange
    row = {"a": 2, "k": [1, 1], "v": [5, 5], "w": [7, 256]}

    # Act / Assert
    with pytest.raises(OverflowError):
        BinaryPacker.pack(_timed(), row)
