from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, eq, flags, times, u8, when
from packbin import dict as map_field
from packbin import list as list_field

from test_borrowed_count import ROUTE, _route


def _scheme(*fields) -> Scheme:
    return Scheme(1, dict, u8(0, lambda row: row["a"]), *fields)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _one_member() -> Scheme:
    return _scheme(times(1, 0, _u8(1, "x")))


def _two_members() -> Scheme:
    return _scheme(times(1, 0, _u8(1, "x"), _u8(2, "y")))


def _under_when() -> Scheme:
    return _scheme(times(1, 0, _u8(1, "k"), when(2, eq(1, 1), _u8(2, "v"))))


def _under_flags() -> Scheme:
    return _scheme(times(1, 0, flags(1, _u8(1, "f"))))


def _list_member() -> Scheme:
    return _scheme(times(1, 0, list_field(lambda row: row["xs"], _u8(0, "v"))))


def _dict_member() -> Scheme:
    return _scheme(times(1, 0, map_field(lambda row: row["m"], _u8(0, "v"))))


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def test_ac1_a_longer_list_is_refused():
    with pytest.raises(ValueError, match=r"^1: 3 items, times count is 2$"):
        BinaryPacker.pack(_one_member(), {"a": 2, "x": [1, 2, 3]})


def test_ac2_count_zero_refuses_a_non_empty_list():
    with pytest.raises(ValueError, match=r"^1: 1 items, times count is 0$"):
        BinaryPacker.pack(_one_member(), {"a": 0, "x": [1]})


@pytest.mark.parametrize("row", [{"a": 0, "x": []}, {"a": 0}], ids=["empty", "absent"])
def test_ac2_count_zero_packs_an_empty_or_absent_list(row: dict):
    assert _pack(_one_member(), row) == "0100"


@pytest.mark.parametrize(
    "build,row,field",
    [
        (_two_members, {"a": 2, "x": [1, 2], "y": [3, 4, 5]}, "2"),
        (_under_when, {"a": 1, "k": [1], "v": [7, 8]}, "2"),
        (_under_flags, {"a": 2, "f": [1, 2, 3]}, "1"),
    ],
    ids=["second_member", "under_when", "under_flags"],
)
def test_ac3_any_member_of_the_body_is_checked(build, row: dict, field: str):
    with pytest.raises(ValueError, match=rf"^{field}: \d items, times count is \d$"):
        BinaryPacker.pack(build(), row)


def test_ac3_a_list_under_a_when_that_does_not_match_is_still_checked():
    with pytest.raises(ValueError, match=r"^2: 2 items, times count is 1$"):
        BinaryPacker.pack(_under_when(), {"a": 1, "k": [0], "v": [7, 8]})


@pytest.mark.parametrize(
    "build,row,expected",
    [
        (_one_member, {"a": 2, "x": [1, 2]}, "01020102"),
        (_one_member, {"a": 2, "x": 5}, "01020505"),
        (_two_members, {"a": 2, "x": [1, 2], "y": [3, 4]}, "010201030204"),
        (_under_when, {"a": 2, "k": [1, 0], "v": [7]}, "0102010700"),
        (_under_flags, {"a": 2, "f": [1, 2]}, "010201010102"),
    ],
    ids=["exact", "lone_scalar", "two_members", "when", "flags"],
)
def test_ac4_valid_rows_are_unchanged(build, row: dict, expected: str):
    assert _pack(build(), row) == expected


@pytest.mark.parametrize(
    "build,row,label",
    [
        (_list_member, {"a": 2, "xs": [[1], [2], [3]]}, "list"),
        (_dict_member, {"a": 2, "m": [{"k": 1}, {"k": 2}, {"k": 3}]}, "dict"),
    ],
    ids=["list", "dict"],
)
def test_ac3_a_list_or_dict_member_is_checked_by_its_kind(build, row: dict, label: str):
    with pytest.raises(ValueError, match=rf"^{label}: 3 items, times count is 2$"):
        BinaryPacker.pack(build(), row)


def test_ac4_a_list_member_with_one_list_per_round_packs_unchanged():
    assert _pack(_list_member(), {"a": 2, "xs": [[1], [2]]}) == "0102010001010002"


def test_ac5_a_shorter_list_keeps_its_failure():
    with pytest.raises(IndexError):
        BinaryPacker.pack(_one_member(), {"a": 2, "x": [1]})


def test_ac6_an_unpacked_row_packs_again():
    scheme = _one_member()
    got = BinaryPacker.unpack(bytes.fromhex("01020102"), scheme.on(lambda _row: None))

    assert got.ok
    assert _pack(scheme, got.value) == "01020102"


def test_ac6_the_route_row_packs_unchanged():
    layout = _route()
    got = BinaryPacker.unpack(bytes.fromhex(ROUTE), layout.on(lambda _row: None))

    assert got.ok
    assert _pack(layout, got.value) == ROUTE
