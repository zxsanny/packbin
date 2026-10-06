from __future__ import annotations

import operator

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    be,
    bool as flag_bool,
    dict as map_field,
    eq,
    flag_byte,
    flags,
    group,
    list as list_field,
    times,
    u2,
    u8,
    u16,
    when,
)


class Pt:
    def __init__(self, x: int = 0) -> None:
        self.x = x


class Row:
    def __init__(self, pts=None) -> None:
        self.pts = pts


def _message(holder: str, what: str, name: str) -> str:
    return (
        f"{holder} element: {what} uses the attribute accessor '{name}'; "
        f"an element row is a dict, so use a key accessor, row['{name}']"
    )


def _refused(*fields, row_type=Row) -> str:
    with pytest.raises(ValueError) as caught:
        Scheme(1, row_type, *fields)
    return str(caught.value)


def _points(element):
    return list_field(lambda r: r.pts, element)


def _unpacked(scheme: Scheme, hex_bytes: str):
    result = BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))
    assert result.ok, result.error
    return result.value


def test_ac1_a_list_element_group_with_an_attribute_accessor_is_refused():
    assert _refused(_points(group(0, u8(0, lambda p: p.x)))) == _message("list", "field 0", "x")


def test_ac2_a_dict_element_group_with_an_attribute_accessor_is_refused():
    scheme_field = map_field(lambda r: r.pts, group(0, u8(0, lambda p: p.x)))

    assert _refused(scheme_field) == _message("dict", "field 0", "x")


ELEMENT_SHAPES = {
    "flags": (lambda: flags(0, u8(0, lambda p: p.x)), "field 0", "x"),
    "u2": (lambda: u2((0, lambda p: p["a"]), (1, lambda p: p.b)), "field 1", "b"),
    "group_in_group": (lambda: group(0, group(0, u8(0, lambda p: p.x))), "field 0", "x"),
    "when_body": (
        lambda: group(0, u8(0, lambda p: p["k"]), when(1, eq(0, 1), u8(1, lambda p: p.y))),
        "field 1",
        "y",
    ),
    "times_body": (
        lambda: group(0, u8(0, lambda p: p["n"]), times(1, 0, u8(1, lambda p: p.v))),
        "field 1",
        "v",
    ),
    "bool_under_flags": (lambda: flags(0, flag_bool(0, lambda p: p.on)), "field 0", "on"),
    "one_key_one_attribute": (
        lambda: group(0, u8(0, lambda p: p["k"]), u8(1, lambda p: p.v)),
        "field 1",
        "v",
    ),
    "nested_list": (
        lambda: group(0, list_field(lambda p: p.inner, u8(0, lambda z: z))),
        "a nested list",
        "inner",
    ),
    "nested_dict": (
        lambda: group(0, map_field(lambda p: p.inner, u8(0, lambda z: z))),
        "a nested dict",
        "inner",
    ),
    "big_endian": (lambda: group(0, be(u16(0, lambda p: p.x))), "field 0", "x"),
}


@pytest.mark.parametrize("make,what,name", ELEMENT_SHAPES.values(), ids=ELEMENT_SHAPES.keys())
def test_ac3_every_place_the_element_scope_holds_an_attribute_accessor(make, what, name):
    assert _refused(_points(make())) == _message("list", what, name)


def _the_list():
    return _points(group(0, u8(0, lambda p: p.x)))


PLACEMENTS = {
    "when_body": lambda: (u8(0, lambda r: r.k), when(1, eq(0, 1), _the_list())),
    "under_flags": lambda: (flags(0, _the_list()),),
    "flag_bit": lambda: _flag_bit_placement(),
    "times_body": lambda: (u8(0, lambda r: r.n), times(1, 0, _the_list())),
}


def _flag_bit_placement():
    m = flag_byte()
    return (m, m.bit(_the_list()))


@pytest.mark.parametrize("make", PLACEMENTS.values(), ids=PLACEMENTS.keys())
def test_ac3_the_list_is_found_in_a_when_flags_a_flag_bit_and_a_times_body(make):
    assert _refused(*make()) == _message("list", "field 0", "x")


def test_ac4_a_list_of_a_list_names_the_inner_container():
    inner = list_field(lambda p: p["q"], group(0, u8(0, lambda p: p.x)))

    assert _refused(_points(inner)) == _message("list", "field 0", "x")


def test_ac4_a_list_of_a_dict_names_the_dict():
    inner = map_field(lambda p: p["q"], group(0, u8(0, lambda p: p.x)))

    assert _refused(_points(inner)) == _message("dict", "field 0", "x")


def test_ac4_a_dict_of_a_list_names_the_list():
    inner = list_field(lambda p: p["q"], group(0, u8(0, lambda p: p.x)))

    assert _refused(map_field(lambda r: r.m, inner)) == _message("list", "field 0", "x")


def test_ac5_a_dict_row_with_key_accessors_in_a_list_group_keeps_its_bytes_and_rows():
    scheme = Scheme(1, dict, list_field(lambda r: r["pts"], group(0, u8(0, lambda p: p["x"]))))
    row = {"pts": [{"x": 1}, {"x": 2}]}

    assert BinaryPacker.pack(scheme, row).hex() == "0102000102"
    assert _unpacked(scheme, "0102000102") == row


def test_ac5_a_dict_row_with_key_accessors_in_a_dict_group_keeps_its_bytes_and_rows():
    scheme = Scheme(1, dict, map_field(lambda r: r["m"], group(0, u8(0, lambda p: p["x"]))))

    assert BinaryPacker.pack(scheme, {"m": {"y": {"x": 3}, "x": {"x": 1}}}).hex() == "0102000100780101007903"
    assert _unpacked(scheme, "0102000100780101007903") == {"m": {"x": {"x": 1}, "y": {"x": 3}}}


