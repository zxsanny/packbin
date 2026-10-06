from __future__ import annotations

from pathlib import Path

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
    when,
)

CASES = Path(__file__).resolve().parents[2] / "fixtures" / "hostile" / "cases.txt"


def _scheme(*fields) -> Scheme:
    return Scheme(1, dict, *fields)


def _on(field_id: int):
    return flag_bool(field_id, lambda row: row["on"])


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _nine_children():
    return [_u8(i, f"f{i}") for i in range(9)]


def test_bool_in_flags_true_false_absent():
    scheme = _scheme(flags(0, _on(0), _u8(1, "n")))

    packed = [BinaryPacker.pack(scheme, row).hex() for row in ({"on": True, "n": 7}, {"on": False}, {})]

    assert packed == ["010307", "0100", "0100"]
    result = BinaryPacker.unpack(bytes.fromhex("010307"), scheme.on(lambda _row: None))
    assert result.ok
    assert result.value == {"on": True, "n": 7}


def test_bool_false_in_flags_unpacks_without_true():
    scheme = _scheme(flags(0, _on(0)))

    result = BinaryPacker.unpack(bytes.fromhex("0100"), scheme.on(lambda _row: None))

    assert result.ok
    assert result.value.get("on") is not True


def test_bool_top_level_is_scheme_error():
    with pytest.raises(ValueError, match=r"\b1\b"):
        _scheme(_u8(0, "a"), _on(1))


BOOL_OUTSIDE_FLAGS = {
    "group": lambda: _scheme(group(0, _u8(0, "n"), _on(1))),
    "group_under_flags": lambda: _scheme(flags(0, group(0, _u8(0, "n"), _on(1)))),
    "when": lambda: _scheme(_u8(0, "k"), when(1, eq(0, 1), _on(1))),
    "repeat": lambda: _scheme(repeat(0, _on(0))),
    "times": lambda: _scheme(_u8(0, "n"), times(1, 0, _on(1))),
    "list_element": lambda: _scheme(list_field(lambda row: row["xs"], _on(0))),
    "dict_element": lambda: _scheme(map_field(lambda row: row["d"], _on(0))),
}


@pytest.mark.parametrize("place", sorted(BOOL_OUTSIDE_FLAGS))
def test_bool_in_group_when_repeat_times_element_is_scheme_error(place: str):
    with pytest.raises(ValueError, match="flags"):
        BOOL_OUTSIDE_FLAGS[place]()


def test_ninth_flags_child_is_scheme_error():
    with pytest.raises(ValueError, match=r"\b0\b"):
        flags(0, *_nine_children())


def test_eight_flags_children_pack():
    scheme = _scheme(flags(0, *_nine_children()[:8]))

    assert BinaryPacker.pack(scheme, {"f7": 1}).hex() == "018001"


def _nine_bits_split():
    byte = flag_byte()
    bits = [byte.bit(_u8(i, f"f{i}")) for i in range(9)]
    _scheme(byte, *bits)


# Construct vectors in fixtures/hostile/cases.txt that this package can build today.
# nine_flag_bits_split: Scheme(...) refuses the 9th bit of one read of a flag_byte; bit() itself raises nothing.
# The three reference vectors (when/count naming a later or outer field, AZ-2113) are in test_reference_scope.py.
CONSTRUCT_SCHEMES = {
    "nine_flag_bits": lambda: _scheme(flags(0, *_nine_children())),
    "nine_flag_bits_split": _nine_bits_split,
    "bool_outside_flags": lambda: _scheme(_u8(0, "a"), _on(1)),
    "empty_group_outside_flags": lambda: _scheme(_u8(0, "a"), group(1)),
}


def _construct_ids() -> list[str]:
    out = []
    for line in CASES.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        case_id, stage, expected, _hex = line.split()
        if stage == "construct" and case_id in CONSTRUCT_SCHEMES:
            assert expected == "scheme_error"
            out.append(case_id)
    return out


def test_construct_vectors_are_in_the_case_file():
    assert sorted(_construct_ids()) == sorted(CONSTRUCT_SCHEMES)


@pytest.mark.parametrize("case_id", sorted(CONSTRUCT_SCHEMES))
def test_construct_vector_is_scheme_error(case_id: str):
    with pytest.raises(ValueError, match="8 bits|flags|no fields"):
        CONSTRUCT_SCHEMES[case_id]()


EMPTY_GROUP_PLACES = {
    "top_level": lambda: _scheme(_u8(0, "a"), group(1)),
    "in_flags": lambda: _scheme(flags(0, group(0))),
    "in_when": lambda: _scheme(_u8(0, "k"), when(1, eq(0, 1), group(1))),
    "in_repeat": lambda: _scheme(repeat(0, group(0))),
    "in_times": lambda: _scheme(_u8(0, "n"), times(1, 0, group(1))),
    "list_element": lambda: _scheme(list_field(lambda row: row["xs"], group(0))),
}


@pytest.mark.parametrize("place", sorted(EMPTY_GROUP_PLACES))
def test_empty_group_is_scheme_error_everywhere(place: str):
    with pytest.raises(ValueError, match=r"group \d+ has no fields"):
        EMPTY_GROUP_PLACES[place]()


@pytest.mark.parametrize("value", [1, "yes"])
def test_bool_value_other_than_true_clears_the_bit(value):
    scheme = _scheme(flags(0, _on(0)))

    packed = BinaryPacker.pack(scheme, {"on": value}).hex()

    assert packed == "0100"
    result = BinaryPacker.unpack(bytes.fromhex(packed), scheme.on(lambda _row: None))
    assert result.ok
    assert "on" not in result.value
