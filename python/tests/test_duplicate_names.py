from __future__ import annotations

import time

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    be,
    bits,
    bool as flag_bool,
    dict as map_field,
    eq,
    flag_byte,
    flags,
    group,
    list as list_field,
    packed,
    repeat,
    sized,
    times,
    u2,
    u8,
    u16,
    utf8,
    when,
)


def _message(name: str) -> str:
    return f"member {name}: declared twice in one scope; a row holds one value per name, so one would be lost"


def _key(name):
    return lambda row, name=name: row[name]


def _u8(field_id: int, name: str):
    return u8(field_id, _key(name))


def _u16(field_id: int, name: str):
    return u16(field_id, _key(name))


def _same(row):
    return row


def _scheme(*fields, type_number: int = 1) -> Scheme:
    return Scheme(type_number, dict, *fields)


def _refused(*fields) -> str:
    with pytest.raises(ValueError) as caught:
        _scheme(*fields)
    return str(caught.value)


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


def _row(scheme: Scheme, hex_bytes: str) -> dict:
    result = BinaryPacker.unpack(bytes.fromhex(hex_bytes), scheme.on(lambda _row: None))
    assert result.ok, result.error
    return result.value


def test_ac1_the_same_name_twice_at_one_level_is_refused():
    assert _refused(_u8(0, "x"), _u8(1, "x")) == _message("x")


def test_ac2_a_name_outside_a_times_round_and_inside_it_is_refused():
    assert _refused(_u8(0, "x"), _u8(1, "c"), times(2, 1, _u8(2, "x"))) == _message("x")


def test_ac2_a_name_outside_a_repeat_round_and_inside_it_is_refused():
    assert _refused(_u8(0, "x"), repeat(1, _u8(1, "x"))) == _message("x")


def test_ac3_two_rounds_sharing_a_name_are_refused():
    fields = (_u8(0, "n"), times(1, 0, _u8(1, "v")), _u8(2, "m"), times(3, 2, _u8(3, "v")))

    assert _refused(*fields) == _message("v")


def test_ac4_a_name_under_flags_is_refused():
    assert _refused(_u8(0, "x"), flags(1, _u8(1, "x"))) == _message("x")


def test_ac4_a_name_in_a_group_is_refused():
    assert _refused(_u8(0, "x"), group(1, _u8(1, "x"))) == _message("x")


def test_ac4_a_bool_named_twice_under_two_flags_is_refused():
    assert _refused(flags(0, flag_bool(0, _key("on"))), flags(1, flag_bool(1, _key("on")))) == _message("on")


def test_ac4_a_name_in_a_split_flag_bit_and_outside_it_is_refused():
    m = flag_byte()

    assert _refused(m, m.bit(_u8(0, "x")), _u8(1, "x")) == _message("x")


class _Row:
    pass


FIELD_KINDS = {
    "scalar_and_utf8": ((_u8(0, "x"), utf8(1, _key("x"))), "x"),
    "u2_slots": ((u2((0, _key("x")), (1, _key("x"))),), "x"),
    "sized_twice": ((_u8(0, "n"), sized(1, _key("x"), 0), sized(2, _key("x"), 0)), "x"),
    "bits_and_packed": ((_u8(0, "n"), bits(1, _key("x"), 0), packed(1, 2, _key("x"), 0)), "x"),
    "be_and_scalar": ((be(_u16(0, "x")), _u8(1, "x")), "x"),
    "scalar_and_list": ((_u8(0, "xs"), list_field(_key("xs"), u8(0, _same))), "xs"),
    "list_and_dict": (
        (list_field(_key("xs"), u8(0, _same)), map_field(_key("xs"), u8(0, _same))),
        "xs",
    ),
    "integer_key_accessors": ((u8(0, lambda row: row[0]), u8(1, lambda row: row[0])), "0"),
}


@pytest.mark.parametrize("fields,name", FIELD_KINDS.values(), ids=FIELD_KINDS.keys())
def test_ac5_every_kind_of_field_and_a_list_or_dict_accessor_counts(fields, name):
    assert _refused(*fields) == _message(name)


