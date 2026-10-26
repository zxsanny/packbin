from __future__ import annotations

import importlib.util

import packbin
from packbin import BinaryPacker, Scheme, u8
from packbin import bool as flag_bool
from packbin import bytes as raw_bytes
from packbin import dict as map_field
from packbin import list as list_field

SHADOWING = ("bool", "bytes", "dict", "list")
# the stream session and its modules, removed in loop 74 (ADR-009)
STREAM_SESSION = ("PackSession", "_session", "_session_pad")


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

    for name in ("Scheme", "BinaryPacker", "u8", "flags", "utf8"):
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

    assert BinaryPacker.pack(row, {"m": {"b": 1, "a": 2}}).hex() == "0102000210610202106201"


def test_no_stream_session_name_is_public_or_importable():
    # Arrange
    namespace: dict = {}
    exec("from packbin import *", namespace)

    # Act
    left = set(STREAM_SESSION) & (set(dir(packbin)) | set(packbin.__all__) | set(namespace))
    modules = [name for name in STREAM_SESSION[1:] if importlib.util.find_spec(f"packbin.{name}") is not None]

    # Assert
    assert (left, modules) == (set(), [])


def test_the_crypto_module_is_internal():
    # Arrange
    namespace: dict = {}

    # Act
    exec("from packbin import *", namespace)

    # Assert
    assert ("_crypto" in packbin.__all__, "_crypto" in namespace) == (False, False)
