from __future__ import annotations

import sys

from packbin import dict, list, pack, packet, unpack, utf8

USER = packet(
    [
        utf8("username"),
        list("roles", utf8("role")),
        dict("access", list("actions", utf8("action"))),
    ]
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

NESTED = packet(
    [dict("access", list("rows", dict("fields", utf8("value"))))]
)

NESTED_VALUES = {
    "access": {
        "map": [{"op": "gps_fix"}],
        "store": [{"op": "read"}, {"op": "write"}],
    },
}


def main(argv: list[str]) -> int:
    if len(argv) < 1:
        return 2
    cmd = argv[0]
    if cmd == "pack-user":
        print(pack(USER, USER_VALUES).hex())
        return 0
    if cmd == "pack-nested":
        print(pack(NESTED, NESTED_VALUES).hex())
        return 0
    if cmd == "unpack-user":
        if len(argv) < 2:
            return 1
        result = unpack(USER, bytes.fromhex(argv[1]))
        if not result.ok or result.value is None:
            return 1
        return 0 if result.value == USER_VALUES else 1
    if cmd == "unpack-nested":
        if len(argv) < 2:
            return 1
        result = unpack(NESTED, bytes.fromhex(argv[1]))
        if not result.ok or result.value is None:
            return 1
        return 0 if result.value == NESTED_VALUES else 1
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
