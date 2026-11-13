"""Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of ../README.md,
packs each shape's values and unpacks its own bytes. One line per shape: package, shape, build, pack,
unpack (tab separated). It asserts nothing: it prints what happens.

Rows are plain dicts read with key accessors (`Scheme(1, dict, ...)`, `lambda r: r["x"]`), so a
shape leaves a value out by leaving its key out. A class row with attribute accessors builds the same
nodes.
"""

from __future__ import annotations

import json
import re
from typing import Any

from packbin import BinaryPacker, Scheme, UnpackResult, flags, u8
from packbin import bool as flag_bool

Row = dict[str, Any]


def one_line(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def raised(exc: BaseException) -> str:
    return one_line(f"{type(exc).__name__}: {exc}")


def shown(value: Any) -> str:
    """Keys in sorted order, so two rows that hold the same values print the same text."""
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def present(row: Row) -> Row:
    """The values two rows are compared by: a member with no value (None) is absent, and so is
    `b = False`, which leaves the bit clear as an absent `b` does (README §Bool)."""
    return {k: v for k, v in row.items() if v is not None and not (k == "b" and v is False)}


def build() -> Scheme[Row]:
    """S: flags(flags(u8 x), bool b). The ids number straight through: the inner flags and x are 0, b is 1."""
    return Scheme(
        1,
        dict,
        flags(0, flags(0, u8(0, lambda r: r["x"])), flag_bool(1, lambda r: r["b"])),
    )


def read_back(result: UnpackResult[Row], got: list[Row], values: Row) -> str:
    """The unpack column of an unpack that returned: `got` holds the row when the packet was read."""
    if not got:
        return f"refused: {one_line(repr(result.error))}"
    if present(got[0]) == present(values):
        return "same"
    return f"differs: {shown(got[0])}"


def probe(shape: str, values: Row) -> None:
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


probe("both", {"x": 9, "b": True})
probe("x-only", {"x": 9})
probe("b-only", {"b": True})
probe("none", {})
