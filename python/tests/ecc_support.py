"""Shared pieces of the message ECC tests (AZ-2680; contract `message-ecc.md`).

The vector rows are `fixtures/ecc/vectors.txt`, the same for the eight packages. The reference codec is
`scripts/ecc/eccfmt.py`; it is loaded by path as the independent side of the byte-for-byte checks.
"""

from __future__ import annotations

import importlib.util
import random
from pathlib import Path
from typing import Any, NamedTuple

from packbin import BinaryPacker, Scheme, UnpackResult, flags, i16, i32, repeat, u8, u16

ROOT = Path(__file__).resolve().parents[2]
VECTORS = ROOT / "fixtures" / "ecc" / "vectors.txt"
REFERENCE = ROOT / "scripts" / "ecc" / "eccfmt.py"

POSITION_HEX = "4001000065cd1d00a3e1110100"
POSITION_VALUES = {"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1}
POSITION_TYPE = 0x40


def _load_reference() -> Any:
    spec = importlib.util.spec_from_file_location("eccfmt", REFERENCE)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


reference = _load_reference()


class Row(NamedTuple):
    kind: str
    id: str
    n: int
    t: int | None
    clear: bytes
    received: bytes
    expect: str


def _bytes(token: str) -> bytes:
    return b"" if token == "-" else bytes.fromhex(token)


def _rows() -> list[Row]:
    rows: list[Row] = []
    for line in VECTORS.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        part = line.split(" ")
        kind, row_id, n = part[0], part[1], int(part[2])
        if kind == "enc":
            rows.append(Row(kind, row_id, n, None, _bytes(part[3]), _bytes(part[4]), ""))
        elif kind == "fix":
            rows.append(Row(kind, row_id, n, int(part[3]), _bytes(part[5]), _bytes(part[4]), part[6]))
        elif kind == "bad":
            rows.append(Row(kind, row_id, n, int(part[3]), b"", _bytes(part[4]), part[5]))
        elif kind == "lim":
            rows.append(Row(kind, row_id, n, None, bytes(int(part[3])), b"", part[4]))
        elif kind == "par":
            rows.append(Row(kind, row_id, n, None, b"", b"", ""))
        elif kind == "lmt":
            rows.append(Row(kind, row_id, n, int(part[3]), b"", b"", ""))
        else:
            raise ValueError(f"ecc vectors.txt: unknown row kind {kind!r}")
    return rows


ROWS = _rows()


def rows(kind: str) -> list[Row]:
    return [row for row in ROWS if row.kind == kind]


def ids(selected: list[Row]) -> list[str]:
    return [row.id for row in selected]


def raw_scheme(type_number: int, parity: int = 0) -> Scheme:
    """Any message whose first byte is `type_number`: the other bytes are the list `row["b"]`."""
    scheme = Scheme(type_number, dict, repeat(0, u8(0, lambda row: row["b"])))
    return scheme.with_limits(parity=parity)


def position_scheme(parity: int = 0, type_number: int = POSITION_TYPE) -> Scheme:
    scheme = Scheme(
        type_number,
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
    return scheme.with_limits(parity=parity)


def read(data: bytes, scheme: Scheme, limit: int = 0) -> UnpackResult[Any]:
    return BinaryPacker.unpack(data, scheme.on(lambda _row: None), limit=limit)


def kind_of(result: UnpackResult[Any]) -> str:
    """The refusal name of the vectors file for a refused result."""
    assert not result.ok
    name = type(result.error).__name__
    if name == "Uncorrectable":
        return "uncorrectable"
    if name == "TooLong":
        return "too_long"
    if name == "ShortPacket" and result.field == "parity":
        return "short"
    return name


def corrupt(rng: random.Random, data: bytes, count: int) -> tuple[bytes, list[int]]:
    """`data` with `count` distinct bytes changed to other values; also gives the positions."""
    word = bytearray(data)
    places = rng.sample(range(len(word)), count)
    for place in places:
        word[place] ^= rng.randrange(1, 256)
    return bytes(word), places
