"""Shared pieces of the parity percentage tests (AZ-3500; contract `message-ecc.md` 1.1.0).

The vector rows are `fixtures/ecc/percent-vectors.txt`, the same for the eight packages.
"""

from __future__ import annotations

from typing import Any, NamedTuple

import ecc_support as support
from packbin import Scheme, repeat, u8, u16

PERCENT_VECTORS = support.ROOT / "fixtures" / "ecc" / "percent-vectors.txt"

LARGEST_CLEAR = {1: 251, 10: 230, 25: 222, 50: 222, 100: 222}


class PRow(NamedTuple):
    kind: str
    id: str
    p: int
    t: int | None
    n: int | None
    clear: bytes
    received: bytes
    expect: str


def _bytes(token: str) -> bytes:
    return b"" if token == "-" else bytes.fromhex(token)


def _load() -> list[PRow]:
    rows: list[PRow] = []
    for line in PERCENT_VECTORS.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        w = line.split(" ")
        kind, row_id = w[0], w[1]
        if kind == "pct":
            rows.append(PRow(kind, row_id, int(w[2]), None, int(w[4]), bytes(int(w[3])), b"", ""))
        elif kind == "encp":
            rows.append(PRow(kind, row_id, int(w[2]), None, None, _bytes(w[3]), _bytes(w[4]), ""))
        elif kind == "inv":
            rows.append(PRow(kind, row_id, int(w[2]), None, int(w[3]), b"", b"", w[4]))
        elif kind == "limp":
            rows.append(PRow(kind, row_id, int(w[2]), None, int(w[3]), b"", b"", w[4]))
        elif kind == "fixp":
            rows.append(PRow(kind, row_id, int(w[2]), int(w[3]), int(w[6]), _bytes(w[5]), _bytes(w[4]), ""))
        elif kind == "badp":
            rows.append(PRow(kind, row_id, int(w[2]), int(w[3]), None, b"", _bytes(w[4]), w[5]))
        elif kind == "parp":
            rows.append(PRow(kind, row_id, int(w[2]), None, int(w[3]), b"", b"", ""))
        elif kind == "lmtp":
            rows.append(PRow(kind, row_id, 0, int(w[2]), None, b"", b"", ""))
        else:
            raise ValueError(f"percent-vectors.txt: unknown row kind {kind!r}")
    return rows


ROWS = _load()


def rows(kind: str) -> list[PRow]:
    return [row for row in ROWS if row.kind == kind]


def ids(selected: list[PRow]) -> list[str]:
    return [row.id for row in selected]


def percent_scheme(percent: int, type_number: int = 0x40) -> Scheme:
    """Any message whose first byte is `type_number`; the other bytes are the list `row["b"]` (at most 255)."""
    return support.raw_scheme(type_number).with_limits(parity_percent=percent)


def long_percent_scheme(percent: int) -> Scheme:
    """A scheme of five lists `b0` to `b4`, so a clear message can be longer than 256 bytes (use `long_row`)."""
    nodes = [repeat(i, u8(i, lambda row, i=i: row[f"b{i}"])) for i in range(5)]
    return Scheme(0, dict, *nodes).with_limits(max_bytes=4096, parity_percent=percent)


def long_row(length: int) -> dict[str, Any]:
    """The row of `long_percent_scheme` whose clear message is `length` bytes (at least 1)."""
    rest = length - 1
    return {f"b{i}": [0] * min(255, max(0, rest - 255 * i)) for i in range(5)}


def body_of(clear: bytes) -> dict[str, Any]:
    return {"b": list(clear[1:])}


def count_of(percent: int, length: int) -> int:
    """The independent integer rule of the contract: the percentage of the length, rounded up, at most 32."""
    return min(32, -(-(percent * length) // 100))


def largest_of(percent: int) -> int:
    length = 0
    while length + 1 + count_of(percent, length + 1) <= 254:
        length += 1
    return length
