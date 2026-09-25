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

def test_when_group_width():
    layout = Scheme(
        1,
        dict,
        u8(0, lambda row: row["profile"]),
        when(eq(0, 0), u8(1, lambda row: row["shape"])),
    )
    assert len(BinaryPacker.pack(layout, {"profile": 1})) == 2
    assert len(BinaryPacker.pack(layout, {"profile": 0, "shape": 9})) == 3


def test_repeat_group_boundary():
    layout = Scheme(
        1,
        dict,
        u8(0, lambda row: row["type"]),
        repeat(i32(1, lambda row: row["lat"]), i32(2, lambda row: row["lon"])),
    )
    complete = BinaryPacker.pack(
        layout,
        {"type": 1, "lat": [10, 30], "lon": [20, 40]},
    )
    got = BinaryPacker.unpack(complete, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["lat"] == [10, 30]
    assert got.value["lon"] == [20, 40]

    leftover = complete + b"\xff"
    bad = BinaryPacker.unpack(leftover, layout.on(lambda row: None))
    assert bad.ok is False
    assert bad.value is None
    assert isinstance(bad.error, ShortPacket)


def test_flag_group():
    empty = Scheme(1, dict, flags(flag_bool(0, lambda row: row["mark"])))
    set_bit = BinaryPacker.pack(empty, {"mark": True})
    assert set_bit == b"\x01\x01"
    assert len(set_bit) - 1 == 1
    clear = BinaryPacker.pack(empty, {})
    assert clear == b"\x01\x00"

    one = Scheme(
        1,
        dict,
        flags(
            u8(0, lambda row: row["a"]),
            u8(1, lambda row: row["b"]),
            u8(2, lambda row: row["c"]),
            u8(3, lambda row: row["d"]),
            u8(4, lambda row: row["e"]),
            u16(5, lambda row: row["b5"]),
        ),
    )
    assert len(BinaryPacker.pack(one, {"a": 1})) == 3
    wide = BinaryPacker.pack(one, {"b5": 1})
    assert wide[1] == 0x20
    assert len(wide) - len(BinaryPacker.pack(one, {})) == 2

    two = Scheme(1, dict, flags(group(u16(0, lambda row: row["login"]), u32(1, lambda row: row["ts"]))))
    raw = BinaryPacker.pack(two, {"login": 7, "ts": 1000})
    assert raw[2:].hex() == "0700e8030000"
    assert len(raw) - 2 == 6
    absent = BinaryPacker.pack(two, {})
    assert absent == b"\x01\x00"
    got = BinaryPacker.unpack(absent, two.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert "login" not in got.value
    assert "ts" not in got.value

    zero = Scheme(1, dict, flags(group(u8(0, lambda row: row["b"]))))
    stored = BinaryPacker.pack(zero, {"b": 0})
    assert stored == b"\x01\x01\x00"

    short = BinaryPacker.unpack(b"\x01\x01\x07", two.on(lambda row: None))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "0"
    assert short.needed == 2
    assert short.left == 1


def test_sized_bytes():
    layout = Scheme(1, dict, u16(0, lambda row: row["n"]), sized(1, lambda row: row["payload"], 0))
    raw = BinaryPacker.pack(layout, {"n": 3, "payload": bytes.fromhex("756176")})
    assert raw.hex() == "010300756176"
    got = BinaryPacker.unpack(raw, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["payload"] == bytes.fromhex("756176")
    empty = BinaryPacker.pack(layout, {"n": 0, "payload": b""})
    assert empty.hex() == "010000"
    empty_got = BinaryPacker.unpack(empty, layout.on(lambda row: None))
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["payload"] == b""
    short = BinaryPacker.unpack(bytes.fromhex("01030075"), layout.on(lambda row: None))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "1"
    assert short.needed == 3
    assert short.left == 1


def test_u2_and_bits():
    kinds = Scheme(1, dict, u2((0, lambda row: row["a"]), (1, lambda row: row["b"]), (2, lambda row: row["c"]), (3, lambda row: row["d"])))
    raw = BinaryPacker.pack(kinds, {"a": 0, "b": 1, "c": 2, "d": 3})
    assert raw.hex() == "01e4"
    got = BinaryPacker.unpack(raw, kinds.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert [got.value[k] for k in ("a", "b", "c", "d")] == [0, 1, 2, 3]
    one = BinaryPacker.pack(Scheme(1, dict, u2((0, lambda row: row["a"]))), {"a": 1})
    assert one.hex() == "0101"

    layout = Scheme(1, dict, u8(0, lambda row: row["n"]), bits(1, lambda row: row["segs"], 0))
    eight = BinaryPacker.pack(layout, {"n": 8, "segs": [1] * 8})
    assert eight[2:].hex() == "ff"
    assert len(eight) - 2 == 1
    nine = BinaryPacker.pack(layout, {"n": 9, "segs": [1] * 9})
    assert len(nine) - 2 == 2
    assert nine[2] == 0xFF
    assert nine[3] & 0xFE == 0
    short = BinaryPacker.unpack(bytes([1, 9, 0x01]), layout.on(lambda row: None))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "1"
    assert short.needed == 2
    assert short.left == 1


def test_utf8_string():
    layout = Scheme(1, dict, utf8(0, lambda row: row["name"]))
    raw = BinaryPacker.pack(layout, {"name": "zxsanny"})
    assert raw.hex() == "0107007a7873616e6e79"
    assert len(raw) == 10
    got = BinaryPacker.unpack(raw, layout.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["name"] == "zxsanny"

    empty = BinaryPacker.pack(layout, {"name": ""})
    assert empty.hex() == "010000"
    empty_got = BinaryPacker.unpack(empty, layout.on(lambda row: None))
    assert empty_got.ok is True
    assert empty_got.value is not None
    assert empty_got.value["name"] == ""

    with pytest.raises(ValueError):
        BinaryPacker.pack(layout, {"name": "a" * 65536})

    short = BinaryPacker.unpack(bytes([0x01, 0x07, 0x00, 0x7A, 0x78]), layout.on(lambda row: None))
    assert short.ok is False
    assert short.value is None
    assert isinstance(short.error, ShortPacket)
    assert short.field == "0"
    assert short.needed == 7
    assert short.left == 2


def test_counted_list():
    two = Scheme(1, dict, list(lambda row: row["xs"], u16(0, lambda row: row)))
    raw = BinaryPacker.pack(two, {"xs": [1, 2]})
    assert raw.hex() == "01020001000200"
    got = BinaryPacker.unpack(raw, two.on(lambda row: None))
    assert got.ok is True
    assert got.value is not None
    assert got.value["xs"] == [1, 2]

    be_one = Scheme(1, dict, list(lambda row: row["xs"], be(u16(0, lambda row: row))))
    assert BinaryPacker.pack(be_one, {"xs": [1]}).hex() == "0101000001"

    followed = Scheme(1, dict, list(lambda row: row["xs"], u8(0, lambda row: row)), u8(0, lambda row: row["y"]))
    both = BinaryPacker.pack(followed, {"xs": [1], "y": 2})
    assert both.hex() == "0101000102"
    back = BinaryPacker.unpack(both, followed.on(lambda row: None))
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
        utf8(0, lambda row: row["username"]),
        list(lambda row: row["roles"], utf8(0, lambda row: row)),
        map_field(lambda row: row["access"], list(lambda row: row["actions"], utf8(0, lambda row: row))),
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
    got = BinaryPacker.unpack(raw, layout.on(lambda row: None))
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
        utf8(0, lambda row: row["s"]),
        list(lambda row: row["xs"], u8(0, lambda row: row)),
        map_field(lambda row: row["m"], utf8(0, lambda row: row)),
    )
    assert BinaryPacker.pack(empty, {"s": "", "xs": [], "m": {}}).hex() == "01000000000000"

    dup = BinaryPacker.unpack(
        bytes.fromhex("010200010061010078010061010079"),
        Scheme(1, dict, map_field(lambda row: row["access"], utf8(0, lambda row: row))).on(lambda row: None),
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

    huge = Scheme(1, dict, map_field(lambda row: row["m"], utf8(0, lambda row: row)))
    with pytest.raises(ValueError):
        BinaryPacker.pack(huge, {"m": {str(i): "x" for i in range(65536)}})
