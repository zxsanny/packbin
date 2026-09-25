from __future__ import annotations

from dataclasses import dataclass

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    bool as flag_bool,
    eq,
    flags,
    i32,
    list,
    u8,
    u16,
    when,
)

from _bind import gs, leaf

AC1_HEX = "2001000065cd1d00a3e111010000000000"


@dataclass
class MarkerRow:
    sid: int = 0
    lat: int = 0
    lon: int = 0
    kind: int = 0
    kind_id: int | None = None
    title: int = 0
    hidden: bool | None = None
    delta: bool | None = None


@dataclass
class ParentRow:
    sid: int = 0
    items: list | None = None


MARKER = Scheme(
    0x20,
    MarkerRow,
    u16(0, *gs("sid")),
    i32(1, *gs("lat")),
    i32(2, *gs("lon")),
    u8(3, *gs("kind")),
    when(eq(3, 1), u16(4, *gs("kind_id"))),
    u16(5, *gs("title")),
    flags(
        flag_bool(6, *gs("hidden")),
        flag_bool(7, *gs("delta")),
    ),
)


def test_ac1_member_names_are_not_wire_names():
    row = MarkerRow(sid=1, lat=500_000_000, lon=300_000_000, kind=1, kind_id=0, title=0)
    raw = BinaryPacker.pack(MARKER, row)
    assert raw.hex() == AC1_HEX
    assert "lat" not in raw.hex()
    got = BinaryPacker.unpack(raw, MARKER.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value.lat == 500_000_000
    assert hasattr(got.value, "lat")


def test_ac1_positional_payload_bytes():
    row = MarkerRow(sid=1, lat=500_000_000, lon=300_000_000, kind=1, kind_id=0, title=0)
    raw = BinaryPacker.pack(MARKER, row)
    assert raw.hex() == AC1_HEX


def test_ac2_sibling_references_use_order():
    with_kind = MarkerRow(sid=1, lat=0, lon=0, kind=1, kind_id=9, title=0)
    raw = BinaryPacker.pack(MARKER, with_kind)
    got = BinaryPacker.unpack(raw, MARKER.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value.kind_id == 9

    without = MarkerRow(sid=1, lat=0, lon=0, kind=0, title=0)
    raw0 = BinaryPacker.pack(MARKER, without)
    got0 = BinaryPacker.unpack(raw0, MARKER.on(lambda row: None))
    assert got0.ok is True
    assert got0.value is not None
    assert got0.value.kind_id is None
    assert len(raw) > len(raw0)


def test_ac3_flags_use_child_accessors():
    row = MarkerRow(sid=1, lat=0, lon=0, kind=0, title=0, hidden=True, delta=None)
    raw = BinaryPacker.pack(MARKER, row)
    assert raw[-1] == 0x01
    got = BinaryPacker.unpack(raw, MARKER.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value.hidden is True
    assert got.value.delta is None


def test_ac4_nested_row_type_has_own_ids():
    parent = Scheme(
        0x20,
        ParentRow,
        u16(0, *gs("sid")),
        list(*gs("items"), u16(0, *leaf())),
    )
    raw = BinaryPacker.pack(parent, ParentRow(sid=1, items=[7, 8]))
    got = BinaryPacker.unpack(raw, parent.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value.sid == 1
    assert got.value.items == [7, 8]


def test_ac5_order_must_match_the_number():
    with pytest.raises(ValueError):
        Scheme(1, MarkerRow, i32(2, *gs("lat")))


def test_ac6_ac1_bytes_match():
    row = MarkerRow(sid=1, lat=500_000_000, lon=300_000_000, kind=1, kind_id=0, title=0)
    raw = BinaryPacker.pack(MARKER, row)
    expected = bytes.fromhex(AC1_HEX)
    mismatched = sum(1 for a, b in zip(raw, expected, strict=True) if a != b) + abs(len(raw) - len(expected))
    assert mismatched == 0
