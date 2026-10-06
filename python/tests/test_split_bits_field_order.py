from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    eq,
    flag_byte,
    flags,
    group,
    i16,
    i32,
    repeat,
    u8,
    u16,
    when,
)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


def _row(scheme: Scheme, hex_bytes: str) -> dict:
    result = _unpack(scheme, hex_bytes)
    assert result.ok, result.error
    return result.value


def test_ac1_one_handle_is_a_member_of_two_schemes():
    # Arrange
    m = flag_byte()
    first = Scheme(1, dict, m, m.bit(_u8(0, "x")))
    second = Scheme(2, dict, m, m.bit(_u8(0, "x")))

    # Act
    packed = (_pack(first, {"x": 5}), _pack(second, {"x": 5}))
    first_again = _pack(first, {"x": 5})

    # Assert
    assert packed == ("010105", "020105")
    assert first_again == "010105"


def test_ac2_numbers_follow_the_scheme_not_the_order_of_the_calls():
    # Arrange
    m = flag_byte()
    late = m.bit(_u8(1, "b"))
    early = m.bit(_u8(0, "a"))
    scheme = Scheme(1, dict, m, early, late)

    # Act
    packed = _pack(scheme, {"b": 9})
    from_early = _row(scheme, "010109")
    from_late = _row(scheme, "010209")

    # Assert
    assert packed == "010209"
    assert from_early == {"a": 9}
    assert from_late == {"b": 9}


def test_ac3_a_second_read_starts_its_own_bits():
    # Arrange
    m = flag_byte()
    scheme = Scheme(1, dict, m, m.bit(_u8(0, "a")), m, m.bit(_u8(1, "b")))

    # Act
    only_b = _pack(scheme, {"b": 9})
    both = _pack(scheme, {"a": 3, "b": 9})
    limited = _pack(scheme.with_limits(max_rounds=3), {"b": 9})

    # Assert
    assert (only_b, both, limited) == ("01000109", "0101030109", "01000109")
    assert _row(scheme, "01000109") == {"b": 9}
    assert _row(scheme, "0101030109") == {"a": 3, "b": 9}


def _five_bits(m, type_number: int) -> Scheme:
    return Scheme(type_number, dict, m, *[m.bit(_u8(i, f"f{i}")) for i in range(5)])


def test_ac4_a_handle_shared_by_two_five_bit_schemes_builds_both():
    # Arrange
    m = flag_byte()
    first = _five_bits(m, 1)
    second = _five_bits(m, 2)

    # Act
    packed = (_pack(first, {"f4": 7}), _pack(second, {"f0": 3, "f4": 7}))

    # Assert
    assert packed == ("011007", "02110307")
    assert _row(first, "011007") == {"f4": 7}
    assert _row(second, "02110307") == {"f0": 3, "f4": 7}


def test_ac5_a_flag_byte_read_twice_holds_eight_bits_each():
    # Arrange
    m = flag_byte()
    a = [m.bit(_u8(i, f"a{i}")) for i in range(8)]
    b = [m.bit(_u8(8 + i, f"b{i}")) for i in range(8)]
    scheme = Scheme(1, dict, m, *a, m, *b)

    # Act
    packed = _pack(scheme, {"a7": 1, "b0": 2})

    # Assert
    assert packed == "0180010102"
    assert _row(scheme, packed) == {"a7": 1, "b0": 2}


def test_ac6_the_ninth_bit_of_one_read_is_refused_by_the_scheme_not_by_bit():
    # Arrange
    m = flag_byte()

    # Act
    bits = [m.bit(_u8(i, f"f{i}")) for i in range(9)]

    # Assert
    with pytest.raises(ValueError, match="flags already has 8 bits"):
        Scheme(1, dict, m, *bits)


def test_ac6_the_ninth_bit_is_counted_across_a_when_that_follows_the_read():
    # Arrange
    m = flag_byte()
    before = [m.bit(_u8(1 + i, f"f{i}")) for i in range(4)]
    inside = [m.bit(_u8(5 + i, f"f{4 + i}")) for i in range(5)]

    # Act and assert
    with pytest.raises(ValueError, match="flags already has 8 bits"):
        Scheme(1, dict, _u8(0, "k"), m, *before, when(5, eq(0, 1), *inside))


def test_ac6_eight_bits_in_one_read_build():
    # Arrange
    m = flag_byte()
    bits = [m.bit(_u8(i, f"f{i}")) for i in range(8)]

    # Act
    scheme = Scheme(1, dict, m, *bits)

    # Assert
    assert _pack(scheme, {"f7": 1}) == "018001"


