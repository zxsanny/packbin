from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, bytes as raw_bytes, dict as map_field, repeat, times, u8, utf8


def _entry():
    return map_field(lambda row: row["d"], u8(0, lambda value: value))


def _times_scheme() -> Scheme:
    return Scheme(1, dict, u8(0, lambda row: row["n"]), times(1, 0, _entry(), u8(1, lambda row: row["x"])))


def _repeat_scheme() -> Scheme:
    return Scheme(1, dict, repeat(0, _entry(), u8(0, lambda row: row["x"])))


def _unpack(scheme: Scheme, raw: bytes):
    result = BinaryPacker.unpack(raw, scheme.on(lambda _row: None))
    assert result.ok, result.error
    return result.value


@pytest.mark.parametrize(
    "scheme,row",
    [
        (_times_scheme, {"n": 2, "d": {"k": 7}, "x": [1, 2]}),
        (_repeat_scheme, {"d": {"k": 7}, "x": [1, 2]}),
        (_repeat_scheme, {"d": {"k": 7}, "x": 5}),
        (_repeat_scheme, {"d": {"k": 7}}),
        (_repeat_scheme, {"d": {}, "x": []}),
    ],
    ids=["times", "repeat-longer-sibling", "repeat-lone-sibling", "repeat-no-sibling", "repeat-empty-dict"],
)
def test_az_2308_ac2_a_lone_dict_in_a_round_is_refused_naming_the_member(scheme, row):
    with pytest.raises(TypeError, match=r"member d: a dict in a repeat or times round must be a list"):
        BinaryPacker.pack(scheme(), row)


def test_az_2308_ac2_a_lone_dict_is_refused_on_an_object_row_naming_the_member():
    class Row:
        n = 2
        entries = {"k": 7}
        x = [1, 2]

    scheme = Scheme(
        1,
        Row,
        u8(0, lambda row: row.n),
        times(1, 0, map_field(lambda row: row.entries, u8(0, lambda value: value)), u8(1, lambda row: row.x)),
    )

    with pytest.raises(TypeError, match=r"member entries: "):
        BinaryPacker.pack(scheme, Row())


def test_az_2308_ac2_a_lone_dict_is_refused_even_when_the_times_count_is_zero():
    with pytest.raises(TypeError, match=r"member d: "):
        BinaryPacker.pack(_times_scheme(), {"n": 0, "d": {"k": 7}, "x": []})


def test_az_2308_ac3_a_list_of_dicts_in_times_packs_one_per_round():
    scheme = _times_scheme()

    raw = BinaryPacker.pack(scheme, {"n": 2, "d": [{"k": 7}, {"k": 8}], "x": [1, 2]})

    assert raw.hex() == "0102010001006b0701010001006b0802"
    assert _unpack(scheme, raw) == {"n": 2, "d": [{"k": 7}, {"k": 8}], "x": [1, 2]}


def test_az_2308_ac3_a_list_of_dicts_in_repeat_packs_one_per_round():
    scheme = _repeat_scheme()

    raw = BinaryPacker.pack(scheme, {"d": [{"k": 7}, {"k": 8}], "x": [1, 2]})

    assert raw.hex() == "01010001006b0701010001006b0802"
    assert _unpack(scheme, raw) == {"d": [{"k": 7}, {"k": 8}], "x": [1, 2]}


def test_az_2308_a_dict_outside_a_round_is_a_dict_not_a_list():
    scheme = Scheme(1, dict, _entry())

    raw = BinaryPacker.pack(scheme, {"d": {"k": 7}})

    assert raw.hex() == "01010001006b07"
    assert _unpack(scheme, raw) == {"d": {"k": 7}}


def test_az_2308_a_lone_string_for_a_utf8_name_keeps_broadcasting():
    scheme = Scheme(1, dict, u8(0, lambda row: row["n"]), times(1, 0, utf8(1, lambda row: row["s"])))

    raw = BinaryPacker.pack(scheme, {"n": 2, "s": "ab"})

    assert raw.hex() == "01020200616202006162"


def test_az_2308_a_lone_bytes_for_a_bytes_name_keeps_broadcasting():
    scheme = Scheme(1, dict, u8(0, lambda row: row["n"]), times(1, 0, raw_bytes(1, lambda row: row["b"], 1)))

    raw = BinaryPacker.pack(scheme, {"n": 2, "b": b"a"})

    assert raw.hex() == "01026161"