def test_ac5_attribute_accessors_are_refused_on_a_class_row():
    with pytest.raises(ValueError) as caught:
        Scheme(1, _Row, u8(0, lambda row: row.x), u8(1, lambda row: row.x))

    assert str(caught.value) == _message("x")


def test_ac6_two_when_arms_may_share_a_member():
    scheme = _scheme(
        _u8(0, "kind"),
        when(1, eq(0, 0), _u8(1, "shape")),
        when(2, eq(0, 1), _u16(2, "shape")),
    )

    assert _pack(scheme, {"kind": 1, "shape": 300}) == "01012c01"


def test_ac6_two_when_arms_in_a_repeat_may_share_a_member():
    scheme = _scheme(
        repeat(
            0,
            _u8(0, "kind"),
            when(1, eq(0, 0), _u8(1, "shape")),
            when(2, eq(0, 1), _u16(2, "shape")),
        )
    )

    packet = _pack(scheme, {"kind": [0, 1], "shape": [5, 300]})

    assert packet == "010005012c01"
    assert _row(scheme, packet) == {"kind": [0, 1], "shape": [5, 300]}


def test_ac6_a_name_outside_a_when_and_under_one_builds():
    scheme = _scheme(_u8(0, "kind"), _u8(1, "shape"), when(2, eq(0, 1), _u16(2, "shape")))

    assert _pack(scheme, {"kind": 0, "shape": 7}) == "010007"


def test_ac6_two_declarations_in_one_when_body_still_build():
    scheme = _scheme(_u8(0, "k"), when(1, eq(0, 1), _u8(1, "v"), _u8(2, "v")))

    assert _pack(scheme, {"k": 1, "v": 7}) == "01010707"
    assert _row(scheme, "01010708") == {"k": 1, "v": 8}


def test_ac7_an_element_may_reuse_the_names_of_the_row_around_it_in_a_list():
    scheme = _scheme(_u8(0, "a"), list_field(_key("xs"), group(0, _u8(0, "a"))))
    row = {"a": 7, "xs": [{"a": 1}, {"a": 2}]}

    packet = _pack(scheme, row)

    assert (packet, _row(scheme, packet)) == ("010702000102", row)


def test_ac7_an_element_may_reuse_the_names_of_the_row_around_it_in_a_dict():
    scheme = _scheme(_u8(0, "a"), map_field(_key("m"), group(0, _u8(0, "a"))))
    row = {"a": 7, "m": {"k": {"a": 1}}}

    packet = _pack(scheme, row)

    assert (packet, _row(scheme, packet)) == ("0107010001006b01", row)


def test_ac7_a_name_twice_inside_a_list_element_is_refused():
    assert _refused(list_field(_key("xs"), group(0, _u8(0, "a"), _u8(1, "a")))) == _message("a")


def test_ac7_a_name_twice_inside_a_nested_element_is_refused():
    inner = list_field(_same, group(0, _u8(0, "a"), _u8(1, "a")))

    assert _refused(list_field(_key("xs"), inner)) == _message("a")


def test_ac7_two_lists_of_scalars_with_the_identity_accessor_build():
    scheme = _scheme(list_field(_key("xs"), u8(0, _same)), list_field(_key("ys"), u8(0, _same)))

    assert _pack(scheme, {"xs": [1], "ys": [2]}) == "01010001010002"


def test_ac8_a_flag_byte_handle_read_in_two_scopes_is_not_a_name():
    m = flag_byte()
    scheme = _scheme(_u8(0, "c"), m, m.bit(_u8(1, "a")), times(2, 0, m, m.bit(_u8(2, "b"))))

    assert _pack(scheme, {"c": 2, "a": 5, "b": [7, None]}) == "01020105010700"


