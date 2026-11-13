"""AZ-4258: a required member with no value is refused by its name, and a `None` item of a list or dict of rows is
refused by the list's name, not by a raw `TypeError` from the accessor. A present value of the wrong type, and a
list of plain values that holds `None`, keep the messages they had."""

from __future__ import annotations

from typing import Any

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bits,
    bytes as bytes_field,
    dict as map_field,
    group,
    list as list_field,
    packed,
    sized,
    u8,
    utf8,
)


class Holder:
    def __init__(self, text: Any = None) -> None:
        self.text = text


def _refused(scheme: Scheme[Any], row: Any) -> tuple[type[BaseException], str]:
    with pytest.raises(Exception) as raised:
        BinaryPacker.pack(scheme, row)
    return type(raised.value), str(raised.value)


def _text_row() -> Scheme[Any]:
    return Scheme(1, dict, u8(0, lambda r: r["n"]), utf8(1, lambda r: r["text"]))


@pytest.mark.parametrize("row", [{"n": 1}, {"n": 1, "text": None}], ids=["absent", "none"])
def test_a_missing_text_is_named_by_its_key(row):
    assert _refused(_text_row(), row) == (TypeError, "missing text")


def test_a_missing_text_of_a_typed_row_is_named_by_its_attribute():
    scheme = Scheme(1, Holder, utf8(0, lambda r: r.text))

    assert _refused(scheme, Holder()) == (TypeError, "missing text")


def test_a_wrong_type_text_keeps_its_message():
    assert _refused(_text_row(), {"n": 1, "text": 5}) == (TypeError, "1: expected str")


def test_a_present_text_still_packs():
    assert BinaryPacker.pack(_text_row(), {"n": 1, "text": "a"}).hex() == "0101021061"


def test_a_missing_sized_bits_and_packed_member_are_named_too():
    sized_scheme = Scheme(1, dict, u8(0, lambda r: r["n"]), sized(1, lambda r: r["blob"], 0))
    bits_scheme = Scheme(1, dict, u8(0, lambda r: r["n"]), bits(1, lambda r: r["flags"], 0))
    packed_scheme = Scheme(1, dict, u8(0, lambda r: r["n"]), packed(2, 1, lambda r: r["crumbs"], 0))

    assert _refused(sized_scheme, {"n": 2}) == (TypeError, "missing blob")
    assert _refused(bits_scheme, {"n": 2}) == (TypeError, "missing flags")
    assert _refused(packed_scheme, {"n": 2}) == (TypeError, "missing crumbs")


def test_a_wrong_type_sized_member_keeps_its_message():
    scheme = Scheme(1, dict, u8(0, lambda r: r["n"]), sized(1, lambda r: r["blob"], 0))

    assert _refused(scheme, {"n": 2, "blob": "ab"}) == (TypeError, "1: expected bytes")


def _row_element() -> Any:
    return group(0, u8(0, lambda r: r["id"]), utf8(1, lambda r: r["text"]))


def _listed() -> Scheme[Any]:
    return Scheme(1, dict, list_field(lambda r: r["items"], _row_element()))


def _keyed() -> Scheme[Any]:
    return Scheme(1, dict, map_field(lambda r: r["map"], _row_element()))


def test_a_missing_member_of_an_element_row_is_named():
    assert _refused(_listed(), {"items": [{"id": 1}]}) == (TypeError, "missing text")


@pytest.mark.parametrize("items", [[None], [{"id": 1, "text": "a"}, None]], ids=["only", "second"])
def test_a_none_item_of_a_list_of_rows_is_refused_by_the_list_name(items):
    assert _refused(_listed(), {"items": items}) == (TypeError, "items: an item has no value")


@pytest.mark.parametrize("mapping", [{"a": None}, {"a": {"id": 1, "text": "a"}, "b": None}], ids=["only", "second"])
def test_a_none_value_of_a_dict_of_rows_is_refused_by_the_dict_name(mapping):
    assert _refused(_keyed(), {"map": mapping}) == (TypeError, "map: an item has no value")


def test_a_none_item_of_a_list_of_rows_inside_a_list_of_lists_is_refused_by_the_inner_name():
    scheme = Scheme(1, dict, list_field(lambda r: r["outer"], list_field(lambda r: r["inner"], _row_element())))

    assert _refused(scheme, {"outer": [[None]]}) == (TypeError, "inner: an item has no value")


@pytest.mark.parametrize(
    ("kind", "element", "good", "message"),
    [
        ("u8", lambda: u8(0, lambda r: r), 1, "0: expected int, got NoneType"),
        ("utf8", lambda: utf8(0, lambda r: r), "a", "0: expected str"),
        ("bytes", lambda: bytes_field(0, lambda r: r, 2), b"ab", "0: expected bytes"),
    ],
)
def test_a_list_or_dict_of_plain_values_that_holds_none_keeps_its_message(kind, element, good, message):
    listed = Scheme(1, dict, list_field(lambda r: r["x"], element()))
    keyed = Scheme(1, dict, map_field(lambda r: r["x"], element()))

    assert _refused(listed, {"x": [good, None]}) == (TypeError, message)
    assert _refused(listed, {"x": [None]}) == (TypeError, message)
    assert _refused(keyed, {"x": {"a": None}}) == (TypeError, message)
