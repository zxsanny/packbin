from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bool as flag_bool,
    dict as map_field,
    eq,
    flag_byte,
    flags,
    group,
    list as list_field,
    repeat,
    times,
    u8,
    u16,
    when,
)

FROM_TYPESCRIPT = "010901045a00"
TYPESCRIPT_SHORT = "010100"


def _scheme(*fields) -> Scheme:
    return Scheme(1, dict, *fields)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _u16(field_id: int, name: str):
    return u16(field_id, lambda row, name=name: row[name])


def _on(field_id: int):
    return flag_bool(field_id, lambda row: row["on"])


def _heading_scheme() -> Scheme:
    motion = flag_byte()
    return _scheme(
        _u8(0, "sid"),
        motion,
        when(1, eq(0, 9), _u8(1, "shape")),
        motion.bit(_u16(2, "heading")),
    )


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


def test_ac1_split_form_matches_typescript():
    scheme = _heading_scheme()

    full = BinaryPacker.pack(scheme, {"sid": 9, "shape": 4, "heading": 90}).hex()
    short = BinaryPacker.pack(scheme, {"sid": 1}).hex()

    assert (full, short) == (FROM_TYPESCRIPT, TYPESCRIPT_SHORT)


@pytest.mark.parametrize(
    "hex_bytes,expected",
    [(FROM_TYPESCRIPT, {"sid": 9, "shape": 4, "heading": 90}), (TYPESCRIPT_SHORT, {"sid": 1})],
    ids=["full", "short"],
)
def test_ac1_split_form_unpacks_the_typescript_bytes(hex_bytes: str, expected: dict):
    scheme = _heading_scheme()

    result = _unpack(scheme, hex_bytes)

    assert result.ok
    assert result.value == expected


def test_ac2_split_form_bool():
    flag = flag_byte()
    scheme = _scheme(flag, flag.bit(_on(0)))

    packed = [BinaryPacker.pack(scheme, row).hex() for row in ({"on": True}, {"on": False})]
    result = _unpack(scheme, "0101")

    assert packed == ["0101", "0100"]
    assert result.ok
    assert result.value["on"] is True


def test_ac2_split_form_clear_bit_leaves_the_bool_out():
    flag = flag_byte()
    scheme = _scheme(flag, flag.bit(_on(0)))

    result = _unpack(scheme, "0100")

    assert result.ok
    assert "on" not in result.value


def test_ac3_bit_before_flag_byte_is_scheme_error():
    flag = flag_byte()
    bit = flag.bit(_u8(0, "a"))

    with pytest.raises(ValueError, match=r"flag bit 0\b.*flag byte"):
        _scheme(bit, flag)


def test_ac3_bit_whose_flag_byte_is_not_in_the_scheme_is_scheme_error():
    flag = flag_byte()
    bit = flag.bit(_u8(0, "a"))

    with pytest.raises(ValueError, match=r"flag bit 0\b.*flag byte"):
        _scheme(bit)


def test_ac3_flag_byte_listed_without_its_bits_leaves_them_clear():
    flag = flag_byte()
    flag.bit(_on(0))
    scheme = _scheme(flag)

    packed = BinaryPacker.pack(scheme, {"on": True}).hex()

    assert packed == "0100"


def test_flag_byte_takes_no_id_and_each_bit_is_checked_at_its_place():
    flag = flag_byte()
    bit = flag.bit(_u8(5, "a"))

    with pytest.raises(ValueError, match="field id 5 is not the next order 0"):
        _scheme(flag, bit)


def test_flag_byte_read_inside_a_when_is_not_visible_after_it():
    flag = flag_byte()
    bit = flag.bit(_u8(2, "b"))

    with pytest.raises(ValueError, match=r"flag bit 2\b.*flag byte"):
        _scheme(_u8(0, "k"), when(1, eq(0, 1), flag, _u8(1, "a")), bit)


def test_flag_byte_outside_a_repeat_is_not_visible_inside_it():
    flag = flag_byte()
    bit = flag.bit(_u8(0, "v"))

    with pytest.raises(ValueError, match=r"flag bit 0\b.*flag byte"):
        _scheme(flag, repeat(0, bit))


def test_flag_byte_outside_a_list_element_is_not_visible_inside_it():
    flag = flag_byte()
    bit = flag.bit(_u8(0, "v"))

    with pytest.raises(ValueError, match=r"flag bit 0\b.*flag byte"):
        _scheme(flag, list_field(lambda row: row["xs"], bit))


def test_flag_byte_outside_a_times_is_not_visible_inside_it():
    flag = flag_byte()
    bit = flag.bit(_u8(1, "v"))

    with pytest.raises(ValueError, match=r"flag bit 1\b.*flag byte"):
        _scheme(_u8(0, "n"), flag, times(1, 0, bit))


def test_flag_byte_in_a_when_serves_bits_inside_that_when():
    flag = flag_byte()
    scheme = _scheme(_u8(0, "k"), when(1, eq(0, 1), flag, flag.bit(_u8(1, "v"))))

    taken = BinaryPacker.pack(scheme, {"k": 1, "v": 5}).hex()
    skipped = BinaryPacker.pack(scheme, {"k": 0}).hex()

    assert (taken, skipped) == ("01010105", "0100")


def test_bit_inside_a_when_uses_the_flag_byte_read_before_the_when():
    flag = flag_byte()
    scheme = _scheme(_u8(0, "k"), flag, when(1, eq(0, 1), flag.bit(_u8(1, "v"))))

    not_taken = BinaryPacker.pack(scheme, {"k": 0, "v": 5}).hex()
    taken = BinaryPacker.pack(scheme, {"k": 1, "v": 5}).hex()
    back = _unpack(scheme, not_taken)

    assert (not_taken, taken) == ("010001", "01010105")
    assert back.ok
    assert back.value == {"k": 0}


def test_flag_byte_read_in_each_round_serves_the_bits_of_that_round():
    flag = flag_byte()
    scheme = _scheme(repeat(0, flag, flag.bit(_u8(0, "v"))))

    packed = BinaryPacker.pack(scheme, {"v": [5, None, 7]}).hex()
    back = _unpack(scheme, packed)

    assert packed == "010105000107"
    assert back.ok
    assert back.value["v"] == [5, None, 7]


def test_flag_byte_with_a_group_bit_round_trips():
    flag = flag_byte()
    scheme = _scheme(flag, flag.bit(group(0, _u8(0, "a"), _u8(1, "b"))))

    packed = BinaryPacker.pack(scheme, {"a": 1, "b": 2}).hex()
    back = _unpack(scheme, packed)

    assert packed == "01010102"
    assert back.value == {"a": 1, "b": 2}


def test_ids_continue_through_a_split_byte_a_flags_group_and_a_bit():
    flag = flag_byte()
    scheme = _scheme(
        flag,
        flags(0, _on(0), _u8(1, "n")),
        flag.bit(_u16(2, "h")),
        map_field(lambda row: row["d"], _u8(0, "v")),
    )

    packed = BinaryPacker.pack(scheme, {"on": True, "n": 3, "h": 1, "d": {}}).hex()

    assert packed == "0101" + "0303" + "0100" + "0000"


def test_flag_byte_and_bit_inside_a_list_element_round_trip():
    flag = flag_byte()
    scheme = _scheme(list_field(lambda row: row["xs"], group(0, flag, flag.bit(_u8(0, "v")))))

    packed = BinaryPacker.pack(scheme, {"xs": [{"v": 5}, {}]}).hex()
    result = _unpack(scheme, packed)

    assert packed == "0102000105" + "00"
    assert result.ok
    assert result.value == {"xs": [{"v": 5}, {}]}

