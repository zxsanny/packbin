from __future__ import annotations

import threading

import pytest

from packbin import (
    ShortPacket,
    Scheme,
    be,
    bits,
    bool as flag_bool,
    dict as map_field,
    eq,
    flags,
    group,
    i32,
    list,
    BinaryPacker,
    repeat,
    sized,
    u2,
    utf8,
    u8,
    u16,
    u32,
    when,
)

from _bind import gs, leaf


def test_when_group_width():
    g_profile, s_profile = gs("profile")
    g_shape, s_shape = gs("shape")
    layout = Scheme(1, dict, u8(0, g_profile, s_profile), when(eq(0, 0), u8(1, g_shape, s_shape)))
    assert len(BinaryPacker.pack(layout, {"profile": 1})) == 2
    assert len(BinaryPacker.pack(layout, {"profile": 0, "shape": 9})) == 3


def test_repeat_group_boundary():
    g_type, s_type = gs("type")
    g_lat, s_lat = gs("lat")
    g_lon, s_lon = gs("lon")
    layout = Scheme(1, dict, u8(0, g_type, s_type), repeat(i32(1, g_lat, s_lat), i32(2, g_lon, s_lon)))
    complete = BinaryPacker.pack(
        layout,
        {"type": 1, "lat": [10, 30], "lon": [20, 40]},
    )
    got = BinaryPacker.unpack(layout, complete)
    assert got.ok is True
    assert got.value is not None
    assert got.value["lat"] == [10, 30]
    assert got.value["lon"] == [20, 40]

    leftover = complete + b"\xff"
    bad = BinaryPacker.unpack(layout, leftover)
    assert bad.ok is False
    assert bad.value is None
    assert isinstance(bad.error, ShortPacket)


def test_flag_group():
    g_mark, s_mark = gs("mark")
    empty = Scheme(1, dict, flags(flag_bool(0, g_mark, s_mark)))
    set_bit = BinaryPacker.pack(empty, {"mark": True})
    assert set_bit == b"\x01\x01"
    assert len(set_bit) - 1 == 1
    clear = BinaryPacker.pack(empty, {})
    assert clear == b"\x01\x00"

    one = Scheme(
        1,
        dict,
        flags(
            u8(0, *gs("a")),
            u8(1, *gs("b")),
            u8(2, *gs("c")),
            u8(3, *gs("d")),
            u8(4, *gs("e")),
            u16(5, *gs("b5")),
        ),
    )
    assert len(BinaryPacker.pack(one, {"a": 1})) == 3
    wide = BinaryPacker.pack(one, {"b5": 1})
    assert wide[1] == 0x20
    assert len(wide) - len(BinaryPacker.pack(one, {})) == 2

    two = Scheme(1, dict, flags(group(u16(0, *gs("login")), u32(1, *gs("ts")))))
    raw = BinaryPacker.pack(two, {"login": 7, "ts": 1000})
    assert raw[2:].hex() == "0700e8030000"
    assert len(raw) - 2 == 6
    absent = BinaryPacker.pack(two, {})
    assert absent == b"\x01\x00"
    got = BinaryPacker.unpack(two, absent)
    assert got.ok is True
    assert got.value is not None
    assert "login" not in got.value
    assert "ts" not in got.value

    zero = Scheme(1, dict, flags(group(u8(0, *gs("b")))))
    stored = BinaryPacker.pack(zero, {"b": 0})
    assert stored == b"\x01\x01\x00"

    short = BinaryPacker.unpack(two, b"\x01\x01\x07")
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "0"
    assert short.needed == 2
    assert short.left == 1


def test_sized_bytes():
    layout = Scheme(1, dict, u16(0, *gs("n")), sized(1, *gs("payload"), 0))
    raw = BinaryPacker.pack(layout, {"n": 3, "payload": bytes.fromhex("756176")})
    assert raw.hex() == "010300756176"
    got = BinaryPacker.unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["payload"] == bytes.fromhex("756176")
    empty = BinaryPacker.pack(layout, {"n": 0, "payload": b""})
    assert empty.hex() == "010000"
    empty_got = BinaryPacker.unpack(layout, empty)
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["payload"] == b""
    short = BinaryPacker.unpack(layout, bytes.fromhex("01030075"))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "1"
    assert short.needed == 3
    assert short.left == 1


