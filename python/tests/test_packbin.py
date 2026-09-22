from __future__ import annotations

import time
from pathlib import Path

from packbin import (
    ShortPacket,
    TrailingBytes,
    eq,
    flags,
    i16,
    i32,
    pack,
    packet,
    repeat,
    u8,
    u16,
    unpack,
    when,
)

REPO_ROOT = Path(__file__).resolve().parents[2]
GOLDEN_HEX = (REPO_ROOT / "fixtures" / "golden.hex").read_text().strip()
POSITION_HEX = "4001000065cd1d00a3e1110100"

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


def _hex(data: bytes) -> str:
    return data.hex()


def _mismatched_bytes(actual: bytes, expected_hex: str) -> int:
    expected = bytes.fromhex(expected_hex)
    return sum(1 for a, b in zip(actual, expected, strict=False) if a != b) + abs(
        len(actual) - len(expected)
    )


def test_ac1_position_pack():
    raw = pack(POSITION, POSITION_VALUES)
    assert _hex(raw) == POSITION_HEX
    assert _mismatched_bytes(raw, POSITION_HEX) == 0
    assert len(raw) == 13
    again = pack(POSITION, POSITION_VALUES)
    assert _mismatched_bytes(again, _hex(raw)) == 0


def test_ac2_position_unpack():
    got = unpack(POSITION, bytes.fromhex(POSITION_HEX))
    assert got.ok is True
    assert got.value is not None
    assert got.value["type"] == 64
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
    raw = pack(POSITION, POSITION_VALUES)
    assert _mismatched_bytes(raw, GOLDEN_HEX) == 0
    assert GOLDEN_HEX == POSITION_HEX


def test_ac4_flags_and_stored_zero():
    layout = packet(
        [
            u8("type"),
            flags(
                "opt",
                [
                    u8("b0"),
                    u8("b1"),
                    u8("b2"),
                    u8("b3"),
                    u8("b4"),
                    u16("b5"),
                ],
            ),
        ]
    )
    clear = pack(layout, {"type": 0x40})
    assert clear[1] == 0x00
    assert len(clear) == 2

    set_bit = pack(layout, {"type": 0x40, "b5": 0x1234})
    assert set_bit[1] == 0x20
    assert len(set_bit) == 4
    assert len(set_bit) - len(clear) == 2

    present_zero = pack(layout, {"type": 0x40, "b5": 0})
    assert present_zero[1] == 0x20
    assert present_zero[2:] == b"\x00\x00"
    assert len(present_zero) == 4

    absent = pack(layout, {"type": 0x40})
    assert absent[1] == 0x00
    assert len(absent) == 2
    assert absent != present_zero


def test_ac5_short_field_then_position_pack():
    layout = packet(
        [
            u8("type"),
            flags(
                "opt",
                [
                    u8("b0"),
                    u8("b1"),
                    u8("b2"),
                    u8("b3"),
                    u8("b4"),
                    u16("b5"),
                ],
            ),
        ]
    )
    short = bytes([0x40, 0x20, 0x34])
    got = unpack(layout, short)
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, ShortPacket)
    assert got.field == "b5"
    assert got.needed == 2
    assert got.left == 1

    raw = pack(POSITION, POSITION_VALUES)
    assert _hex(raw) == GOLDEN_HEX
    assert _mismatched_bytes(raw, GOLDEN_HEX) == 0


def test_when_group_width():
    layout = packet(
        [
            u8("profile"),
            when(eq("profile", 0), [u8("shape")]),
        ]
    )
    assert len(pack(layout, {"profile": 1})) == 1
    assert len(pack(layout, {"profile": 0, "shape": 9})) == 2


def test_repeat_group_boundary():
    layout = packet([u8("type"), repeat([i32("lat"), i32("lon")])])
    complete = pack(
        layout,
        {"type": 1, "lat": [10, 30], "lon": [20, 40]},
    )
    got = unpack(layout, complete)
    assert got.ok is True
    assert got.value is not None
    assert got.value["lat"] == [10, 30]
    assert got.value["lon"] == [20, 40]

    leftover = complete + b"\xff"
    bad = unpack(layout, leftover)
    assert bad.ok is False
    assert bad.value is None
    assert isinstance(bad.error, ShortPacket)


def test_trailing_bytes():
    raw = pack(POSITION, POSITION_VALUES) + b"\x00"
    got = unpack(POSITION, raw)
    assert got.ok is False
    assert got.value is None
    assert isinstance(got.error, TrailingBytes)
    assert got.error.left == 1


def test_nfr_round_trips():
    start = time.perf_counter()
    for _ in range(100_000):
        raw = pack(POSITION, POSITION_VALUES)
        got = unpack(POSITION, raw)
        assert got.ok is True
    elapsed = time.perf_counter() - start
    _assert_no_gpu()
    assert elapsed <= 1.0, f"elapsed {elapsed:.3f}s"


def _assert_no_gpu():
    maps = Path("/proc/self/maps")
    if not maps.exists():
        return
    blob = maps.read_text(errors="replace").lower()
    for bad in ("libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"):
        assert bad not in blob
