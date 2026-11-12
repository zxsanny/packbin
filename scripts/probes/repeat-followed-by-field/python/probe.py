"""Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
../README.md, packs the values given there and unpacks its own bytes. One line per shape:
package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.

Rows are plain dicts read with key accessors (`Scheme(1, dict, ...)`, `lambda r: r["x"]`): the row of a
list or dict element is always a dict, so this form writes every shape. A class row with attribute
accessors builds the same nodes. The rounds of a repeat are one list per name (`v = [5, 6]`).
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable
from typing import Any

from packbin import BinaryPacker, Scheme, UnpackResult, eq, flags, group, repeat, u8, when
from packbin import dict as dict_field
from packbin import list as list_field

Row = dict[str, Any]

# The names a repeat holds in the shapes.
ROUND_NAMES = frozenset({"v", "w"})


def one_line(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def raised(exc: BaseException) -> str:
    return one_line(f"{type(exc).__name__}: {exc}")


def plain(value: Any) -> Any:
    if isinstance(value, (bytes, bytearray, memoryview)):
        return list(value)
    raise TypeError(f"no text form for {type(value).__name__}")


def shown(value: Any) -> str:
    """Keys in sorted order, so two rows that hold the same values print the same text."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=plain)


def without_empty_rounds(value: Any) -> Any:
    """A repeat that reads no round leaves its names out of the row unpack returns, so an empty list of
    rounds and an absent name are the same values: both are dropped before two rows are compared."""
    if isinstance(value, dict):
        return {
            key: without_empty_rounds(item)
            for key, item in value.items()
            if not (key in ROUND_NAMES and item == [])
        }
    if isinstance(value, list):
        return [without_empty_rounds(item) for item in value]
    return value


def read_back(result: UnpackResult[Row], got: list[Row], values: Row) -> str:
    """The unpack column of an unpack that returned: `got` holds the row when the packet was read."""
    if not got:
        return f"refused: {one_line(repr(result.error))}"
    if without_empty_rounds(got[0]) == without_empty_rounds(values):
        return "same"
    return f"differs: {shown(got[0])}"


def probe(shape: str, build: Callable[[], Scheme[Row]], values: Row) -> None:
    def line(built: str, packed: str, unpacked: str) -> None:
        print("\t".join(["python", shape, built, packed, unpacked]), flush=True)

    try:
        scheme = build()
    except Exception as exc:  # the refusal is the finding
        line(f"refused: {raised(exc)}", "-", "-")
        return
    try:
        packed = BinaryPacker.pack(scheme, values)
    except Exception as exc:  # the refusal is the finding
        line("built", f"refused: {raised(exc)}", "-")
        return
    got: list[Row] = []
    try:
        result = BinaryPacker.unpack(packed, scheme.on(got.append))
    except Exception as exc:  # an unpack that raises is the finding
        line("built", packed.hex(), f"threw: {raised(exc)}")
        return
    try:
        unpacked = read_back(result, got, values)
    except Exception as exc:  # a row the probe cannot compare or print: say so and go on
        unpacked = f"threw: probe: {raised(exc)}"
    line("built", packed.hex(), unpacked)


# control: the repeat is the last thing read.
probe(
    "control",
    lambda: Scheme(1, dict, u8(0, lambda r: r["x"]), repeat(1, u8(1, lambda r: r["v"]))),
    {"x": 9, "v": [5, 6]},
)

# a: a field after a repeat, top level.
probe(
    "a",
    lambda: Scheme(1, dict, repeat(0, u8(0, lambda r: r["v"])), u8(1, lambda r: r["x"])),
    {"v": [5, 6], "x": 9},
)

# b: a repeat inside a list element row, two items. The element row is a group; an element is a scope of
# its own, so its ids start at 0.
probe(
    "b",
    lambda: Scheme(
        1,
        dict,
        list_field(
            lambda r: r["items"],
            group(0, u8(0, lambda r: r["mode"]), repeat(1, u8(1, lambda r: r["v"]))),
        ),
    ),
    {"items": [{"mode": 1, "v": [5]}, {"mode": 2, "v": []}]},
)

# c: a repeat inside a dict element row, two entries.
probe(
    "c",
    lambda: Scheme(
        1,
        dict,
        dict_field(
            lambda r: r["d"],
            group(0, u8(0, lambda r: r["mode"]), repeat(1, u8(1, lambda r: r["v"]))),
        ),
    ),
    {"d": {"a": {"mode": 1, "v": [5]}, "b": {"mode": 2, "v": []}}},
)

# d: a repeat inside a group, then a field. Python has one group, `group(anchor, *fields)`: it takes an
# anchor, shares the ids and the row of the fields around it (so `x` is id 1, not 0 as in TypeScript) and
# has no name, so the row is flat.
probe(
    "d",
    lambda: Scheme(1, dict, group(0, repeat(0, u8(0, lambda r: r["v"]))), u8(1, lambda r: r["x"])),
    {"v": [5, 6], "x": 9},
)

# e-when: a repeat under a when that is taken, then a field.
probe(
    "e-when",
    lambda: Scheme(
        1,
        dict,
        u8(0, lambda r: r["k"]),
        when(1, eq(0, 1), repeat(1, u8(1, lambda r: r["v"]))),
        u8(2, lambda r: r["x"]),
    ),
    {"k": 1, "v": [5, 6], "x": 9},
)

# e-flags: a repeat under flags, then a field.
probe(
    "e-flags",
    lambda: Scheme(1, dict, flags(0, repeat(0, u8(0, lambda r: r["v"]))), u8(1, lambda r: r["x"])),
    {"v": [5, 6], "x": 9},
)

# f: a repeat after a repeat. A name whose repeat read no round has no key in the row that comes back.
probe(
    "f",
    lambda: Scheme(1, dict, repeat(0, u8(0, lambda r: r["v"])), repeat(1, u8(1, lambda r: r["w"]))),
    {"v": [5], "w": [6]},
)
