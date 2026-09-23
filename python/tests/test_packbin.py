from __future__ import annotations

import threading
import time
from pathlib import Path

import pytest

from packbin import (
    ShortPacket,
    TrailingBytes,
    be,
    bits,
    dict,
    eq,
    flags,
    group,
    i16,
    i32,
    list,
    pack,
    packet,
    repeat,
    sized,
    u2,
    utf8,
    u8,
    u16,
    u32,
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
    assert elapsed <= 2.0, f"elapsed {elapsed:.3f}s"


def _assert_no_gpu():
    maps = Path("/proc/self/maps")
    if not maps.exists():
        return
    blob = maps.read_text(errors="replace").lower()
    for bad in ("libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"):
        assert bad not in blob


def test_flag_group():
    empty = packet([flags("f", [group("mark", [])])])
    set_bit = pack(empty, {"mark": True})
    assert set_bit == b"\x01"
    assert len(set_bit) - 1 == 0
    clear = pack(empty, {})
    assert clear == b"\x00"

    one = packet([flags("f", [u8("a"), u8("b"), u8("c"), u8("d"), u8("e"), u16("b5")])])
    assert len(pack(one, {"a": 1})) == 2
    wide = pack(one, {"b5": 1})
    assert wide[0] == 0x20
    assert len(wide) - len(pack(one, {})) == 2

    two = packet([flags("f", [group("session", [u16("login"), u32("ts")])])])
    raw = pack(two, {"login": 7, "ts": 1000})
    assert raw[1:].hex() == "0700e8030000"
    assert len(raw) - 1 == 6
    absent = pack(two, {})
    assert absent == b"\x00"
    got = unpack(two, absent)
    assert got.ok is True
    assert got.value is not None
    assert "login" not in got.value
    assert "ts" not in got.value

    zero = packet([flags("f", [group("g", [u8("b")])])])
    stored = pack(zero, {"b": 0})
    assert stored == b"\x01\x00"

    short = unpack(two, b"\x01\x07")
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "login"
    assert short.needed == 2
    assert short.left == 1


def test_sized_bytes():
    layout = packet([u16("n"), sized("payload", "n")])
    raw = pack(layout, {"n": 3, "payload": bytes.fromhex("756176")})
    assert raw.hex() == "0300756176"
    got = unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["payload"] == bytes.fromhex("756176")
    empty = pack(layout, {"n": 0, "payload": b""})
    assert empty.hex() == "0000"
    empty_got = unpack(layout, empty)
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["payload"] == b""
    short = unpack(layout, bytes.fromhex("030075"))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "payload"
    assert short.needed == 3
    assert short.left == 1


def test_u2_and_bits():
    kinds = packet([u2("a", "b", "c", "d")])
    raw = pack(kinds, {"a": 0, "b": 1, "c": 2, "d": 3})
    assert raw.hex() == "e4"
    got = unpack(kinds, raw)
    assert got.ok is True
    assert got.value is not None
    assert [got.value[k] for k in ("a", "b", "c", "d")] == [0, 1, 2, 3]
    one = pack(packet([u2("a")]), {"a": 1})
    assert one.hex() == "01"

    layout = packet([u8("n"), bits("segs", "n")])
    eight = pack(layout, {"n": 8, "segs": [1] * 8})
    assert eight[1:].hex() == "ff"
    assert len(eight) - 1 == 1
    nine = pack(layout, {"n": 9, "segs": [1] * 9})
    assert len(nine) - 1 == 2
    assert nine[1] == 0xFF
    assert nine[2] & 0xFE == 0
    short = unpack(layout, bytes([9, 0x01]))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "segs"
    assert short.needed == 2
    assert short.left == 1


def test_utf8_string():
    layout = packet([utf8("name")])
    raw = pack(layout, {"name": "zxsanny"})
    assert raw.hex() == "07007a7873616e6e79"
    assert len(raw) == 9
    got = unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["name"] == "zxsanny"

    empty = pack(layout, {"name": ""})
    assert empty.hex() == "0000"
    empty_got = unpack(layout, empty)
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["name"] == ""

    with pytest.raises(ValueError):
        pack(layout, {"name": "a" * 65536})

    short = unpack(layout, bytes([0x07, 0x00, 0x7A, 0x78]))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "name"
    assert short.needed == 7
    assert short.left == 2


def test_counted_list():
    two = packet([list("xs", u16("n"))])
    raw = pack(two, {"xs": [1, 2]})
    assert raw.hex() == "020001000200"
    got = unpack(two, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["xs"] == [1, 2]

    be_one = packet([list("xs", be(u16("n")))])
    assert pack(be_one, {"xs": [1]}).hex() == "01000001"

    followed = packet([list("xs", u8("n")), u8("y")])
    both = pack(followed, {"xs": [1], "y": 2})
    assert both.hex() == "01000102"
    back = unpack(followed, both)
    assert back.ok is True
    assert back.value is not None
    assert back.value["xs"] == [1]
    assert back.value["y"] == 2

    assert pack(two, {"xs": []}).hex() == "0000"
    with pytest.raises(ValueError):
        pack(two, {"xs": [1] * 65536})


def test_dictionary():
    user_hex = (
        "07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e"
        "6e656c010004007265616403006d6170040004007265616407006770735f66697803007365"
        "74040065646974050073746f7265020004007265616405007772697465"
    )
    layout = packet(
        [
            utf8("username"),
            list("roles", utf8("role")),
            dict("access", list("actions", utf8("action"))),
        ]
    )
    values = {
        "username": "zxsanny",
        "roles": ["user", "dispatcher"],
        "access": {
            "channel": ["read"],
            "map": ["read", "gps_fix", "set", "edit"],
            "store": ["read", "write"],
        },
    }
    raw = pack(layout, values)
    assert raw.hex() == user_hex
    got = unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["username"] == "zxsanny"
    assert got.value["roles"] == ["user", "dispatcher"]
    assert got.value["access"]["channel"] == ["read"]
    assert got.value["access"]["map"] == ["read", "gps_fix", "set", "edit"]
    assert got.value["access"]["store"] == ["read", "write"]

    reordered = {
        "username": "zxsanny",
        "roles": ["user", "dispatcher"],
        "access": {
            "store": ["read", "write"],
            "channel": ["read"],
            "map": ["read", "gps_fix", "set", "edit"],
        },
    }
    assert pack(layout, reordered).hex() == user_hex

    empty = packet([utf8("s"), list("xs", u8("n")), dict("m", utf8("v"))])
    assert pack(empty, {"s": "", "xs": [], "m": {}}).hex() == "000000000000"

    dup = unpack(
        packet([dict("access", utf8("v"))]),
        bytes.fromhex("0200010061010078010061010079"),
    )
    assert dup.ok is False
    assert dup.value is None

    a = pack(layout, values)
    b = pack(layout, values)
    assert a == b
    assert _mismatched_bytes(a, b.hex()) == 0

    results: list[bytes | None] = [None, None]

    def run(index: int) -> None:
        results[index] = pack(layout, values)

    t0 = threading.Thread(target=run, args=(0,))
    t1 = threading.Thread(target=run, args=(1,))
    t0.start()
    t1.start()
    t0.join()
    t1.join()
    assert results[0] is not None and results[1] is not None
    assert _mismatched_bytes(results[0], results[1].hex()) == 0

    huge = packet([dict("m", utf8("v"))])
    with pytest.raises(ValueError):
        pack(huge, {"m": {str(i): "x" for i in range(65536)}})
