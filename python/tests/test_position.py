from __future__ import annotations

import time
from pathlib import Path

from packbin import (
    ShortPacket,
    TrailingBytes,
    Scheme,
    flags,
    i16,
    i32,
    BinaryPacker,
    u8,
    u16,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
GOLDEN_HEX = (REPO_ROOT / "fixtures" / "golden.hex").read_text().strip()
POSITION_HEX = "4001000065cd1d00a3e1110100"

POSITION = Scheme(
    0x40,
    dict,
    u16(0, lambda row: row["sid"]),
    i32(1, lambda row: row["lat"]),
    i32(2, lambda row: row["lon"]),
    u8(3, lambda row: row["profile"]),
    flags(
        u16(4, lambda row: row["heading"]),
        u8(5, lambda row: row["speed"]),
        i16(6, lambda row: row["altitude"]),
    ),
)

POSITION_VALUES = {
    "sid": 1,
    "lat": 500_000_000,
    "lon": 300_000_000,
    "profile": 1,
}


def _hex(data: bytes) -> str:
    return data.hex()


def _mismatched_bytes(actual: bytes, expected_hex: str) -> int:
    expected = bytes.fromhex(expected_hex)
    return sum(1 for a, b in zip(actual, expected, strict=False) if a != b) + abs(
        len(actual) - len(expected)
    )


def test_ac1_position_pack():
    raw = BinaryPacker.pack(POSITION, POSITION_VALUES)
    assert _hex(raw) == POSITION_HEX
    assert _mismatched_bytes(raw, POSITION_HEX) == 0
    assert len(raw) == 13
    again = BinaryPacker.pack(POSITION, POSITION_VALUES)
    assert _mismatched_bytes(again, _hex(raw)) == 0


def test_ac2_position_unpack():
    got = BinaryPacker.unpack(bytes.fromhex(POSITION_HEX), POSITION.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert "type" not in got.value
    assert got.value["sid"] == 1
    assert got.value["lat"] == 500_000_000
    assert got.value["lon"] == 300_000_000
    assert got.value["profile"] == 1
    motion_fields = [
        name
        for name in ("heading", "speed", "altitude")
        if name in got.value and got.value[name] is not None
    ]
    assert len(motion_fields) == 0


def test_ac3_bytes_match_fixture():
    raw = BinaryPacker.pack(POSITION, POSITION_VALUES)
    assert _mismatched_bytes(raw, GOLDEN_HEX) == 0
    assert GOLDEN_HEX == POSITION_HEX


def test_ac4_flags_and_stored_zero():
    layout = Scheme(
        0x40,
        dict,
        flags(
            u8(0, lambda row: row["b0"]),
            u8(1, lambda row: row["b1"]),
            u8(2, lambda row: row["b2"]),
            u8(3, lambda row: row["b3"]),
            u8(4, lambda row: row["b4"]),
            u16(5, lambda row: row["b5"]),
        ),
    )
    clear = BinaryPacker.pack(layout, {})
    assert clear[1] == 0x00
    assert len(clear) == 2

    set_bit = BinaryPacker.pack(layout, {"b5": 0x1234})
    assert set_bit[1] == 0x20
    assert len(set_bit) == 4
    assert len(set_bit) - len(clear) == 2

    present_zero = BinaryPacker.pack(layout, {"b5": 0})
    assert present_zero[1] == 0x20
    assert present_zero[2:] == b"\x00\x00"
    assert len(present_zero) == 4

    absent = BinaryPacker.pack(layout, {})
    assert absent[1] == 0x00
    assert len(absent) == 2
    assert absent != present_zero


def test_ac5_short_field_then_position_pack():
    layout = Scheme(
        0x40,
        dict,
        flags(
            u8(0, lambda row: row["b0"]),
            u8(1, lambda row: row["b1"]),
            u8(2, lambda row: row["b2"]),
            u8(3, lambda row: row["b3"]),
            u8(4, lambda row: row["b4"]),
            u16(5, lambda row: row["b5"]),
        ),
    )
    short = bytes([0x40, 0x20, 0x34])
    got = BinaryPacker.unpack(short, layout.on(lambda row: None))
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, ShortPacket)
    assert got.field == "5"
    assert got.needed == 2
    assert got.left == 1

    raw = BinaryPacker.pack(POSITION, POSITION_VALUES)
    assert _hex(raw) == GOLDEN_HEX
    assert _mismatched_bytes(raw, GOLDEN_HEX) == 0


def test_trailing_bytes():
    raw = BinaryPacker.pack(POSITION, POSITION_VALUES) + b"\x00"
    got = BinaryPacker.unpack(raw, POSITION.on(lambda row: None))
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, TrailingBytes)
    assert got.error.left == 1


def test_nfr_round_trips():
    start = time.perf_counter()
    for _ in range(100_000):
        raw = BinaryPacker.pack(POSITION, POSITION_VALUES)
        got = BinaryPacker.unpack(raw, POSITION.on(lambda row: None))
        assert got.ok is True
    elapsed = time.perf_counter() - start
    _assert_no_gpu()
    assert elapsed <= 2.0, f"elapsed {elapsed:.3f}s"


def _assert_no_gpu():
    maps = Path("/proc/self/maps")
    if not maps.exists():
        return
    blob = maps.read_text(errors="replace").lower()
    for bad in ("libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"):
        assert bad not in blob
