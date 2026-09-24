from __future__ import annotations

import sys

from packbin import Scheme, dict as map_field, list, pack, unpack, utf8


def gs(key: str):
    return (lambda r, k=key: r.get(k), lambda r, v, k=key: r.__setitem__(k, v))


def leaf():
    return (lambda x: x, lambda _x, _v: None)


USER = Scheme(
    1,
    dict,
    utf8(0, *gs("username")),
    list(*gs("roles"), utf8(0, *leaf())),
    map_field(*gs("access"), list(*gs("actions"), utf8(0, *leaf()))),
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
    map_field(*gs("access"), list(*gs("rows"), map_field(*gs("fields"), utf8(0, *leaf())))),
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
