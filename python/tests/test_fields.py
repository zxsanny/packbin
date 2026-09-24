from __future__ import annotations

import threading

import pytest

from packbin import (
    ShortPacket,
    Scheme,
    be,
    bits,
    dict as map_field,
    eq,
    flags,
    group,
    i32,
    list,
    pack,
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


def test_when_group_width():
    layout = Scheme(1, dict, u8("profile"), when(eq("profile", 0), [u8("shape")]))
    assert len(pack(layout, {"profile": 1})) == 2
    assert len(pack(layout, {"profile": 0, "shape": 9})) == 3


def test_repeat_group_boundary():
    layout = Scheme(1, dict, u8("type"), repeat([i32("lat"), i32("lon")]))
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


def test_flag_group():
    empty = Scheme(1, dict, flags("f", [group("mark", [])]))
    set_bit = pack(empty, {"mark": True})
    assert set_bit == b"\x01\x01"
    assert len(set_bit) - 1 == 1
    clear = pack(empty, {})
    assert clear == b"\x01\x00"

    one = Scheme(1, dict, flags("f", [u8("a"), u8("b"), u8("c"), u8("d"), u8("e"), u16("b5")]))
    assert len(pack(one, {"a": 1})) == 3
    wide = pack(one, {"b5": 1})
    assert wide[1] == 0x20
    assert len(wide) - len(pack(one, {})) == 2

    two = Scheme(1, dict, flags("f", [group("session", [u16("login"), u32("ts")])]))
    raw = pack(two, {"login": 7, "ts": 1000})
    assert raw[2:].hex() == "0700e8030000"
    assert len(raw) - 2 == 6
    absent = pack(two, {})
    assert absent == b"\x01\x00"
    got = unpack(two, absent)
    assert got.ok is True
    assert got.value is not None
    assert "login" not in got.value
    assert "ts" not in got.value

    zero = Scheme(1, dict, flags("f", [group("g", [u8("b")])]))
    stored = pack(zero, {"b": 0})
    assert stored == b"\x01\x01\x00"

    short = unpack(two, b"\x01\x01\x07")
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "login"
    assert short.needed == 2
    assert short.left == 1


def test_sized_bytes():
    layout = Scheme(1, dict, u16("n"), sized("payload", "n"))
    raw = pack(layout, {"n": 3, "payload": bytes.fromhex("756176")})
    assert raw.hex() == "010300756176"
    got = unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["payload"] == bytes.fromhex("756176")
    empty = pack(layout, {"n": 0, "payload": b""})
    assert empty.hex() == "010000"
    empty_got = unpack(layout, empty)
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["payload"] == b""
    short = unpack(layout, bytes.fromhex("01030075"))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "payload"
    assert short.needed == 3
    assert short.left == 1


def test_u2_and_bits():
    kinds = Scheme(1, dict, u2("a", "b", "c", "d"))
    raw = pack(kinds, {"a": 0, "b": 1, "c": 2, "d": 3})
    assert raw.hex() == "01e4"
    got = unpack(kinds, raw)
    assert got.ok is True
    assert got.value is not None
    assert [got.value[k] for k in ("a", "b", "c", "d")] == [0, 1, 2, 3]
    one = pack(Scheme(1, dict, u2("a")), {"a": 1})
    assert one.hex() == "0101"

    layout = Scheme(1, dict, u8("n"), bits("segs", "n"))
    eight = pack(layout, {"n": 8, "segs": [1] * 8})
    assert eight[2:].hex() == "ff"
    assert len(eight) - 2 == 1
    nine = pack(layout, {"n": 9, "segs": [1] * 9})
    assert len(nine) - 2 == 2
    assert nine[2] == 0xFF
    assert nine[3] & 0xFE == 0
    short = unpack(layout, bytes([1, 9, 0x01]))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "segs"
    assert short.needed == 2
    assert short.left == 1


def test_utf8_string():
    layout = Scheme(1, dict, utf8("name"))
    raw = pack(layout, {"name": "zxsanny"})
    assert raw.hex() == "0107007a7873616e6e79"
    assert len(raw) == 10
    got = unpack(layout, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["name"] == "zxsanny"

    empty = pack(layout, {"name": ""})
    assert empty.hex() == "010000"
    empty_got = unpack(layout, empty)
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["name"] == ""

    with pytest.raises(ValueError):
        pack(layout, {"name": "a" * 65536})

    short = unpack(layout, bytes([0x01, 0x07, 0x00, 0x7A, 0x78]))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "name"
    assert short.needed == 7
    assert short.left == 2


def test_counted_list():
    two = Scheme(1, dict, list("xs", u16("n")))
    raw = pack(two, {"xs": [1, 2]})
    assert raw.hex() == "01020001000200"
    got = unpack(two, raw)
    assert got.ok is True
    assert got.value is not None
    assert got.value["xs"] == [1, 2]

    be_one = Scheme(1, dict, list("xs", be(u16("n"))))
    assert pack(be_one, {"xs": [1]}).hex() == "0101000001"

    followed = Scheme(1, dict, list("xs", u8("n")), u8("y"))
    both = pack(followed, {"xs": [1], "y": 2})
    assert both.hex() == "0101000102"
    back = unpack(followed, both)
    assert back.ok is True
    assert back.value is not None
    assert back.value["xs"] == [1]
    assert back.value["y"] == 2

    assert pack(two, {"xs": []}).hex() == "010000"
    with pytest.raises(ValueError):
        pack(two, {"xs": [1] * 65536})


def test_dictionary():
    user_hex = (
        "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e"
        "6e656c010004007265616403006d6170040004007265616407006770735f66697803007365"
        "74040065646974050073746f7265020004007265616405007772697465"
    )
    layout = Scheme(
        1,
        dict,
        utf8("username"),
        list("roles", utf8("role")),
        map_field("access", list("actions", utf8("action"))),
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

    empty = Scheme(1, dict, utf8("s"), list("xs", u8("n")), map_field("m", utf8("v")))
    assert pack(empty, {"s": "", "xs": [], "m": {}}).hex() == "01000000000000"

    dup = unpack(
        Scheme(1, dict, map_field("access", utf8("v"))),
        bytes.fromhex("010200010061010078010061010079"),
    )
    assert dup.ok is False
    assert dup.value is None

    a = pack(layout, values)
    b = pack(layout, values)
    assert a == b

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
    assert results[0] == results[1]

    huge = Scheme(1, dict, map_field("m", utf8("v")))
    with pytest.raises(ValueError):
        pack(huge, {"m": {str(i): "x" for i in range(65536)}})