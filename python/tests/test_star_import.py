from __future__ import annotations

import packbin
from packbin import BinaryPacker, Scheme, u8
from packbin import bool as flag_bool
from packbin import bytes as raw_bytes
from packbin import dict as map_field
from packbin import list as list_field

SHADOWING = ("bool", "bytes", "dict", "list")


def test_star_import_keeps_builtins():
    namespace: dict = {}

    exec(
        "from packbin import *\nresult = (dict(), list((1, 2)), bytes.fromhex('00'), bool(1))\n",
        namespace,
    )

    assert namespace["result"] == ({}, [1, 2], b"\x00", True)
    assert not set(SHADOWING) & set(namespace)


def test_star_import_still_brings_the_rest_of_the_public_names():
    namespace: dict = {}

    exec("from packbin import *", namespace)

    for name in ("Scheme", "BinaryPacker", "PackSession", "u8", "flags", "utf8"):
        assert name in namespace


def test_all_leaves_out_the_builtin_names():
    assert not set(SHADOWING) & set(packbin.__all__)


def test_every_name_in_all_exists():
    assert all(hasattr(packbin, name) for name in packbin.__all__)


def test_builder_names_import_explicitly():
    assert (map_field, list_field, raw_bytes, flag_bool) == (
        packbin.dict,
        packbin.list,
        packbin.bytes,
        packbin.bool,
    )

    row = Scheme(1, dict, map_field(lambda row: row["m"], u8(0, lambda row: row)))

    assert BinaryPacker.pack(row, {"m": {"b": 1, "a": 2}}).hex() == "0102000100610201006201"
