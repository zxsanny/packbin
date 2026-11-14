"""Probe of AZ-4291: what happens when a scheme is nested very deep. Usage: probe.py <shape> <depth> with
shape `when` or `group`. It prints one tab-separated line: package, shape-depth, build, pack, unpack. It
asserts nothing: it prints what happens. The scheme is built in a loop, innermost first, so the probe
itself never recurses. The recursion limit is left at its default: what the package does there is the finding.

group form: Python has one group, `group(anchor, *fields)`: it shares the ids and the row of the fields
around it, so a chain of D of them (each anchor 0, the innermost holding `u8 b` with id 0) is the only
nesting the API has. The row is a flat dict, so the value is `{"b": 7}` at any depth and it packs `01 07`.
"""

from __future__ import annotations

import json
import re
import sys
from collections.abc import Callable
from typing import Any

from packbin import BinaryPacker, Scheme, eq, group, u8, when

Row = dict[str, Any]

MAX_HEX = 80
RAW = (RecursionError, MemoryError)  # a raw language failure, not the package's own refusal


def one_line(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def failure(exc: BaseException) -> str:
    if isinstance(exc, RAW):
        return f"threw: {type(exc).__name__}"
    return f"refused: {one_line(f'{type(exc).__name__}: {exc}')[:120]}"


def hexed(data: bytes) -> str:
    text = data.hex()
    return f"{text[:40]}...({len(data)} bytes)" if len(text) > MAX_HEX else text


def build_when(depth: int) -> Scheme[Row]:
    inner: list[Any] = [u8(1, lambda r: r["b"])]
    for _ in range(depth):
        inner = [when(1, eq(0, 1), *inner)]
    return Scheme(1, dict, u8(0, lambda r: r["a"]), *inner)


def build_group(depth: int) -> Scheme[Row]:
    inner: list[Any] = [u8(0, lambda r: r["b"])]
    for _ in range(depth):
        inner = [group(0, *inner)]
    return Scheme(1, dict, *inner)


def main() -> None:
    if len(sys.argv) != 3 or sys.argv[1] not in ("when", "group") or not sys.argv[2].isdigit():
        print("usage: probe.py <when|group> <depth>", file=sys.stderr)
        raise SystemExit(2)
    shape, depth = sys.argv[1], int(sys.argv[2])
    values: Row = {"a": 1, "b": 7} if shape == "when" else {"b": 7}
    builder: Callable[[int], Scheme[Row]] = build_when if shape == "when" else build_group

    def line(built: str, packed: str, unpacked: str) -> None:
        print("\t".join(["python", f"{shape}-{depth}", built, packed, unpacked]), flush=True)

    try:
        scheme = builder(depth)
    except Exception as exc:  # the outcome is the finding
        line(failure(exc), "-", "-")
        return
    try:
        packed = BinaryPacker.pack(scheme, values)
    except Exception as exc:  # the outcome is the finding
        line("built", failure(exc), "-")
        return
    got: list[Row] = []
    try:
        result = BinaryPacker.unpack(packed, scheme.on(got.append))
    except Exception as exc:  # the outcome is the finding
        line("built", hexed(packed), failure(exc))
        return
    if not got:
        line("built", hexed(packed), f"refused: {one_line(repr(result.error))[:120]}")
    elif got[0] == values:
        line("built", hexed(packed), "same")
    else:
        line("built", hexed(packed), f"differs: {one_line(json.dumps(got[0], sort_keys=True, default=repr))[:120]}")


main()
