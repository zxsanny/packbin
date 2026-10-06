from __future__ import annotations

import math
from decimal import Decimal
from fractions import Fraction

import pytest

from packbin import BinaryPacker, Scheme, eq, f32, f64, flags, times, u8, when
from packbin import dict as map_field
from packbin import list as list_field


def _float(kind) -> Scheme:
    return Scheme(1, dict, kind(0, lambda row: row["x"]))


def _list_of_f32() -> Scheme:
    return Scheme(1, dict, list_field(lambda row: row["xs"], f32(0, lambda row: row)))


def _pack(scheme: Scheme, row: dict) -> str:
    return BinaryPacker.pack(scheme, row).hex()


@pytest.mark.parametrize("value", ["1.5", "abc"])
@pytest.mark.parametrize("kind", [f64, f32], ids=["f64", "f32"])
def test_ac1_a_string_is_refused(kind, value: str):
    with pytest.raises(TypeError, match=r"^0: expected number, got str$"):
        BinaryPacker.pack(_float(kind), {"x": value})


@pytest.mark.parametrize("value", ["1.5", "abc"])
def test_ac1_a_string_in_a_list_element_is_refused(value: str):
    with pytest.raises(TypeError, match=r"^0: expected number, got str$"):
        BinaryPacker.pack(_list_of_f32(), {"xs": [value]})


@pytest.mark.parametrize("value", [True, False])
@pytest.mark.parametrize("kind", [f64, f32], ids=["f64", "f32"])
def test_ac2_a_bool_is_refused(kind, value: bool):
    with pytest.raises(TypeError, match=r"^0: expected number, got bool$"):
        BinaryPacker.pack(_float(kind), {"x": value})


@pytest.mark.parametrize(
    "value,type_name",
    [(b"1", "bytes"), (Decimal("1.5"), "Decimal"), (Fraction(3, 2), "Fraction"), ([1.5], "list")],
    ids=["bytes", "decimal", "fraction", "list"],
)
def test_ac3_any_other_non_number_is_refused(value, type_name: str):
    with pytest.raises(TypeError, match=rf"^0: expected number, got {type_name}$"):
        BinaryPacker.pack(_float(f64), {"x": value})


def test_ac3_none_is_still_a_missing_field():
    with pytest.raises(KeyError, match="missing field 0"):
        BinaryPacker.pack(_float(f64), {"x": None})


@pytest.mark.parametrize("value", [1e39, -1e39, 3.5e38])
def test_ac4_f32_overflow_names_the_field(value: float):
    with pytest.raises(OverflowError, match=r"^0: .* does not fit in f32$"):
        BinaryPacker.pack(_float(f32), {"x": value})


def test_ac4_f32_overflow_in_a_list_element_names_the_field():
    with pytest.raises(OverflowError, match=r"^0: .* does not fit in f32$"):
        BinaryPacker.pack(_list_of_f32(), {"xs": [1.5, 1e39]})


def test_ac4_the_largest_f32_still_packs():
    assert _pack(_float(f32), {"x": 3.4028235e38}) == "01ffff7f7f"


@pytest.mark.parametrize(
    "kind,value,expected",
    [
        (f64, 3, "010000000000000840"),
        (f64, 1.5, "01000000000000f83f"),
        (f64, -0.0, "010000000000000080"),
        (f64, math.inf, "01000000000000f07f"),
        (f64, math.nan, "01000000000000f87f"),
        (f32, 1.5, "010000c03f"),
        (f32, math.inf, "010000807f"),
        (f32, math.nan, "010000c07f"),
    ],
    ids=["f64_int", "f64_1.5", "f64_-0.0", "f64_inf", "f64_nan", "f32_1.5", "f32_inf", "f32_nan"],
)
def test_ac5_valid_values_keep_their_bytes(kind, value: float, expected: str):
    assert _pack(_float(kind), {"x": value}) == expected


def test_ac5_negative_infinity_is_written():
    assert _pack(_float(f32), {"x": -math.inf}) == "01000080ff"


def test_ac6_readme_float_example_round_trips():
    scheme = _float(f32)

    packed = _pack(scheme, {"x": 1.5})
    got = BinaryPacker.unpack(bytes.fromhex("010000c03f"), scheme.on(lambda _row: None))

    assert packed == "010000c03f"
    assert got.ok
    assert _pack(scheme, got.value) == "010000c03f"


PLACES = {
    "flags": (lambda: Scheme(1, dict, flags(0, f64(0, lambda row: row["x"]))), {"x": "1.5"}, "0"),
    "when": (
        lambda: Scheme(1, dict, u8(0, lambda row: row["k"]), when(1, eq(0, 1), f64(1, lambda row: row["x"]))),
        {"k": 1, "x": "1.5"},
        "1",
    ),
    "times": (
        lambda: Scheme(1, dict, u8(0, lambda row: row["n"]), times(1, 0, f64(1, lambda row: row["x"]))),
        {"n": 1, "x": ["1.5"]},
        "1",
    ),
    "dict_element": (
        lambda: Scheme(1, dict, map_field(lambda row: row["m"], f64(0, lambda row: row))),
        {"m": {"a": "1.5"}},
        "0",
    ),
}


@pytest.mark.parametrize("place", sorted(PLACES))
def test_a_string_is_refused_in_every_place_a_float_stands(place: str):
    build, row, field = PLACES[place]

    with pytest.raises(TypeError, match=rf"^{field}: expected number, got str$"):
        BinaryPacker.pack(build(), row)
