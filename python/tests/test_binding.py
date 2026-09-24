from __future__ import annotations

from dataclasses import dataclass

import pytest

from packbin import (
    Scheme,
    bool as flag_bool,
    eq,
    flags,
    i32,
    list,
    pack,
    u8,
    u16,
    unpack,
    when,
)

from _bind import gs, leaf

AC1_HEX = "2001000065cd1d00a3e111010000000000"


@dataclass
class MarkerRow:
    Sid: int = 0
    Lat: int = 0
    Lon: int = 0
    Kind: int = 0
    KindId: int | None = None
    Title: int = 0
    Hidden: bool | None = None
    Delta: bool | None = None


@dataclass
class ParentRow:
    Sid: int = 0
    Items: list | None = None


MARKER = Scheme(
    0x20,
    MarkerRow,
    u16(0, *gs("Sid")),
    i32(1, *gs("Lat")),
    i32(2, *gs("Lon")),
    u8(3, *gs("Kind")),
    when(eq(3, 1), u16(4, *gs("KindId"))),
    u16(5, *gs("Title")),
    flags(
        flag_bool(6, *gs("Hidden")),
        flag_bool(7, *gs("Delta")),
    ),
)


def test_ac1_member_names_are_not_wire_names():
    row = MarkerRow(Sid=1, Lat=500_000_000, Lon=300_000_000, Kind=1, KindId=0, Title=0)
    raw = pack(MARKER, row)
    assert raw.hex() == AC1_HEX
    assert "Lat" not in raw.hex()
    got = unpack(MARKER, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value.Lat == 500_000_000
    assert hasattr(got.value, "Lat")


def test_ac1_positional_payload_bytes():
    row = MarkerRow(Sid=1, Lat=500_000_000, Lon=300_000_000, Kind=1, KindId=0, Title=0)
    raw = pack(MARKER, row)
    assert raw.hex() == AC1_HEX


def test_ac2_sibling_references_use_order():
    with_kind = MarkerRow(Sid=1, Lat=0, Lon=0, Kind=1, KindId=9, Title=0)
    raw = pack(MARKER, with_kind)
    got = unpack(MARKER, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value.KindId == 9

    without = MarkerRow(Sid=1, Lat=0, Lon=0, Kind=0, Title=0)
    raw0 = pack(MARKER, without)
    got0 = unpack(MARKER, raw0)
    assert got0.ok is True
    assert got0.value is not None
    assert got0.value.KindId is None
    assert len(raw) > len(raw0)


def test_ac3_flags_use_child_accessors():
    row = MarkerRow(Sid=1, Lat=0, Lon=0, Kind=0, Title=0, Hidden=True, Delta=None)
    raw = pack(MARKER, row)
    assert raw[-1] == 0x01
    got = unpack(MARKER, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value.Hidden is True
    assert got.value.Delta is None


def test_ac4_nested_row_type_has_own_ids():
    parent = Scheme(
        0x20,
        ParentRow,
        u16(0, *gs("Sid")),
        list(*gs("Items"), u16(0, *leaf())),
    )
    raw = pack(parent, ParentRow(Sid=1, Items=[7, 8]))
    got = unpack(parent, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value.Sid == 1
    assert got.value.Items == [7, 8]


def test_ac5_order_must_match_the_number():
    with pytest.raises(ValueError):
        Scheme(1, MarkerRow, i32(2, *gs("Lat")))


def test_ac6_ac1_bytes_match():
    row = MarkerRow(Sid=1, Lat=500_000_000, Lon=300_000_000, Kind=1, KindId=0, Title=0)
    raw = pack(MARKER, row)
    expected = bytes.fromhex(AC1_HEX)
    mismatched = sum(1 for a, b in zip(raw, expected, strict=True) if a != b) + abs(len(raw) - len(expected))
    assert mismatched == 0
