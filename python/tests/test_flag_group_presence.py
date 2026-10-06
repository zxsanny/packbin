from __future__ import annotations

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    flag_byte,
    flags,
    group,
    repeat,
    u2,
    u8,
)


def _scheme(*fields) -> Scheme:
    return Scheme(1, dict, *fields)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _pq():
    return u2((0, lambda row: row["p"]), (1, lambda row: row["q"]))


def _unpack(scheme: Scheme, hex_bytes: str):
    return BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))


def test_ac1_a_group_holding_only_a_u2_sets_its_bit_and_round_trips():
    scheme = _scheme(flags(0, group(0, _pq())))

    packed = BinaryPacker.pack(scheme, {"p": 1, "q": 2}).hex()
    result = _unpack(scheme, packed)

    assert packed == "010109"
    assert result.ok
    assert result.value == {"p": 1, "q": 2}


def test_ac1_a_u2_directly_under_flags_sets_its_bit():
    scheme = _scheme(flags(0, _pq()))

    packed = BinaryPacker.pack(scheme, {"p": 1, "q": 2}).hex()

    assert packed == "010109"


def test_ac1_a_u2_in_a_split_form_bit_sets_the_bit():
    flag = flag_byte()
    scheme = _scheme(flag, flag.bit(_pq()))

    packed = BinaryPacker.pack(scheme, {"p": 1, "q": 2}).hex()
    result = _unpack(scheme, packed)

    assert packed == "010109"
    assert result.value == {"p": 1, "q": 2}


def test_ac1_a_group_holding_only_a_nested_flags_sets_its_bit_and_round_trips():
    scheme = _scheme(flags(0, group(0, flags(0, _u8(0, "b")))))

    packed = BinaryPacker.pack(scheme, {"b": 5}).hex()
    result = _unpack(scheme, packed)

    assert packed == "01010105"
    assert result.ok
    assert result.value == {"b": 5}


def test_ac1_a_group_holding_only_a_nested_group_still_sets_its_bit():
    scheme = _scheme(flags(0, group(0, group(0, _u8(0, "b")))))

    packed = BinaryPacker.pack(scheme, {"b": 5}).hex()

    assert packed == "010105"


def test_ac1_a_clear_group_stays_clear():
    scheme = _scheme(flags(0, group(0, _pq()), _u8(2, "n")))

    packed = BinaryPacker.pack(scheme, {"n": 7}).hex()

    assert packed == "010207"


def test_ac1_a_u2_group_under_a_round_sets_the_bit_of_the_round_that_holds_it():
    scheme = _scheme(repeat(0, flags(0, group(0, _pq()))))

    packed = BinaryPacker.pack(scheme, {"p": [1, None], "q": [2, None]}).hex()
    result = _unpack(scheme, packed)

    assert packed == "010109" + "00"
    assert result.ok
    assert result.value == {"p": [1, None], "q": [2, None]}


def test_ac2_a_missing_sibling_of_a_nested_flags_value_fails_pack_naming_it():
    scheme = _scheme(flags(0, group(0, _u8(0, "a"), flags(1, _u8(1, "b")))))

    with pytest.raises(KeyError, match="missing field 0"):
        BinaryPacker.pack(scheme, {"b": 5})


def test_ac2_a_missing_u2_slot_fails_pack_naming_it():
    scheme = _scheme(flags(0, group(0, _pq())))

    with pytest.raises(ValueError, match=r"^1: expected 2-bit int$"):
        BinaryPacker.pack(scheme, {"p": 1})


def test_ac2_a_group_with_every_value_missing_packs_a_clear_bit():
    scheme = _scheme(flags(0, group(0, _u8(0, "a"), flags(1, _u8(1, "b")))))

    assert BinaryPacker.pack(scheme, {}).hex() == "0100"