def test_ac5_a_list_of_flags_with_key_accessors_keeps_its_bytes_and_rows():
    scheme = Scheme(
        1,
        dict,
        list_field(lambda r: r["l"], flags(0, u8(0, lambda p: p["a"]), u16(1, lambda p: p["b"]))),
    )
    row = {"l": [{"a": 1}, {}, {"b": 2}]}

    assert BinaryPacker.pack(scheme, row).hex() == "010300010100020200"
    assert _unpacked(scheme, "010300010100020200") == row


def test_ac5_a_typed_row_with_an_attribute_accessor_on_the_list_and_key_accessors_inside():
    scheme = Scheme(1, Row, _points(group(0, u8(0, lambda p: p["x"]))))

    assert BinaryPacker.pack(scheme, Row([{"x": 1}, {"x": 2}])).hex() == "0102000102"
    assert _unpacked(scheme, "0102000102").pts == [{"x": 1}, {"x": 2}]


def test_ac5_nested_groups_with_key_accessors_keep_their_bytes():
    inner = group(1, u8(1, lambda p: p["b"]))
    scheme = Scheme(1, dict, list_field(lambda r: r["l"], group(0, u8(0, lambda p: p["a"]), inner)))

    assert BinaryPacker.pack(scheme, {"l": [{"a": 1, "b": 2}]}).hex() == "0101000102"


def test_ac6_a_leaf_element_with_an_attribute_accessor_builds_and_round_trips():
    scheme = Scheme(1, Row, _points(u8(0, lambda p: p.x)))

    assert BinaryPacker.pack(scheme, Row([1, 2])).hex() == "0102000102"
    assert _unpacked(scheme, "0102000102").pts == [1, 2]


def test_ac6_a_leaf_element_with_the_identity_accessor_builds_and_round_trips():
    scheme = Scheme(1, dict, list_field(lambda r: r["xs"], u16(0, lambda r: r)))

    assert BinaryPacker.pack(scheme, {"xs": [1, 2]}).hex() == "01020001000200"
    assert _unpacked(scheme, "01020001000200") == {"xs": [1, 2]}


def test_ac6_an_inner_container_that_is_an_element_has_an_unchecked_accessor():
    scheme = Scheme(1, Row, _points(list_field(lambda p: p.q, u8(0, lambda z: z.v))))

    assert BinaryPacker.pack(scheme, Row([[1, 2]])).hex() == "01010002000102"
    assert _unpacked(scheme, "01010002000102").pts == [[1, 2]]


def test_ac6_an_attribute_group_that_is_not_an_element_builds():
    scheme = Scheme(1, Pt, group(0, u8(0, lambda p: p.x)))

    assert BinaryPacker.pack(scheme, Pt(5)).hex() == "0105"
    assert _unpacked(scheme, "0107").x == 7


@pytest.mark.parametrize(
    "accessor",
    [operator.attrgetter("a"), lambda p: getattr(p, "a")],  # noqa: B009
    ids=["attrgetter", "getattr"],
)
def test_ac7_an_attribute_accessor_is_found_by_its_probe_not_its_function(accessor):
    assert _refused(_points(group(0, u8(0, accessor)))) == _message("list", "field 0", "a")


@pytest.mark.parametrize(
    "accessor", [operator.itemgetter("a"), lambda p: p[0]], ids=["itemgetter", "integer_key"]
)
def test_ac7_a_key_accessor_is_found_by_its_probe_not_its_function(accessor):
    Scheme(1, Row, _points(group(0, u8(0, accessor))))


def test_ac8_a_wrong_field_id_keeps_its_message():
    assert _refused(_points(group(0, u8(1, lambda p: p.x)))) == "field id 1 is not the next order 0"


def test_ac8_an_empty_group_keeps_its_message():
    assert _refused(_points(group(0))) == "group 0 has no fields, so it can never carry a value"


def test_ac8_a_flag_bit_before_its_flag_byte_keeps_its_message():
    m = flag_byte()

    assert _refused(_points(m.bit(u8(0, lambda p: p.x)))) == (
        "flag bit 0: its flag byte is not read earlier in the same scope"
    )


def test_ac8_a_when_as_the_direct_element_keeps_its_message():
    assert _refused(_points(when(0, eq(0, 1), u8(0, lambda p: p.x)))) == (
        "when 0: eq names field id 0 is allowed only if declared earlier in the same scope"
    )


def test_ac9_the_identity_accessor_in_an_element_group_is_left_alone():
    scheme = Scheme(1, dict, list_field(lambda r: r["l"], group(0, u8(0, lambda p: p))))

    with pytest.raises(TypeError, match=r"^0: expected int, got dict$"):
        BinaryPacker.pack(scheme, {"l": [{"x": 1}]})
    assert _unpacked(scheme, "01010007") == {"l": [{}]}


def test_ac9_key_accessors_in_a_typed_row_given_object_items_fail_at_pack():
    scheme = Scheme(1, Row, _points(group(0, u8(0, lambda p: p["a"]))))

    with pytest.raises(TypeError, match=r"'Pt' object is not subscriptable"):
        BinaryPacker.pack(scheme, Row([Pt(1)]))


def test_ac9_the_two_top_level_mismatches_build_and_fail_at_unpack():
    attribute_on_dict = Scheme(1, dict, u8(0, lambda r: r.a))
    key_on_typed_row = Scheme(1, Row, u8(0, lambda r: r["a"]))

    with pytest.raises(AttributeError):
        _unpacked(attribute_on_dict, "0105")
    with pytest.raises(AttributeError):
        _unpacked(key_on_typed_row, "0105")