def _read_inside_a_when() -> Scheme:
    m = flag_byte()
    return Scheme(
        1,
        dict,
        _u8(0, "k"),
        m,
        when(1, eq(0, 1), m, m.bit(_u8(1, "x"))),
        m.bit(_u8(2, "y")),
    )


def test_ac7_a_byte_read_inside_a_taken_when_does_not_change_the_outer_byte():
    # Arrange
    scheme = _read_inside_a_when()

    # Act
    taken = _pack(scheme, {"k": 1, "x": 5, "y": 6})
    skipped = _pack(scheme, {"k": 0, "y": 6})

    # Assert
    assert (taken, skipped) == ("010101010506", "01000106")
    assert _row(scheme, "010101010506") == {"k": 1, "x": 5, "y": 6}
    assert _row(scheme, "01000106") == {"k": 0, "y": 6}


def test_ac8_a_bit_nested_in_another_bits_field_is_numbered_after_the_outer_one():
    # Arrange
    m = flag_byte()
    scheme = Scheme(1, dict, m, m.bit(group(0, _u8(0, "y"), m.bit(_u8(1, "x")))))

    # Act
    without_x = _pack(scheme, {"y": 1})
    with_x = _pack(scheme, {"y": 1, "x": 2})

    # Assert
    assert (without_x, with_x) == ("010101", "01030102")
    assert _row(scheme, "010101") == {"y": 1}
    assert _row(scheme, "01030102") == {"y": 1, "x": 2}


def test_ac9_a_bit_that_is_not_placed_leaves_its_bit_clear():
    # Arrange
    m = flag_byte()
    m.bit(_u8(0, "x"))

    # Act
    scheme = Scheme(1, dict, m)

    # Assert
    assert _pack(scheme, {}) == "0100"


def test_ac10_the_same_nodes_in_two_schemes_pack_alike_and_stay_unchanged():
    # Arrange
    m = flag_byte()
    bit = m.bit(_u8(0, "x"))
    first = Scheme(1, dict, m, bit)
    second = Scheme(2, dict, m, bit)

    # Act
    packed = (_pack(first, {"x": 5}), _pack(second, {"x": 5}))
    again = Scheme(3, dict, m, bit)

    # Assert
    assert packed == ("010105", "020105")
    assert _pack(again, {"x": 5}) == "030105"


def test_ac10_a_when_bit_after_the_read_keeps_its_bytes():
    # Arrange
    m = flag_byte()
    scheme = Scheme(1, dict, _u8(0, "k"), m, when(1, eq(0, 1), m.bit(_u8(1, "v"))))

    # Act
    not_taken = _pack(scheme, {"k": 0, "v": 5})
    taken = _pack(scheme, {"k": 1, "v": 5})

    # Assert
    assert (not_taken, taken) == ("010001", "01010105")
    assert _row(scheme, not_taken) == {"k": 0}


def test_ac10_a_round_that_reads_its_byte_every_round_keeps_its_bytes():
    # Arrange
    m = flag_byte()
    scheme = Scheme(1, dict, repeat(0, m, m.bit(_u8(0, "v"))))

    # Act
    packed = _pack(scheme, {"v": [5, None, 7]})

    # Assert
    assert packed == "010105000107"
    assert _row(scheme, packed) == {"v": [5, None, 7]}


def _position(split: bool) -> Scheme:
    head = [
        u16(0, lambda row: row["sid"]),
        i32(1, lambda row: row["lat"]),
        i32(2, lambda row: row["lon"]),
        u8(3, lambda row: row["profile"]),
    ]
    heading = u16(4, lambda row: row["heading"])
    speed = u8(5, lambda row: row["speed"])
    altitude = i16(6, lambda row: row["altitude"])
    if not split:
        return Scheme(0x40, dict, *head, flags(4, heading, speed, altitude))
    m = flag_byte()
    return Scheme(0x40, dict, *head, m, m.bit(heading), m.bit(speed), m.bit(altitude))


def test_ac10_the_position_scheme_in_split_form_packs_the_golden_bytes():
    # Arrange
    split = _position(split=True)
    combined = _position(split=False)
    clear = {"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1}
    full = {**clear, "heading": 90, "speed": 7, "altitude": -2}

    # Act
    packed = (_pack(split, clear), _pack(split, full))

    # Assert
    assert packed == ("4001000065cd1d00a3e1110100", _pack(combined, full))
    assert _row(split, packed[1]) == full


def test_a_flag_byte_read_inside_a_group_serves_a_bit_after_the_group():
    # Arrange
    m = flag_byte()
    scheme = Scheme(1, dict, group(0, m), m.bit(_u8(0, "x")))

    # Act
    packed = _pack(scheme, {"x": 5})

    # Assert
    assert packed == "010105"
    assert _row(scheme, packed) == {"x": 5}