def test_u2_and_bits():
    kinds = Scheme(1, dict, u2((0, *gs("a")), (1, *gs("b")), (2, *gs("c")), (3, *gs("d"))))
    raw = BinaryPacker.pack(kinds, {"a": 0, "b": 1, "c": 2, "d": 3})
    assert raw.hex() == "01e4"
    got = BinaryPacker.unpack(kinds, raw)
    assert got.ok is True
    assert got.value is not None
    assert [got.value[k] for k in ("a", "b", "c", "d")] == [0, 1, 2, 3]
    one = BinaryPacker.pack(Scheme(1, dict, u2((0, *gs("a")))), {"a": 1})
    assert one.hex() == "0101"

    layout = Scheme(1, dict, u8(0, *gs("n")), bits(1, *gs("segs"), 0))
    eight = BinaryPacker.pack(layout, {"n": 8, "segs": [1] * 8})
    assert eight[2:].hex() == "ff"
    assert len(eight) - 2 == 1
    nine = BinaryPacker.pack(layout, {"n": 9, "segs": [1] * 9})
    assert len(nine) - 2 == 2
    assert nine[2] == 0xFF
    assert nine[3] & 0xFE == 0
    short = BinaryPacker.unpack(layout, bytes([1, 9, 0x01]))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "1"
    assert short.needed == 2
    assert short.left == 1


def test_utf8_string():
    layout = Scheme(1, dict, utf8(0, *gs("name")))
    raw = BinaryPacker.pack(layout, {"name": "zxsanny"})
    assert raw.hex() == "0107007a7873616e6e79"
    assert len(raw) == 10
    got = BinaryPacker.unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["name"] == "zxsanny"

    empty = BinaryPacker.pack(layout, {"name": ""})
    assert empty.hex() == "010000"
    empty_got = BinaryPacker.unpack(layout, empty)
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["name"] == ""

    with pytest.raises(ValueError):
        BinaryPacker.pack(layout, {"name": "a" * 65536})

    short = BinaryPacker.unpack(layout, bytes([0x01, 0x07, 0x00, 0x7A, 0x78]))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "0"
    assert short.needed == 7
    assert short.left == 2


def test_counted_list():
    two = Scheme(1, dict, list(*gs("xs"), u16(0, *leaf())))
    raw = BinaryPacker.pack(two, {"xs": [1, 2]})
    assert raw.hex() == "01020001000200"
    got = BinaryPacker.unpack(two, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["xs"] == [1, 2]

    be_one = Scheme(1, dict, list(*gs("xs"), be(u16(0, *leaf()))))
    assert BinaryPacker.pack(be_one, {"xs": [1]}).hex() == "0101000001"

    followed = Scheme(1, dict, list(*gs("xs"), u8(0, *leaf())), u8(0, *gs("y")))
    both = BinaryPacker.pack(followed, {"xs": [1], "y": 2})
    assert both.hex() == "0101000102"
    back = BinaryPacker.unpack(followed, both)
    assert back.ok is True
    assert back.value is not None
    assert back.value["xs"] == [1]
    assert back.value["y"] == 2

    assert BinaryPacker.pack(two, {"xs": []}).hex() == "010000"
    with pytest.raises(ValueError):
        BinaryPacker.pack(two, {"xs": [1] * 65536})


def test_dictionary():
    user_hex = (
        "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e"
        "6e656c010004007265616403006d6170040004007265616407006770735f66697803007365"
        "74040065646974050073746f7265020004007265616405007772697465"
    )
    layout = Scheme(
        1,
        dict,
        utf8(0, *gs("username")),
        list(*gs("roles"), utf8(0, *leaf())),
        map_field(*gs("access"), list(*gs("actions"), utf8(0, *leaf()))),
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
    raw = BinaryPacker.pack(layout, values)
    assert raw.hex() == user_hex
    got = BinaryPacker.unpack(layout, raw)
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
    assert BinaryPacker.pack(layout, reordered).hex() == user_hex

    empty = Scheme(
        1,
        dict,
        utf8(0, *gs("s")),
        list(*gs("xs"), u8(0, *leaf())),
        map_field(*gs("m"), utf8(0, *leaf())),
    )
    assert BinaryPacker.pack(empty, {"s": "", "xs": [], "m": {}}).hex() == "01000000000000"

    dup = BinaryPacker.unpack(
        Scheme(1, dict, map_field(*gs("access"), utf8(0, *leaf()))),
        bytes.fromhex("010200010061010078010061010079"),
    )
    assert dup.ok is False
    assert dup.value is None

    a = BinaryPacker.pack(layout, values)
    b = BinaryPacker.pack(layout, values)
    assert a == b

    results: list[bytes | None] = [None, None]

    def run(index: int) -> None:
        results[index] = BinaryPacker.pack(layout, values)

    t0 = threading.Thread(target=run, args=(0,))
    t1 = threading.Thread(target=run, args=(1,))
    t0.start()
    t1.start()
    t0.join()
    t1.join()
    assert results[0] is not None and results[1] is not None
    assert results[0] == results[1]

    huge = Scheme(1, dict, map_field(*gs("m"), utf8(0, *leaf())))
    with pytest.raises(ValueError):
        BinaryPacker.pack(huge, {"m": {str(i): "x" for i in range(65536)}})
