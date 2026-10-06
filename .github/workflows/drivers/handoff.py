from __future__ import annotations

import sys

from packbin import (
    BinaryPacker,
    PackSession,
    Scheme,
    bool as flag_bool,
    dict as map_field,
    eq,
    flag_byte,
    flags,
    group,
    i16,
    i32,
    list,
    u8,
    u16,
    utf8,
    when,
)


USER = Scheme(
    1,
    dict,
    utf8(0, lambda row: row["username"]),
    list(lambda row: row["roles"], utf8(0, lambda row: row)),
    map_field(lambda row: row["access"], list(lambda row: row["actions"], utf8(0, lambda row: row))),
)

USER_VALUES = {
    "username": "zxsanny",
    "roles": ["user", "dispatcher"],
    "access": {
        "channel": ["read"],
        "map": ["read", "gps_fix", "set", "edit"],
        "store": ["read", "write"],
    },
}

NESTED = Scheme(
    1,
    dict,
    map_field(lambda row: row["access"], list(lambda row: row["rows"], map_field(lambda row: row["fields"], utf8(0, lambda row: row)))),
)

NESTED_VALUES = {
    "access": {
        "map": [{"op": "gps_fix"}],
        "store": [{"op": "read"}, {"op": "write"}],
    },
}

POSITION = Scheme(
    0x40,
    dict,
    u16(0, lambda row: row["sid"]),
    i32(1, lambda row: row["lat"]),
    i32(2, lambda row: row["lon"]),
    u8(3, lambda row: row["profile"]),
    flags(
        4,
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

BOOLFLAG = Scheme(1, dict, flags(0, flag_bool(0, lambda row: row["on"])))

# A split bit inside a when that is not taken: the bit comes from the row (01), the when is tested
# first on unpack, so v is never read. {k: 0, v: 5} packs 010001.
_BITWHEN_FLAG = flag_byte()
BITWHEN = Scheme(
    1,
    dict,
    u8(0, lambda row: row["k"]),
    _BITWHEN_FLAG,
    when(1, eq(0, 1), _BITWHEN_FLAG.bit(u8(1, lambda row: row["v"]))),
)
BITWHEN_VALUES = {"k": 0, "v": 5}

# A list of group, a dict of group and a list of flags (AZ-2102, AZ-2239). An absent value is a clear
# flag bit, so the flags item {"b": 2} packs its flag byte as 02.
def _point():
    return (u8(0, lambda p: p["a"]), u8(1, lambda p: p["b"]))


ELEMENT_CASES = {
    "listgroup": (
        Scheme(1, dict, list(lambda row: row["pts"], group(0, *_point()))),
        {"pts": [{"a": 1, "b": 2}, {"a": 3, "b": 4}]},
    ),
    "dictgroup": (
        Scheme(1, dict, map_field(lambda row: row["m"], group(0, *_point()))),
        {"m": {"y": {"a": 3, "b": 4}, "x": {"a": 1, "b": 2}}},
    ),
    "listflags": (
        Scheme(
            1,
            dict,
            list(lambda row: row["pts"], flags(0, u8(0, lambda p: p["a"]), u16(1, lambda p: p["b"]))),
        ),
        {"pts": [{"a": 1}, {}, {"b": 2}]},
    ),
}


def _element_command(cmd: str, argv: list[str]) -> int | None:
    """Runs pack-, unpack- and unpack-...-short for one of ELEMENT_CASES; None when cmd is not one."""
    for kind, (packet, values) in ELEMENT_CASES.items():
        if cmd == f"pack-{kind}":
            print(BinaryPacker.pack(packet, values).hex())
            return 0
        if cmd not in (f"unpack-{kind}", f"unpack-{kind}-short"):
            continue
        if len(argv) < 2 or not argv[1]:
            return 2
        delivered = []
        result = BinaryPacker.unpack(bytes.fromhex(argv[1]), packet.on(delivered.append))
        if cmd.endswith("-short"):
            # A short element is refused and no row reaches the handler.
            if not result.ok and not delivered:
                return 0
            print(f"{cmd}: {result!r}, delivered {delivered!r}; expected a refusal and no row", file=sys.stderr)
            return 1
        if not result.ok or result.value != values:
            print(f"{cmd}: {result!r}, expected {values!r}", file=sys.stderr)
            return 1
        return 0
    return None


SESSION_SEED = bytes(range(1, 33))
SESSION_NONCE = bytes.fromhex("01000000000000000000000000000000")


def _session_fields_ok(row) -> bool:
    if row.get("sid") != 1:
        return False
    if row.get("lat") != 500_000_000:
        return False
    if row.get("lon") != 300_000_000:
        return False
    if row.get("profile") != 1:
        return False
    for name in ("heading", "speed", "altitude"):
        if name in row and row[name] is not None:
            return False
    return True


def main(argv: list[str]) -> int:
    if len(argv) < 1:
        return 2
    cmd = argv[0]
    if cmd == "pack-user":
        print(BinaryPacker.pack(USER, USER_VALUES).hex())
        return 0
    if cmd == "pack-nested":
        print(BinaryPacker.pack(NESTED, NESTED_VALUES).hex())
        return 0
    if cmd == "pack-boolflag":
        print(BinaryPacker.pack(BOOLFLAG, {"on": False}).hex())
        return 0
    if cmd == "pack-booltrue":
        print(BinaryPacker.pack(BOOLFLAG, {"on": True}).hex())
        return 0
    if cmd == "pack-bitwhen":
        print(BinaryPacker.pack(BITWHEN, BITWHEN_VALUES).hex())
        return 0
    if cmd == "pack-session":
        opener = PackSession.load(SESSION_SEED)
        if opener is None or opener.start(SESSION_NONCE) is None:
            return 1
        payload = opener.pack(POSITION, POSITION_VALUES)
        if payload is None:
            return 1
        print(payload.hex())
        return 0
    if cmd == "unpack-user":
        if len(argv) < 2:
            return 1
        result = BinaryPacker.unpack(bytes.fromhex(argv[1]), USER.on(lambda row: None))
        if not result.ok or result.value is None:
            return 1
        return 0 if result.value == USER_VALUES else 1
    if cmd == "unpack-nested":
        if len(argv) < 2:
            return 1
        result = BinaryPacker.unpack(bytes.fromhex(argv[1]), NESTED.on(lambda row: None))
        if not result.ok or result.value is None:
            return 1
        return 0 if result.value == NESTED_VALUES else 1
    if cmd == "unpack-boolflag":
        if len(argv) < 2:
            return 1
        result = BinaryPacker.unpack(bytes.fromhex(argv[1]), BOOLFLAG.on(lambda row: None))
        if not result.ok or result.value is None:
            return 1
        return 1 if result.value.get("on") is True else 0
    if cmd == "unpack-booltrue":
        if len(argv) < 2:
            return 1
        result = BinaryPacker.unpack(bytes.fromhex(argv[1]), BOOLFLAG.on(lambda row: None))
        if not result.ok or result.value is None:
            return 1
        return 0 if result.value.get("on") is True else 1
    if cmd == "unpack-bitwhen":
        if len(argv) < 2:
            return 1
        result = BinaryPacker.unpack(bytes.fromhex(argv[1]), BITWHEN.on(lambda row: None))
        if not result.ok or result.value is None:
            return 1
        return 0 if result.value == {"k": 0} else 1
    if cmd == "unpack-session":
        if len(argv) < 2:
            return 1
        waiter = PackSession.load(SESSION_SEED)
        if waiter is None or not waiter.join(SESSION_NONCE):
            return 1
        result = waiter.unpack(bytes.fromhex(argv[1]), POSITION.on(lambda row: None))
        if not result.ok or result.value is None:
            return 1
        return 0 if _session_fields_ok(result.value) else 1
    element = _element_command(cmd, argv)
    return 2 if element is None else element


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