def test_ac8_a_flag_byte_handle_read_twice_is_not_a_name():
    m = flag_byte()
    scheme = _scheme(m, m.bit(_u8(0, "a")), m, m.bit(_u8(1, "b")))

    assert _pack(scheme, {"b": 9}) == "01000109"


def test_ac8_a_flag_byte_handle_in_two_schemes_is_not_a_name():
    m = flag_byte()
    first = _scheme(m, m.bit(_u8(0, "x")), type_number=1)
    second = _scheme(m, m.bit(_u8(0, "x")), type_number=2)

    assert (_pack(first, {"x": 5}), _pack(second, {"x": 5})) == ("010105", "020105")


def test_ac9_a_wrong_field_id_keeps_its_message():
    assert _refused(_u8(0, "x"), _u8(2, "x")) == "field id 2 is not the next order 1"


def test_ac9_a_flag_bit_before_its_flag_byte_keeps_its_message():
    m = flag_byte()

    assert _refused(m.bit(_u8(0, "x")), _u8(1, "x")) == (
        "flag bit 0: its flag byte is not read earlier in the same scope"
    )


def test_ac9_a_repeat_inside_a_repeat_keeps_its_message():
    fields = (_u8(0, "x"), repeat(1, _u8(1, "x"), repeat(2, _u8(2, "y"))))

    assert _refused(*fields) == (
        "repeat 2 is inside a repeat or times round; a round cannot hold another repeat or times"
    )


def test_ac9_a_when_naming_a_later_field_keeps_its_message():
    assert _refused(when(0, eq(1, 1), _u8(0, "x")), _u8(1, "x")) == (
        "when 0: eq names field id 1 is allowed only if declared earlier in the same scope"
    )


def test_ac9_an_empty_group_keeps_its_message():
    assert _refused(_u8(0, "x"), group(1), _u8(1, "x")) == (
        "group 1 has no fields, so it can never carry a value"
    )


def test_ac9_a_ninth_flag_bit_keeps_its_message():
    m = flag_byte()
    bits_of_one_byte = [m.bit(_u8(i + 1, "x" if i == 0 else f"b{i}")) for i in range(9)]

    assert _refused(_u8(0, "x"), m, *bits_of_one_byte) == "flags already has 8 bits"


@pytest.mark.parametrize(
    "first,second",
    [(0, False), (1, True), (1, 1.0)],
    ids=["zero_and_false", "one_and_true", "one_and_float"],
)
def test_ac5_keys_that_compare_equal_are_one_name(first, second):
    assert _refused(u8(0, lambda row: row[first]), u8(1, lambda row: row[second])) == _message(str(second))


def test_ac5_keys_that_compare_different_are_two_names():
    _scheme(u8(0, lambda row: row[0]), u8(1, lambda row: row["0"]), u8(2, lambda row: row[1]))


def test_ac5_an_unhashable_key_is_a_name_like_any_other():
    first = u8(0, lambda row: row[[1]])
    again = u8(1, lambda row: row[[1]])
    other = u8(1, lambda row: row[[2]])

    assert _refused(first, again) == _message("[1]")
    _scheme(first, other)


def test_ac5_a_slice_key_is_a_name_like_any_other():
    assert _refused(u8(0, lambda row: row[1:2]), u8(1, lambda row: row[1:2])) == _message("slice(1, 2, None)")
    _scheme(u8(0, lambda row: row[1:2]), u8(1, lambda row: row[1:3]))


def _build_time(fields: list) -> float:
    best = float("inf")
    for _ in range(3):
        started = time.perf_counter()
        _scheme(*fields)
        best = min(best, time.perf_counter() - started)
    return best


def test_ac5_the_name_check_is_linear_in_the_fields_of_a_scope():
    small = [u8(i, lambda row, i=i: row[f"n{i}"]) for i in range(2_000)]
    large = [u8(i, lambda row, i=i: row[f"n{i}"]) for i in range(20_000)]

    ratio = _build_time(large) / _build_time(small)

    # Ten times the fields cost about ten times as much; a scan of every earlier name costs about a hundred.
    assert ratio < 40, ratio
