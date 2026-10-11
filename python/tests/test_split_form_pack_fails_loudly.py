from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    eq,
    flag_byte,
    flags,
    group,
    times,
    u8,
    u16,
    when,
)


SKIPPED_COUNT = (
    "pt: a value is given, but the count of its times is not written, so its bit is clear; "
    "write the count before the times"
)


def _scheme(*fields) -> Scheme:
    return Scheme(1, dict, *fields)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _u16(field_id: int, name: str):
    return u16(field_id, lambda row, name=name: row[name])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _when_after_byte() -> Scheme:
    """The `when` names `sel`, written between the flag byte and the bit."""
    byte = flag_byte()
    return _scheme(_u8(0, "mode"), byte, _u8(1, "sel"), byte.bit(when(2, eq(1, 1), _u8(2, "speed"))))


def _times_after_byte() -> Scheme:
    byte = flag_byte()
    return _scheme(byte, _u8(0, "n"), byte.bit(times(1, 0, _u8(1, "pt"))), byte.bit(_u16(2, "heading")))


def _group_when_after_byte() -> Scheme:
    byte = flag_byte()
    return _scheme(byte, _u8(0, "sel"), byte.bit(group(1, when(1, eq(0, 1), _u8(1, "speed")))))


def _when_before_byte() -> Scheme:
    byte = flag_byte()
    return _scheme(_u8(0, "mode"), byte, byte.bit(when(1, eq(0, 1), _u8(1, "speed"))), byte.bit(_u16(2, "heading")))


def _times_before_byte() -> Scheme:
    byte = flag_byte()
    return _scheme(_u8(0, "n"), byte, byte.bit(times(1, 0, _u8(1, "pt"))), byte.bit(_u16(2, "heading")))


def test_ac1_when_condition_written_after_the_byte_with_a_body_is_refused_naming_the_member():
    # Arrange
    row = {"mode": 0, "sel": 1, "speed": 7}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^when 2: a body value is given, but condition field 1 is written after"):
        _pack(_when_after_byte(), row)


def test_ac1_when_in_a_group_bit_is_refused_naming_the_when():
    # Arrange
    row = {"sel": 1, "speed": 7}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^when 1: "):
        _pack(_group_when_after_byte(), row)


def test_ac1_times_count_written_after_the_byte_with_values_is_refused_naming_the_member():
    # Arrange
    row = {"n": 2, "pt": [5, 6], "heading": 90}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^times 1: body values are given, but count field 0 has no value"):
        _pack(_times_after_byte(), row)


def test_ac2_times_whose_count_was_skipped_with_values_is_refused_in_combined_flags():
    # Arrange
    scheme = _scheme(flags(0, _u8(0, "n"), times(1, 0, _u8(1, "pt"))))

    # Act / Assert
    with pytest.raises(ValueError, match=rf"^{SKIPPED_COUNT}$"):
        _pack(scheme, {"pt": [5]})


def test_ac3_false_condition_written_after_the_byte_with_a_body_packs_without_the_body():
    # Arrange
    row = {"mode": 0, "sel": 0, "speed": 7}

    # Act / Assert
    assert _pack(_when_after_byte(), row) == "01000000"


def test_ac3_false_condition_in_a_group_bit_packs_without_the_body():
    # Arrange
    row = {"sel": 0, "speed": 7}

    # Act / Assert
    assert _pack(_group_when_after_byte(), row) == "010000"


@pytest.mark.parametrize(
    "row,packet",
    [({"mode": 0, "sel": 1}, "01000001"), ({"mode": 0, "sel": 0}, "01000000")],
    ids=["true-no-body", "false-no-body"],
)
def test_a_split_when_with_no_body_value_still_packs(row: dict, packet: str):
    # Arrange
    scheme = _when_after_byte()

    # Act / Assert
    assert _pack(scheme, row) == packet


def test_a_condition_that_is_never_written_leaves_a_clear_bit_without_an_error():
    # Arrange
    byte = flag_byte()
    scheme = _scheme(byte, flags(0, _u8(0, "sel")), byte.bit(when(1, eq(0, 1), _u8(1, "speed"))))

    # Act
    packed = _pack(scheme, {"speed": 7})

    # Assert
    assert packed == "010000"


@pytest.mark.parametrize(
    "build,row,packet",
    [
        (_when_before_byte, {"mode": 1, "speed": 7, "heading": 90}, "010103075a00"),
        (_when_before_byte, {"mode": 0, "heading": 90}, "0100025a00"),
        (_when_before_byte, {"mode": 1, "heading": 90}, "0101025a00"),
        (_when_before_byte, {"mode": 0, "speed": 7, "heading": 90}, "0100025a00"),
        (_times_before_byte, {"n": 0, "heading": 90}, "0100025a00"),
        (_times_before_byte, {"n": 1, "pt": [5], "heading": 90}, "010103055a00"),
        (_times_before_byte, {"n": 2, "pt": [5, 6], "heading": 90}, "01020305065a00"),
    ],
    ids=["w-true", "w-false", "w-no-body", "w-false-body-given", "t-0", "t-1", "t-2"],
)
def test_ac4_reference_rows_with_the_source_before_the_byte_pack_as_before(build, row, packet):
    # Arrange
    scheme = build()

    # Act / Assert
    assert _pack(scheme, row) == packet


def test_a_value_outside_the_member_range_still_fails_naming_the_field():
    # Arrange
    row = {"n": 1, "pt": [300], "heading": 90}

    # Act / Assert
    with pytest.raises(OverflowError, match=r"^1: 300 does not fit in u8$"):
        _pack(_times_before_byte(), row)


def _two_whens_in_one_bit() -> Scheme:
    """One split bit holds two `when`s; `a` (field 0) is never given, `b` (field 1) is written after the byte."""
    byte = flag_byte()
    return _scheme(
        byte,
        byte.bit(_u8(0, "a")),
        _u8(1, "b"),
        byte.bit(group(2, when(2, eq(0, 1), _u8(2, "x")), when(3, eq(1, 1), _u8(3, "y")))),
    )


def test_ac1_second_when_of_a_split_bit_with_a_written_condition_and_a_body_is_refused():
    # Arrange
    row = {"b": 1, "y": 9}

    # Act / Assert
    with pytest.raises(ValueError, match=r"^when 3: a body value is given, but condition field 1 is written after"):
        _pack(_two_whens_in_one_bit(), row)


@pytest.mark.parametrize(
    "row,packet",
    [({"b": 0, "y": 9}, "010000"), ({"b": 1}, "010001"), ({"b": 0}, "010000")],
    ids=["second-false-body-given", "second-true-no-body", "second-false-no-body"],
)
def test_ac3_second_when_of_a_split_bit_stays_silent_when_false_or_without_a_body(row: dict, packet: str):
    # Arrange
    scheme = _two_whens_in_one_bit()

    # Act / Assert
    assert _pack(scheme, row) == packet
