from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, ShortPacket, bytes as raw_bytes, dict as map_field, eq, list as list_field, u8, when

from hostile_support import assert_rejected, error_kind, unpack_guarded


def _scheme(field) -> Scheme:
    return Scheme(1, dict, field)


def _empty_bytes():
    return raw_bytes(0, lambda row: row["b"], 0)


def _list_of(element) -> Scheme:
    return _scheme(list_field(lambda row: row["xs"], element))


def _dict_of(element) -> Scheme:
    return _scheme(map_field(lambda row: row["d"], element))


def _never_matches():
    return when(0, eq(0, 9), u8(0, lambda row: row["v"]))


def _assert_bad_value(scheme: Scheme, hex_bytes: str, left: int) -> None:
    result, seen, elapsed = unpack_guarded(scheme, bytes.fromhex(hex_bytes))
    assert_rejected(result, seen, elapsed)
    assert result.error == ShortPacket(field="", needed=0, left=left)
    assert error_kind(result) == "bad_value"


def test_zero_width_list_element_is_error():
    nested = _list_of(list_field(lambda row: row["ys"], _empty_bytes()))
    _assert_bad_value(nested, "01ffffffff", 0)


def test_zero_width_list_element_single_level_is_error():
    _assert_bad_value(_list_of(_empty_bytes()), "01ffff", 0)


def test_zero_width_list_element_deep_nesting_is_error():
    deep = _list_of(list_field(lambda row: row["ys"], list_field(lambda row: row["zs"], _empty_bytes())))
    _assert_bad_value(deep, "01ffff0100010001000100", 4)


def test_zero_width_dict_value_is_error():
    _assert_bad_value(_dict_of(_empty_bytes()), "01ffff01006100", 1)
    _assert_bad_value(_dict_of(_empty_bytes()), "010100" "01006100", 1)


def test_never_matching_when_element_is_error():
    _assert_bad_value(_list_of(_never_matches()), "010300", 0)
    _assert_bad_value(_list_of(_never_matches()), "0103000a", 1)


@pytest.mark.parametrize("make", [_list_of, _dict_of], ids=["list", "dict"])
def test_empty_container_of_zero_width_still_unpacks(make):
    layout = make(_empty_bytes())
    got = BinaryPacker.unpack(bytes.fromhex("010000"), layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert list(got.value.values()) == [[] if make is _list_of else {}]
