from __future__ import annotations

import pytest

from packbin import BinaryPacker, Scheme, eq, i8, i64, u2, u8, u16, u64, when


def _u8(field_id: int, name: str):
    return u8(field_id, lambda row, name=name: row[name])


def _scheme(source, value) -> Scheme:
    return Scheme(1, dict, source, when(1, eq(0, value), _u8(1, "v")))


@pytest.mark.parametrize(
    "source,value,limit",
    [
        (_u8(0, "a"), 300, "0..255"),
        (_u8(0, "a"), -1, "0..255"),
        (u16(0, lambda row: row["a"]), 65536, "0..65535"),
        (i8(0, lambda row: row["a"]), 128, "-128..127"),
        (u64(0, lambda row: row["a"]), 2**64, "0..18446744073709551615"),
        (i64(0, lambda row: row["a"]), -(2**63) - 1, "-9223372036854775808..9223372036854775807"),
        (u2((0, lambda row: row["a"])), 4, "0..3"),
    ],
    ids=["u8-high", "u8-low", "u16", "i8", "u64", "i64", "u2-slot"],
)
def test_ac1_a_value_outside_the_source_range_is_refused_naming_the_member(source, value, limit):
    # Arrange / Act / Assert
    with pytest.raises(ValueError, match=rf"^when 1: eq tests .* field 0 against {value}, which is outside {limit}$"):
        _scheme(source, value)


@pytest.mark.parametrize(
    "value,shown",
    [("x", "'x'"), (float("nan"), "nan"), (1.5, "1.5"), (5.0, "5.0"), (None, "None"), ([5], "list")],
    ids=["str", "nan", "fraction", "whole-float", "none", "list"],
)
def test_ac2_a_non_integer_value_is_refused_naming_the_member(value, shown):
    # Arrange / Act / Assert
    with pytest.raises(ValueError, match=rf"^when 1: eq tests u8 field 0 against {shown};"):
        _scheme(_u8(0, "a"), value)


@pytest.mark.parametrize("value", [True, False])
def test_ac3_a_bool_for_an_integer_source_is_refused(value):
    # Arrange / Act / Assert
    with pytest.raises(ValueError, match=rf"^when 1: eq tests u8 field 0 against {value};"):
        _scheme(_u8(0, "a"), value)


def test_ac3_a_bool_for_a_u2_slot_is_refused():
    # Arrange / Act / Assert
    with pytest.raises(ValueError, match=r"^when 1: eq tests u2 slot field 0 against True;"):
        _scheme(u2((0, lambda row: row["a"])), True)


@pytest.mark.parametrize("value", [0, 5, 255])
def test_ac4_a_value_in_range_builds_and_packs_as_before(value):
    # Arrange
    scheme = _scheme(_u8(0, "a"), value)

    # Act
    taken = BinaryPacker.pack(scheme, {"a": value, "v": 9}).hex()
    skipped = BinaryPacker.pack(scheme, {"a": (value + 1) % 256, "v": 9}).hex()

    # Assert
    assert (taken, skipped) == (f"01{value:02x}09", f"01{(value + 1) % 256:02x}")


def test_the_range_edges_of_signed_and_wide_sources_build():
    # Arrange / Act
    built = [
        _scheme(i8(0, lambda row: row["a"]), -128),
        _scheme(u64(0, lambda row: row["a"]), 2**64 - 1),
        _scheme(u2((0, lambda row: row["a"])), 3),
    ]

    # Assert
    assert len(built) == 3
