from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, bytes as raw_bytes, flags, repeat, sized, times, u8


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _timed_bytes() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), times(1, 0, raw_bytes(1, lambda row: row["b"], 2)))


def _timed_sized() -> Scheme:
    return Scheme(1, dict, _u8(0, "n"), times(1, 0, _u8(1, "len"), sized(2, lambda row: row["z"], 1)))


def _repeated_bytes() -> Scheme:
    return Scheme(1, dict, repeat(0, raw_bytes(0, lambda row: row["b"], 2)))


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


@pytest.mark.parametrize(
    "buffer", [b"ab", bytearray(b"ab"), memoryview(b"ab")], ids=["bytes", "bytearray", "memoryview"]
)
def test_ac1_a_lone_buffer_for_a_bytes_name_in_a_times_is_refused_naming_the_member(buffer):
    # Arrange
    row = {"n": 3, "b": buffer}

    # Act / Assert
    with pytest.raises(TypeError, match=r"^member b: a byte buffer in a repeat or times round must be a list"):
        _pack(_timed_bytes(), row)


def test_ac1_a_lone_buffer_for_a_sized_name_in_a_times_is_refused_naming_the_member():
    # Arrange
    row = {"n": 2, "len": 1, "z": b"a"}

    # Act / Assert
    with pytest.raises(TypeError, match=r"^member z: a byte buffer in a repeat or times round"):
        _pack(_timed_sized(), row)


def test_ac1_a_lone_buffer_in_a_repeat_is_refused_naming_the_member():
    # Arrange
    row = {"b": b"ab"}

    # Act / Assert
    with pytest.raises(TypeError, match=r"^member b: a byte buffer in a repeat or times round"):
        _pack(_repeated_bytes(), row)


def test_ac1_a_lone_buffer_is_refused_whatever_the_times_count():
    # Arrange
    row = {"n": 0, "b": b"ab"}

    # Act / Assert
    with pytest.raises(TypeError, match=r"^member b: "):
        _pack(_timed_bytes(), row)


def test_ac1_a_lone_buffer_under_a_times_in_flags_is_refused():
    # Arrange
    scheme = Scheme(1, dict, _u8(0, "n"), flags(1, times(1, 0, raw_bytes(1, lambda row: row["b"], 2))))

    # Act / Assert
    with pytest.raises(TypeError, match=r"^member b: "):
        _pack(scheme, {"n": 1, "b": b"ab"})


def test_ac2_a_list_of_buffers_packs_one_per_round():
    # Arrange
    row = {"n": 2, "b": [b"ab", b"cd"]}

    # Act
    packed = _pack(_timed_bytes(), row)

    # Assert
    assert packed == "010261626364"


def test_ac2_a_list_of_sized_buffers_packs_one_per_round():
    # Arrange
    row = {"n": 2, "len": [1, 1], "z": [b"a", b"b"]}

    # Act
    packed = _pack(_timed_sized(), row)

    # Assert
    assert packed == "010201610162"


def test_ac2_a_repeat_list_of_buffers_packs_one_per_round():
    # Arrange
    row = {"b": [b"ab", b"cd"]}

    # Act
    packed = _pack(_repeated_bytes(), row)

    # Assert
    assert packed == "0161626364"


def test_a_buffer_of_the_wrong_size_in_a_list_still_fails_naming_the_field():
    # Arrange
    row = {"n": 2, "b": [b"ab", b"c"]}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^1: expected 2 bytes, got 1$"):
        _pack(_timed_bytes(), row)
