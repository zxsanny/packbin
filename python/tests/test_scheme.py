from __future__ import annotations

import inspect
from dataclasses import dataclass
from pathlib import Path

import pytest

from packbin import (
    BinaryPacker,
    Scheme,
    TypeMismatch,
    TypeNum,
    pack,
    packet,
    u8,
    u16,
    i16,
    i32,
    flags,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
GOLDEN_HEX = (REPO_ROOT / "fixtures" / "golden.hex").read_text().strip()


@dataclass
class MarkerRow:
    sid: int


MARKER_ROW_SCHEME: Scheme[MarkerRow] = Scheme.of(MarkerRow, TypeNum.set(32), u8("sid"))

POSITION = packet(
    [
        u8("type"),
        u16("sid"),
        i32("lat"),
        i32("lon"),
        u8("profile"),
        flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
    ]
)

POSITION_VALUES = {
    "type": 64,
    "sid": 1,
    "lat": 500_000_000,
    "lon": 300_000_000,
    "profile": 1,
}


def test_ac1_pack_scheme_and_row():
    row = MarkerRow(sid=23)
    raw = BinaryPacker.pack(MARKER_ROW_SCHEME, row)
    assert raw.hex() == "2017"
    assert raw == bytes([0x20, 0x17])


def test_ac2_unpack_scheme_sid():
    got = BinaryPacker.unpack(MARKER_ROW_SCHEME, bytes.fromhex("2017"))
    assert got.ok is True
    assert got.value is not None
    assert got.value.sid == 23
    assert not hasattr(got.value, "type")
    assert "type" not in vars(got.value)


def test_ac3_scheme_argument_required():
    row = MarkerRow(sid=23)
    with pytest.raises(TypeError):
        BinaryPacker.pack(row)  # type: ignore[call-arg]


def test_ac4_wrong_type_byte():
    got = BinaryPacker.unpack(MARKER_ROW_SCHEME, bytes.fromhex("2117"))
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, TypeMismatch)
    assert got.error.expected == 32
    assert got.error.actual == 33


def test_ac5_untyped_golden_unchanged():
    raw = pack(POSITION, POSITION_VALUES)
    expected = bytes.fromhex(GOLDEN_HEX)
    assert raw == expected


def test_ac6_marker_row_is_data_only():
    src = inspect.getsource(MarkerRow)
    assert "sid" in src
    assert "scheme" not in src.lower()
    assert "def pack" not in src
    assert "BinaryPacker" not in src
    assert "Scheme" not in src
