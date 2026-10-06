from __future__ import annotations

from pathlib import Path

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bits,
    bool as flag_bool,
    dict as map_field,
    eq,
    flags,
    list as list_field,
    packed,
    repeat,
    sized,
    times,
    u8,
    u16,
    when,
)

CASES = Path(__file__).resolve().parents[2] / "fixtures" / "hostile" / "cases.txt"


def _scheme(*fields) -> Scheme:
    return Scheme(1, dict, *fields)


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _when_names_later_field():
    return _scheme(_u8(0, "a"), when(1, eq(2, 1), _u8(1, "b")), _u8(2, "c"))


def _count_names_later_field():
    return _scheme(sized(0, lambda row: row["payload"], 1), u16(1, lambda row: row["n"]))


def _when_names_outer_field_in_repeat():
    return _scheme(_u8(0, "mode"), repeat(1, when(1, eq(0, 1), _u8(1, "v"))))


# The three reference construct vectors in fixtures/hostile/cases.txt, with the id each refusal must name.
REFERENCE_VECTORS = {
    "when_names_later_field": (_when_names_later_field, r"field id 2\b"),
    "count_names_later_field": (_count_names_later_field, r"field id 1\b"),
    "when_names_outer_field_in_repeat": (_when_names_outer_field_in_repeat, r"field id 0\b"),
}


def test_reference_vectors_are_in_the_case_file():
    listed = []
    for line in CASES.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        case_id, stage, expected, _hex = line.split()
        if case_id in REFERENCE_VECTORS:
            assert (stage, expected) == ("construct", "scheme_error")
            listed.append(case_id)

    assert sorted(listed) == sorted(REFERENCE_VECTORS)


@pytest.mark.parametrize("case_id", sorted(REFERENCE_VECTORS))
def test_reference_construct_vector_is_scheme_error(case_id: str):
    build, names = REFERENCE_VECTORS[case_id]

    with pytest.raises(ValueError, match=names):
        build()


def test_ac1_when_naming_a_later_field_is_refused():
    with pytest.raises(ValueError, match=r"when 1: .*field id 2\b"):
        _when_names_later_field()


def test_ac2_count_naming_a_later_field_is_refused():
    with pytest.raises(ValueError, match=r"sized 0: .*field id 1\b"):
        _count_names_later_field()


@pytest.mark.parametrize(
    "build,kind",
    [
        (lambda: _scheme(bits(0, lambda row: row["b"], 1), _u8(1, "n")), "bits 0"),
        (lambda: _scheme(packed(1, 0, lambda row: row["k"], 1), _u8(1, "n")), "packed 0"),
        (lambda: _scheme(times(0, 1, _u8(0, "v")), _u8(1, "n")), "times 0"),
    ],
    ids=["bits", "packed", "times"],
)
def test_ac2_every_count_consumer_naming_a_later_field_is_refused(build, kind: str):
    with pytest.raises(ValueError, match=rf"{kind}: .*field id 1\b"):
        build()


def test_ac2_count_naming_a_field_that_does_not_exist_is_refused():
    with pytest.raises(ValueError, match=r"field id 9\b"):
        _scheme(_u8(0, "n"), sized(1, lambda row: row["payload"], 9))


def test_ac4_when_naming_an_outer_field_in_repeat_is_refused():
    with pytest.raises(ValueError, match=r"when 1: .*field id 0\b"):
        _when_names_outer_field_in_repeat()


def test_ac4_when_naming_an_outer_field_in_times_is_refused():
    with pytest.raises(ValueError, match=r"when 1: .*field id 0\b"):
        _scheme(_u8(0, "n"), times(1, 0, when(1, eq(0, 1), _u8(1, "v"))))


def test_ac4_count_naming_an_outer_field_in_a_body_is_refused():
    with pytest.raises(ValueError, match=r"sized 2: .*field id 0\b"):
        _scheme(_u8(0, "n"), repeat(1, _u8(1, "len"), sized(2, lambda row: row["p"], 0)))


def test_ac4_when_after_a_repeat_naming_a_field_inside_it_is_refused():
    with pytest.raises(ValueError, match=r"when 2: .*field id 1\b"):
        _scheme(repeat(0, _u8(0, "a"), _u8(1, "b")), when(2, eq(1, 1), _u8(2, "c")))


def test_ac4_when_naming_a_field_of_the_list_element_outer_row_is_refused():
    with pytest.raises(ValueError, match=r"when 0: .*field id 0\b"):
        _scheme(_u8(0, "n"), list_field(lambda row: row["xs"], when(0, eq(0, 1), _u8(0, "v"))))


def test_valid_references_still_build_and_pack():
    row = _scheme(
        flags(0, flag_bool(0, lambda row: row["on"]), _u8(1, "k")),
        _u8(2, "mode"),
        when(3, eq(2, 1), _u8(3, "v")),
        _u8(4, "n"),
        sized(5, lambda row: row["payload"], 4),
    )

    packet = BinaryPacker.pack(row, {"on": True, "k": 5, "mode": 1, "v": 9, "n": 2, "payload": b"ab"})

    assert packet.hex() == "010305010902" + "6162"
    assert BinaryPacker.unpack(packet, row.on(lambda _row: None)).ok


def test_repeat_body_may_name_an_earlier_field_of_its_own_round():
    _scheme(_u8(0, "a"), repeat(1, _u8(1, "r"), when(2, eq(1, 1), _u8(2, "w"))))


def test_valid_reference_to_a_field_read_earlier_in_the_same_round():
    row = _scheme(
        _u8(0, "rounds"),
        times(1, 0, _u8(1, "len"), sized(2, lambda row: row["p"], 1), when(3, eq(1, 2), _u8(3, "x"))),
    )

    packet = BinaryPacker.pack(row, {"rounds": 1, "len": [2], "p": [b"ab"], "x": [7]})

    assert packet.hex() == "010102616207"
    assert BinaryPacker.unpack(packet, row.on(lambda _row: None)).ok


def test_list_and_dict_elements_still_build():
    row = _scheme(
        list_field(lambda row: row["xs"], _u8(0, "v")),
        map_field(lambda row: row["m"], _u8(0, "v")),
    )

    assert BinaryPacker.pack(row, {"xs": [1], "m": {"a": 2}}).hex() == "01010001010001006102"
